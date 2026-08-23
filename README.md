# terraform-aws-gitlab-runner-fleet

A lean OpenTofu module for a **GitLab Runner fleeting fleet** on AWS: one
always-on manager plus **scale-to-zero spot workers** (the next-gen
`docker-autoscaler` executor + `fleeting-plugin-aws`). Purpose-built for the
phpboyscout ops account to replace `cattle-ops/gitlab-runner`, giving full
control over the levers that module hid — spot allocation strategy (no forced
`spot_instance_pools`), worker Docker install + disk size, an EFS/S3 cache
layer, and no plan-time Lambda (so CI plan/apply works).

See `phpboyscout/infra` spec `2026-07-28-hand-rolled-runner-fleet-module`.

## Usage

```hcl
module "runner_fleet" {
  source  = "gitlab.com/phpboyscout/gitlab-runner-fleet/aws"
  version = "0.1.0"

  name_prefix                     = "pbs-ops-runner"
  vpc_id                          = var.vpc_id
  subnet_ids                      = var.subnet_ids
  runner_token_ssm_parameter_name = aws_ssm_parameter.runner_token.name
  ebs_kms_key_arn                 = data.aws_kms_key.ebs_default.arn

  max_instances = 4 # hard spot-instance ceiling (cost guardrail)

  tags = { Project = "phpboyscout", Environment = "ops" }
}
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | ~> 1.12.5 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | 6.61.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.61.0 |

## Resources

| Name | Type |
| ---- | ---- |
| [aws_autoscaling_group.manager](https://registry.terraform.io/providers/hashicorp/aws/6.61.0/docs/resources/autoscaling_group) | resource |
| [aws_autoscaling_group.worker](https://registry.terraform.io/providers/hashicorp/aws/6.61.0/docs/resources/autoscaling_group) | resource |
| [aws_efs_file_system.cache](https://registry.terraform.io/providers/hashicorp/aws/6.61.0/docs/resources/efs_file_system) | resource |
| [aws_efs_mount_target.cache](https://registry.terraform.io/providers/hashicorp/aws/6.61.0/docs/resources/efs_mount_target) | resource |
| [aws_iam_instance_profile.manager](https://registry.terraform.io/providers/hashicorp/aws/6.61.0/docs/resources/iam_instance_profile) | resource |
| [aws_iam_instance_profile.worker](https://registry.terraform.io/providers/hashicorp/aws/6.61.0/docs/resources/iam_instance_profile) | resource |
| [aws_iam_role.manager](https://registry.terraform.io/providers/hashicorp/aws/6.61.0/docs/resources/iam_role) | resource |
| [aws_iam_role.worker](https://registry.terraform.io/providers/hashicorp/aws/6.61.0/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.manager](https://registry.terraform.io/providers/hashicorp/aws/6.61.0/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.manager_cache](https://registry.terraform.io/providers/hashicorp/aws/6.61.0/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy_attachment.manager_ssm](https://registry.terraform.io/providers/hashicorp/aws/6.61.0/docs/resources/iam_role_policy_attachment) | resource |
| [aws_kms_grant.asg_ebs](https://registry.terraform.io/providers/hashicorp/aws/6.61.0/docs/resources/kms_grant) | resource |
| [aws_launch_template.manager](https://registry.terraform.io/providers/hashicorp/aws/6.61.0/docs/resources/launch_template) | resource |
| [aws_launch_template.worker](https://registry.terraform.io/providers/hashicorp/aws/6.61.0/docs/resources/launch_template) | resource |
| [aws_s3_bucket.cache](https://registry.terraform.io/providers/hashicorp/aws/6.61.0/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket_lifecycle_configuration.cache](https://registry.terraform.io/providers/hashicorp/aws/6.61.0/docs/resources/s3_bucket_lifecycle_configuration) | resource |
| [aws_s3_bucket_public_access_block.cache](https://registry.terraform.io/providers/hashicorp/aws/6.61.0/docs/resources/s3_bucket_public_access_block) | resource |
| [aws_security_group.efs](https://registry.terraform.io/providers/hashicorp/aws/6.61.0/docs/resources/security_group) | resource |
| [aws_security_group.manager](https://registry.terraform.io/providers/hashicorp/aws/6.61.0/docs/resources/security_group) | resource |
| [aws_security_group.worker](https://registry.terraform.io/providers/hashicorp/aws/6.61.0/docs/resources/security_group) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_cache_s3_bucket"></a> [cache\_s3\_bucket](#input\_cache\_s3\_bucket) | Optional existing S3 bucket for the distributed GitLab cache (cache: keys, e.g. tofu-plugin-cache). When null and enable\_s3\_cache is true the module creates one. | `string` | `null` | no |
| <a name="input_capacity_per_instance"></a> [capacity\_per\_instance](#input\_capacity\_per\_instance) | Jobs a single worker runs concurrently. 1 keeps the max\_instances ceiling equal to the concurrent-job ceiling. | `number` | `1` | no |
| <a name="input_ebs_kms_key_arn"></a> [ebs\_kms\_key\_arn](#input\_ebs\_kms\_key\_arn) | ARN of the CMK encrypting worker/manager EBS volumes (the account's EBS default key). The module grants the Auto Scaling service-linked role use of it — required when the account enforces CMK EBS encryption, or ASG instances die with Client.InvalidKMSKey.InvalidState (D13). Null skips the grant (AWS-managed key in use). | `string` | `null` | no |
| <a name="input_enable_efs_cache"></a> [enable\_efs\_cache](#input\_enable\_efs\_cache) | Provision a shared EFS filesystem and mount it on every worker for the read-mostly caches — scanner vuln DBs (/opt/ci-cache) and the cargo registry / rustup home (/opt/rust-cache/shared) — matching runner1's host mounts. Write-heavy Rust target/ is deliberately NOT on EFS (see runner\_docker\_volumes / S3 cache). | `bool` | `true` | no |
| <a name="input_enable_s3_cache"></a> [enable\_s3\_cache](#input\_enable\_s3\_cache) | Configure the runner's [runners.cache] for S3 so GitLab cache: keys survive across ephemeral workers. | `bool` | `true` | no |
| <a name="input_gitlab_url"></a> [gitlab\_url](#input\_gitlab\_url) | GitLab instance URL the runner registers against. | `string` | `"https://gitlab.com"` | no |
| <a name="input_iam_permissions_boundary"></a> [iam\_permissions\_boundary](#input\_iam\_permissions\_boundary) | Optional IAM permissions-boundary policy ARN applied to the roles the module creates. | `string` | `null` | no |
| <a name="input_idle_time"></a> [idle\_time](#input\_idle\_time) | How long an idle worker lingers before the autoscaler scales it in (a short reuse window for bursty backlogs, then back to zero). idle\_count is fixed at 0 — pure scale-to-zero. | `string` | `"10m0s"` | no |
| <a name="input_manager_instance_type"></a> [manager\_instance\_type](#input\_manager\_instance\_type) | Manager EC2 type. It only runs gitlab-runner + the fleeting plugin (never job containers), so the smallest sane instance is right. | `string` | `"t3.micro"` | no |
| <a name="input_manager_root_volume_size"></a> [manager\_root\_volume\_size](#input\_manager\_root\_volume\_size) | Manager root volume size (GB). It stores no build artifacts. | `number` | `8` | no |
| <a name="input_manager_ssm_access"></a> [manager\_ssm\_access](#input\_manager\_ssm\_access) | Attach AmazonSSMManagedInstanceCore to the manager for operator access (patching/debug). | `bool` | `true` | no |
| <a name="input_max_instances"></a> [max\_instances](#input\_max\_instances) | HARD CEILING on spot worker instances (ASG max\_size AND the fleeting autoscaler max\_instances). With capacity\_per\_instance = 1 this caps concurrent jobs AND running instances — the primary cost guardrail. | `number` | `4` | no |
| <a name="input_name_prefix"></a> [name\_prefix](#input\_name\_prefix) | Prefix for all resource names, e.g. "pbs-ops-runner". Kept short — it seeds ASG, launch-template, IAM, EFS and SG names. | `string` | n/a | yes |
| <a name="input_runner_agent_version"></a> [runner\_agent\_version](#input\_runner\_agent\_version) | gitlab-runner version installed on the manager (workers run job containers, not the agent). Pin the latest stable; Renovate-tracked. | `string` | `"19.2.0"` | no |
| <a name="input_runner_docker_volumes"></a> [runner\_docker\_volumes](#input\_runner\_docker\_volumes) | Docker volume mounts applied to every job container (mirrors runner1's [runners.docker] volumes). Defaults expose the EFS-backed shared caches plus the local /cache. Paths must exist on the worker (the module's user-data creates/mounts them). | `list(string)` | <pre>[<br/>  "/cache",<br/>  "/opt/ci-cache:/opt/ci-cache:rw",<br/>  "/opt/rust-cache/shared:/opt/rust-cache/shared:rw"<br/>]</pre> | no |
| <a name="input_runner_environment"></a> [runner\_environment](#input\_runner\_environment) | Runner-level environment applied to every job (mirrors runner1's [[runners]] environment — cargo/rustup home on the shared cache, git-CLI fetch). | `list(string)` | <pre>[<br/>  "CARGO_HOME=/opt/rust-cache/shared/cargo-home",<br/>  "RUSTUP_HOME=/opt/rust-cache/shared/rustup",<br/>  "CARGO_NET_GIT_FETCH_WITH_CLI=true"<br/>]</pre> | no |
| <a name="input_runner_pre_build_script"></a> [runner\_pre\_build\_script](#input\_runner\_pre\_build\_script) | Runner pre\_build\_script (mirrors runner1). Kept configurable because it needs CI-var expansion the static environment can't do. Note: CARGO\_TARGET\_DIR (write-heavy) points at local worker disk, NOT the EFS mount, to avoid network-FS latency on cargo's small-file I/O (D8). | `string` | `"export CARGO_TARGET_DIR=\"/opt/rust-cache/${CI_PROJECT_PATH_SLUG}/target\"; export PATH=\"/opt/rust-cache/shared/cargo-home/bin:${PATH}\""` | no |
| <a name="input_runner_token_ssm_parameter_name"></a> [runner\_token\_ssm\_parameter\_name](#input\_runner\_token\_ssm\_parameter\_name) | Name of the SSM SecureString parameter holding the pre-registered group-runner authentication token (glrt-…). The manager reads it at boot; never passed as a literal (D9 of the ops spec). | `string` | n/a | yes |
| <a name="input_spot_allocation_strategy"></a> [spot\_allocation\_strategy](#input\_spot\_allocation\_strategy) | How the ASG allocates spot capacity. price-capacity-optimized balances price with the deepest, least-interruption-prone pools; capacity-optimized minimises interruptions; lowest-price chases cost (most interruptions). spot\_instance\_pools is emitted ONLY for lowest-price. | `string` | `"price-capacity-optimized"` | no |
| <a name="input_spot_instance_pools"></a> [spot\_instance\_pools](#input\_spot\_instance\_pools) | Number of spot pools per AZ — ONLY valid with lowest-price allocation (AWS rejects it otherwise). Ignored for the capacity-optimized strategies. | `number` | `null` | no |
| <a name="input_subnet_ids"></a> [subnet\_ids](#input\_subnet\_ids) | Subnet IDs for the manager and the worker ASG (public subnets in the ops design — no NAT). Spread across AZs for spot resilience. | `list(string)` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to every taggable resource the module creates. | `map(string)` | `{}` | no |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | VPC the manager and workers run in. | `string` | n/a | yes |
| <a name="input_worker_ami_name_filter"></a> [worker\_ami\_name\_filter](#input\_worker\_ami\_name\_filter) | AMI name filter for the worker AMI (default: Ubuntu 24.04 amd64). | `string` | `"ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"` | no |
| <a name="input_worker_ami_owners"></a> [worker\_ami\_owners](#input\_worker\_ami\_owners) | AMI owner account IDs for the worker AMI lookup (default: Canonical). | `list(string)` | <pre>[<br/>  "099720109477"<br/>]</pre> | no |
| <a name="input_worker_instance_types"></a> [worker\_instance\_types](#input\_worker\_instance\_types) | amd64 instance types for the spot worker pool (mixed-instances). Job images are amd64. More types = better spot availability. | `list(string)` | <pre>[<br/>  "m7i-flex.large",<br/>  "c7i-flex.large",<br/>  "m6i.large",<br/>  "c6i.large",<br/>  "t3.large"<br/>]</pre> | no |
| <a name="input_worker_root_volume_size"></a> [worker\_root\_volume\_size](#input\_worker\_root\_volume\_size) | Worker root volume size (GB). Docker images + a single Rust build (cargo + target/) need generous headroom; 8 GB (the usual default) is far too small (D15). | `number` | `200` | no |
| <a name="input_worker_volume_type"></a> [worker\_volume\_type](#input\_worker\_volume\_type) | Worker root volume type. | `string` | `"gp3"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_cache_s3_bucket"></a> [cache\_s3\_bucket](#output\_cache\_s3\_bucket) | S3 distributed-cache bucket name (empty when S3 cache is disabled). |
| <a name="output_efs_id"></a> [efs\_id](#output\_efs\_id) | Shared EFS cache filesystem ID (null when EFS cache is disabled). |
| <a name="output_manager_asg_name"></a> [manager\_asg\_name](#output\_manager\_asg\_name) | Name of the manager Auto Scaling Group (size 1). |
| <a name="output_manager_iam_role_arn"></a> [manager\_iam\_role\_arn](#output\_manager\_iam\_role\_arn) | ARN of the manager instance role. |
| <a name="output_worker_asg_name"></a> [worker\_asg\_name](#output\_worker\_asg\_name) | Name of the spot worker Auto Scaling Group (the fleeting plugin\_config target). |
| <a name="output_worker_security_group_id"></a> [worker\_security\_group\_id](#output\_worker\_security\_group\_id) | Worker security group ID. |
<!-- END_TF_DOCS -->
