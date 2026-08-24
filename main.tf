# ----------------------------------------------------------------------
# terraform-aws-gitlab-runner-fleet — a lean GitLab Runner fleeting fleet
# (always-on manager + scale-to-zero spot workers). See phpboyscout/infra
# spec 2026-07-28-hand-rolled-runner-fleet-module.
# ----------------------------------------------------------------------

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

data "aws_ami" "worker" {
  most_recent = true
  owners      = var.worker_ami_owners

  filter {
    name   = "name"
    values = [var.worker_ami_name_filter]
  }
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

# Amazon Linux 2023 for the manager (awscli + ssm-agent baked in).
data "aws_ami" "manager" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

locals {
  worker_asg_name = "${var.name_prefix}-asg"
  cache_bucket    = var.enable_s3_cache ? (var.cache_s3_bucket != null ? var.cache_s3_bucket : aws_s3_bucket.cache[0].bucket) : ""

  config_toml = templatefile("${path.module}/templates/config.toml.tftpl", {
    max_instances         = var.max_instances
    runner_name           = "${var.name_prefix}-manager"
    gitlab_url            = var.gitlab_url
    capacity_per_instance = var.capacity_per_instance
    idle_time             = var.idle_time
    worker_asg_name       = local.worker_asg_name
    default_job_image     = "docker:24"
    enable_s3_cache       = var.enable_s3_cache
    cache_bucket          = local.cache_bucket
    region                = data.aws_region.current.region
    environment_json      = jsonencode(var.runner_environment)
    docker_volumes_json   = jsonencode(var.runner_docker_volumes)
    pre_build_script_json = jsonencode(var.runner_pre_build_script)
  })

  manager_user_data = base64encode(templatefile("${path.module}/templates/manager-user-data.sh.tftpl", {
    runner_version  = var.runner_agent_version
    ssm_token_param = var.runner_token_ssm_parameter_name
    region          = data.aws_region.current.region
    config_toml     = local.config_toml
  }))

  worker_user_data = base64encode(templatefile("${path.module}/templates/worker-user-data.sh.tftpl", {
    enable_efs_cache = var.enable_efs_cache
    efs_dns_name     = var.enable_efs_cache ? aws_efs_file_system.cache[0].dns_name : ""
  }))
}

# --- distributed GitLab cache (S3) ------------------------------------

#trivy:ignore:AVD-AWS-0132 SSE-S3 by design for non-secret ephemeral cache — see checkov CKV_AWS_145 rationale.
resource "aws_s3_bucket" "cache" {
  # checkov:skip=CKV_AWS_145:SSE-S3 is sufficient — non-secret ephemeral CI cache; a CMK adds cost/management for no gain.
  # checkov:skip=CKV_AWS_21:Versioning is pointless for a write-once/expire-in-14-days cache.
  # checkov:skip=CKV_AWS_18:Access logging unwarranted for a private, single-consumer cache bucket.
  # checkov:skip=CKV_AWS_144:No cross-region replication — regenerable cache, region-locked estate.
  # checkov:skip=CKV2_AWS_62:No event notifications — nothing subscribes; the runner cache is CLI-driven.
  count = var.enable_s3_cache && var.cache_s3_bucket == null ? 1 : 0

  bucket = "${var.name_prefix}-${data.aws_caller_identity.current.account_id}-cache"
  tags   = var.tags
}

resource "aws_s3_bucket_lifecycle_configuration" "cache" {
  count = var.enable_s3_cache && var.cache_s3_bucket == null ? 1 : 0

  bucket = aws_s3_bucket.cache[0].id
  rule {
    id     = "expire-cache"
    status = "Enabled"
    filter {}
    expiration {
      days = 14
    }
  }
}

resource "aws_s3_bucket_public_access_block" "cache" {
  count = var.enable_s3_cache && var.cache_s3_bucket == null ? 1 : 0

  bucket                  = aws_s3_bucket.cache[0].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# --- shared EFS cache (read-mostly: scanner DBs + cargo registry) -----

resource "aws_efs_file_system" "cache" {
  # checkov:skip=CKV_AWS_184:Encrypted with the default EFS key (encrypted=true) — non-secret CI cache data (scanner DBs, cargo registry) with a 14-day IA lifecycle; a CMK adds key management for no confidentiality gain.
  count = var.enable_efs_cache ? 1 : 0

  creation_token = "${var.name_prefix}-cache"
  encrypted      = true

  lifecycle_policy {
    transition_to_ia = "AFTER_14_DAYS"
  }

  tags = merge(var.tags, { Name = "${var.name_prefix}-cache" })
}

resource "aws_efs_mount_target" "cache" {
  count = var.enable_efs_cache ? length(var.subnet_ids) : 0

  file_system_id  = aws_efs_file_system.cache[0].id
  subnet_id       = var.subnet_ids[count.index]
  security_groups = [aws_security_group.efs[0].id]
}



# --- security groups ---------------------------------------------------

#trivy:ignore:AVD-AWS-0104 Deliberate open egress (GitLab + fleeting) — see checkov CKV_AWS_382 rationale.
resource "aws_security_group" "manager" {
  # checkov:skip=CKV_AWS_382:Egress to any address is required — the manager reaches GitLab.com and the fleeting plugin manages instances; there is no fixed egress CIDR set.
  name_prefix = "${var.name_prefix}-manager-"
  vpc_id      = var.vpc_id
  description = "Fleet manager: egress only; connects to workers within the fleet SGs."

  egress {
    description = "Egress to GitLab.com + package/registry mirrors."
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "${var.name_prefix}-manager" })

  lifecycle {
    create_before_destroy = true
  }
}

#trivy:ignore:AVD-AWS-0104 Deliberate open egress (registries + GitLab) — see checkov CKV_AWS_382 rationale.
resource "aws_security_group" "worker" {
  # checkov:skip=CKV_AWS_382:Egress to any address is required — workers pull job container images from arbitrary registries and reach GitLab.com; no fixed egress CIDR set.
  name_prefix = "${var.name_prefix}-worker-"
  vpc_id      = var.vpc_id
  description = "Fleet workers: SSH from the manager only; egress to GitLab + registries."

  ingress {
    description     = "SSH from the manager (fleeting connector)."
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.manager.id]
  }

  egress {
    description = "Egress to GitLab.com + job image registries + package mirrors."
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "${var.name_prefix}-worker" })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group" "efs" {
  # checkov:skip=CKV2_AWS_5:Attached to the EFS mount targets via aws_efs_mount_target.security_groups — checkov does not trace that attachment.
  count = var.enable_efs_cache ? 1 : 0

  name_prefix = "${var.name_prefix}-efs-"
  vpc_id      = var.vpc_id
  description = "EFS cache: NFS from workers only."

  ingress {
    description     = "NFS from workers."
    from_port       = 2049
    to_port         = 2049
    protocol        = "tcp"
    security_groups = [aws_security_group.worker.id]
  }

  tags = merge(var.tags, { Name = "${var.name_prefix}-efs" })

  lifecycle {
    create_before_destroy = true
  }
}

# --- IAM: manager ------------------------------------------------------

data "aws_iam_policy_document" "assume_ec2" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "manager" {
  name_prefix          = "${var.name_prefix}-mgr-"
  assume_role_policy   = data.aws_iam_policy_document.assume_ec2.json
  permissions_boundary = var.iam_permissions_boundary
  tags                 = var.tags
}

data "aws_iam_policy_document" "manager" {
  # checkov:skip=CKV_AWS_356:The fleeting plugin needs account-wide autoscaling + ec2:DescribeInstances + ec2-instance-connect across dynamically-created spot instances it does not know in advance; these read/connect actions cannot be resource-scoped.
  # checkov:skip=CKV_AWS_111:Same — the fleeting Describe/Connect actions are not write-with-constraints; the write actions (SetDesiredCapacity/Terminate) target the fleet ASG operationally.
  # Fleeting: manage the worker ASG + connect to instances.
  statement {
    sid = "Fleeting"
    actions = [
      "autoscaling:DescribeAutoScalingGroups",
      "autoscaling:DescribeScalingActivities",
      "autoscaling:SetDesiredCapacity",
      "autoscaling:TerminateInstanceInAutoScalingGroup",
      "ec2:DescribeInstances",
      "ec2-instance-connect:SendSSHPublicKey",
    ]
    resources = ["*"]
  }

  # Read the runner token from SSM (+ decrypt the SecureString).
  statement {
    sid       = "SsmToken"
    actions   = ["ssm:GetParameter"]
    resources = ["arn:${data.aws_partition.current.partition}:ssm:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:parameter${var.runner_token_ssm_parameter_name}"]
  }
  statement {
    sid       = "SsmKmsDecrypt"
    actions   = ["kms:Decrypt"]
    resources = ["arn:${data.aws_partition.current.partition}:kms:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:alias/aws/ssm"]
  }
}

resource "aws_iam_role_policy" "manager" {
  name   = "manager"
  role   = aws_iam_role.manager.id
  policy = data.aws_iam_policy_document.manager.json
}

resource "aws_iam_role_policy" "manager_cache" {
  count = var.enable_s3_cache ? 1 : 0

  name = "cache"
  role = aws_iam_role.manager.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "CacheBucketRW"
      Effect   = "Allow"
      Action   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:ListBucket"]
      Resource = ["arn:${data.aws_partition.current.partition}:s3:::${local.cache_bucket}", "arn:${data.aws_partition.current.partition}:s3:::${local.cache_bucket}/*"]
    }]
  })
}

resource "aws_iam_role_policy_attachment" "manager_ssm" {
  count = var.manager_ssm_access ? 1 : 0

  role       = aws_iam_role.manager.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "manager" {
  name_prefix = "${var.name_prefix}-mgr-"
  role        = aws_iam_role.manager.name
  tags        = var.tags
}

# --- IAM: worker (minimal) --------------------------------------------

resource "aws_iam_role" "worker" {
  name_prefix          = "${var.name_prefix}-wkr-"
  assume_role_policy   = data.aws_iam_policy_document.assume_ec2.json
  permissions_boundary = var.iam_permissions_boundary
  tags                 = var.tags
}

resource "aws_iam_instance_profile" "worker" {
  name_prefix = "${var.name_prefix}-wkr-"
  role        = aws_iam_role.worker.name
  tags        = var.tags
}

# --- EBS-CMK grant for Auto Scaling (D13) -----------------------------

resource "aws_kms_grant" "asg_ebs" {
  count = var.ebs_kms_key_arn != null ? 1 : 0

  name              = "${var.name_prefix}-asg-ebs"
  key_id            = var.ebs_kms_key_arn
  grantee_principal = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:role/aws-service-role/autoscaling.amazonaws.com/AWSServiceRoleForAutoScaling"

  operations = [
    "Encrypt", "Decrypt", "ReEncryptFrom", "ReEncryptTo",
    "GenerateDataKey", "GenerateDataKeyWithoutPlaintext",
    "DescribeKey", "CreateGrant",
  ]
}

# --- worker launch template + spot ASG --------------------------------

resource "aws_launch_template" "worker" {
  name_prefix   = "${var.name_prefix}-worker-"
  image_id      = data.aws_ami.worker.id
  user_data     = local.worker_user_data
  ebs_optimized = true

  iam_instance_profile {
    arn = aws_iam_instance_profile.worker.arn
  }

  vpc_security_group_ids = [aws_security_group.worker.id]

  block_device_mappings {
    device_name = "/dev/sda1"
    ebs {
      volume_size           = var.worker_root_volume_size
      volume_type           = var.worker_volume_type
      delete_on_termination = true
      encrypted             = true
    }
  }

  metadata_options {
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  tag_specifications {
    resource_type = "instance"
    tags          = merge(var.tags, { Name = "${var.name_prefix}-worker" })
  }

  tags = var.tags

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "worker" {
  name             = local.worker_asg_name
  min_size         = 0
  max_size         = var.max_instances
  desired_capacity = 0
  # The fleeting plugin owns instance lifecycle — protect new instances
  # from ASG scale-in so the ASG never terminates a worker the plugin is
  # using (it logs "new instances are not protected from scale in" and
  # detaches/terminates them itself otherwise).
  protect_from_scale_in = true
  vpc_zone_identifier   = var.subnet_ids

  mixed_instances_policy {
    instances_distribution {
      on_demand_base_capacity                  = 0
      on_demand_percentage_above_base_capacity = 0
      spot_allocation_strategy                 = var.spot_allocation_strategy
      # AWS rejects spot_instance_pools with any strategy but lowest-price.
      spot_instance_pools = var.spot_allocation_strategy == "lowest-price" ? var.spot_instance_pools : null
    }

    launch_template {
      launch_template_specification {
        launch_template_id = aws_launch_template.worker.id
        version            = "$Latest"
      }
      dynamic "override" {
        for_each = var.worker_instance_types
        content {
          instance_type = override.value
        }
      }
    }
  }

  # desired_capacity is managed at runtime by the fleeting plugin.
  lifecycle {
    ignore_changes = [desired_capacity]
  }

  tag {
    key                 = "Name"
    value               = "${var.name_prefix}-worker"
    propagate_at_launch = true
  }
}

# --- manager: launch template + ASG of 1 (self-healing) ---------------

resource "aws_launch_template" "manager" {
  name_prefix            = "${var.name_prefix}-manager-"
  image_id               = data.aws_ami.manager.id
  instance_type          = var.manager_instance_type
  user_data              = local.manager_user_data
  vpc_security_group_ids = [aws_security_group.manager.id]

  iam_instance_profile {
    arn = aws_iam_instance_profile.manager.arn
  }

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = var.manager_root_volume_size
      volume_type           = "gp3"
      delete_on_termination = true
      encrypted             = true
    }
  }

  metadata_options {
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  tag_specifications {
    resource_type = "instance"
    tags          = merge(var.tags, { Name = "${var.name_prefix}-manager" })
  }

  tags = var.tags

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "manager" {
  name                = "${var.name_prefix}-manager"
  min_size            = 1
  max_size            = 1
  desired_capacity    = 1
  vpc_zone_identifier = var.subnet_ids

  # Pin the ASG to the template's CURRENT version, NOT "$Latest". This is
  # what makes instance_refresh below actually fire.
  #
  # An ASG whose launch_template block says "$Latest" has no diff when the
  # template's *contents* change — the id and the literal string "$Latest"
  # are both unchanged — so terraform never updates the ASG, and an instance
  # refresh is only triggered by an update to the ASG. The apply succeeds, a
  # new launch template version exists, and the running manager keeps its old
  # user-data (and therefore its old config.toml) indefinitely.
  #
  # Observed 2026-08-24: a runner-config fix applied cleanly, reported
  # success, and changed nothing. The manager had to be replaced by hand from
  # the console before the new config.toml existed on the box. Worse than the
  # bug it was fixing, because it fails silently — see phpboyscout/infra#6.
  #
  # The WORKER ASG deliberately keeps "$Latest": its instances are ephemeral
  # (desired_capacity 0, spot, bounded max_use_count), so every launch already
  # picks up the newest template, and it carries no instance_refresh to defeat.
  launch_template {
    id      = aws_launch_template.manager.id
    version = aws_launch_template.manager.latest_version
  }

  # Roll the manager when the launch template (config/version) changes.
  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 0
    }
  }

  tag {
    key                 = "Name"
    value               = "${var.name_prefix}-manager"
    propagate_at_launch = true
  }
}
