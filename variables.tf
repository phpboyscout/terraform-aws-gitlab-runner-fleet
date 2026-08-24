# ----------------------------------------------------------------------
# Input contract for terraform-aws-gitlab-runner-fleet — a lean GitLab
# Runner fleeting fleet (one always-on manager + scale-to-zero spot
# workers) that we own, replacing cattle-ops/gitlab-runner for the
# phpboyscout ops fleet. See phpboyscout/infra spec
# 2026-07-28-hand-rolled-runner-fleet-module (D1–D8).
# ----------------------------------------------------------------------

# --- identity / tagging ------------------------------------------------

variable "name_prefix" {
  description = "Prefix for all resource names, e.g. \"pbs-ops-runner\". Kept short — it seeds ASG, launch-template, IAM, EFS and SG names."
  type        = string
}

variable "tags" {
  description = "Tags applied to every taggable resource the module creates."
  type        = map(string)
  default     = {}
}

# --- networking (caller-provided; the module never creates a VPC) ------

variable "vpc_id" {
  description = "VPC the manager and workers run in."
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs for the manager and the worker ASG (public subnets in the ops design — no NAT). Spread across AZs for spot resilience."
  type        = list(string)

  validation {
    condition     = length(var.subnet_ids) > 0
    error_message = "At least one subnet is required."
  }
}

# --- GitLab wiring -----------------------------------------------------

variable "gitlab_url" {
  description = "GitLab instance URL the runner registers against."
  type        = string
  default     = "https://gitlab.com"
}

variable "runner_token_ssm_parameter_name" {
  description = "Name of the SSM SecureString parameter holding the pre-registered group-runner authentication token (glrt-…). The manager reads it at boot; never passed as a literal (D9 of the ops spec)."
  type        = string
}

variable "runner_agent_version" {
  description = "gitlab-runner version installed on the manager (workers run job containers, not the agent). Pin the latest stable; Renovate-tracked."
  type        = string
  default     = "19.2.0"
}

# --- the always-on manager --------------------------------------------

variable "manager_instance_type" {
  description = "Manager EC2 type. It only runs gitlab-runner + the fleeting plugin (never job containers), so the smallest sane instance is right."
  type        = string
  default     = "t3.micro"
}

variable "manager_root_volume_size" {
  description = "Manager root volume size (GB). It stores no build artifacts."
  type        = number
  default     = 8
}

# --- the scale-to-zero spot worker pool -------------------------------

variable "worker_instance_types" {
  description = "amd64 instance types for the spot worker pool (mixed-instances). Job images are amd64. More types = better spot availability."
  type        = list(string)
  default     = ["m7i-flex.large", "c7i-flex.large", "m6i.large", "c6i.large", "t3.large"]
}

variable "worker_root_volume_size" {
  description = "Worker root volume size (GB). Docker images + a single Rust build (cargo + target/) need generous headroom; 8 GB (the usual default) is far too small (D15)."
  type        = number
  default     = 200
}

variable "worker_volume_type" {
  description = "Worker root volume type."
  type        = string
  default     = "gp3"
}

variable "max_instances" {
  description = "HARD CEILING on spot worker instances (ASG max_size AND the fleeting autoscaler max_instances). With capacity_per_instance = 1 this caps concurrent jobs AND running instances — the primary cost guardrail."
  type        = number
  default     = 4

  validation {
    condition     = var.max_instances >= 1 && var.max_instances <= 50
    error_message = "max_instances is a cost guardrail; keep it modest and raise deliberately."
  }
}

variable "capacity_per_instance" {
  description = "Jobs a single worker runs concurrently. 1 keeps the max_instances ceiling equal to the concurrent-job ceiling."
  type        = number
  default     = 1
}

variable "idle_time" {
  description = "How long an idle worker lingers before the autoscaler scales it in (a short reuse window for bursty backlogs, then back to zero). idle_count is fixed at 0 — pure scale-to-zero."
  type        = string
  default     = "10m0s"
}

# --- spot allocation (the lever cattle-ops denied us, D16) -------------

variable "spot_allocation_strategy" {
  description = "How the ASG allocates spot capacity. price-capacity-optimized balances price with the deepest, least-interruption-prone pools; capacity-optimized minimises interruptions; lowest-price chases cost (most interruptions). spot_instance_pools is emitted ONLY for lowest-price."
  type        = string
  default     = "price-capacity-optimized"

  validation {
    condition     = contains(["price-capacity-optimized", "capacity-optimized", "lowest-price"], var.spot_allocation_strategy)
    error_message = "spot_allocation_strategy must be price-capacity-optimized, capacity-optimized or lowest-price."
  }
}

variable "spot_instance_pools" {
  description = "Number of spot pools per AZ — ONLY valid with lowest-price allocation (AWS rejects it otherwise). Ignored for the capacity-optimized strategies."
  type        = number
  default     = null
}

# --- worker AMI (Ubuntu; Docker is installed via cloud-init) ----------

variable "worker_ami_owners" {
  description = "AMI owner account IDs for the worker AMI lookup (default: Canonical)."
  type        = list(string)
  default     = ["099720109477"]
}

variable "worker_ami_name_filter" {
  description = "AMI name filter for the worker AMI (default: Ubuntu 24.04 amd64)."
  type        = string
  default     = "ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"
}

# --- caching parity with runner1 (D8) ---------------------------------

variable "enable_efs_cache" {
  description = "Provision a shared EFS filesystem and mount it on every worker for the read-mostly caches — scanner vuln DBs (/opt/ci-cache) and the cargo registry (/opt/rust-cache/shared) — matching runner1's host mounts. The rustup home is deliberately NOT shared (see runner_environment); write-heavy Rust target/ is deliberately NOT on EFS (see runner_docker_volumes / S3 cache)."
  type        = bool
  default     = true
}

variable "runner_docker_volumes" {
  description = "Docker volume mounts applied to every job container (mirrors runner1's [runners.docker] volumes). Defaults expose the EFS-backed shared caches plus the local /cache. Paths must exist on the worker (the module's user-data creates/mounts them)."
  type        = list(string)
  default     = ["/cache", "/opt/ci-cache:/opt/ci-cache:rw", "/opt/rust-cache/shared:/opt/rust-cache/shared:rw"]
}

# The shared cache: registry YES, rustup home NO.
#
# CARGO_HOME on the shared mount is the win — the crate registry is read-mostly,
# cargo locks it for concurrent access, and it is what stops every job
# re-downloading the index.
#
# RUSTUP_HOME on the shared mount is a defect, and was the default here until
# 2026-08-24. A rustup home is not read-mostly: any job whose rust-toolchain.toml
# asks for something the image lacks INSTALLS into it, and up to max_instances
# workers share one EFS filesystem. Concurrent installs leave a half-written
# toolchain that rustup then reports as healthy — `rustup component add` answers
# "up to date" against a toolchain missing the component — and the failure
# surfaces later, elsewhere, as "the '<binary>' binary ... is not applicable to
# the '<version>' toolchain". It corrupts state rather than failing cleanly, so
# it reads as flaky tests until someone inspects the toolchain directory.
# See phpboyscout/infra#6: it happened on runner1, was hand-repaired, then
# recurred on this fleet with the shared 1.98.0 missing rustc itself.
#
# The rust-tools image already solves this: it bakes the toolchain its consumers
# pin, at the image's own /usr/local/rustup, precisely so a job READS rather than
# WRITES. Overriding RUSTUP_HOME here discarded that design wholesale.
#
# Dropping it does not eliminate job-time installs — a repo pinning
# profile = "default" still pulls rust-docs — it makes them land in the container
# and die with it, rather than in a directory every worker shares.
variable "runner_environment" {
  description = "Runner-level environment applied to every job. CARGO_HOME points at the shared cache (read-mostly, cargo-locked); RUSTUP_HOME deliberately does NOT — a shared rustup home is corrupted by concurrent installs, and the Rust image bakes the toolchain its consumers pin. See phpboyscout/infra#6."
  type        = list(string)
  default = [
    "CARGO_HOME=/opt/rust-cache/shared/cargo-home",
    "CARGO_NET_GIT_FETCH_WITH_CLI=true",
  ]
}

# No PATH prepend of the shared cargo-home/bin, for the same reason: past jobs
# write rustup proxies there, and it shadows the Rust image's baked CI tools
# (cargo-nextest, cargo-llvm-cov, cargo-deny, cargo-audit) with whatever an
# earlier job happened to leave. rust-lint failed loudly when a proxy was stale;
# a shadowed cargo-audit would have failed quietly, as a wrong answer.
variable "runner_pre_build_script" {
  description = "Runner pre_build_script. Kept configurable because it needs CI-var expansion the static environment can't do. CARGO_TARGET_DIR (write-heavy) points at local worker disk, NOT the EFS mount, to avoid network-FS latency on cargo's small-file I/O (D8)."
  type        = string
  default     = "export CARGO_TARGET_DIR=\"/opt/rust-cache/$${CI_PROJECT_PATH_SLUG}/target\""
}

variable "cache_s3_bucket" {
  description = "Optional existing S3 bucket for the distributed GitLab cache (cache: keys, e.g. tofu-plugin-cache). When null and enable_s3_cache is true the module creates one."
  type        = string
  default     = null
}

variable "enable_s3_cache" {
  description = "Configure the runner's [runners.cache] for S3 so GitLab cache: keys survive across ephemeral workers."
  type        = bool
  default     = true
}

# --- IAM / KMS ---------------------------------------------------------

variable "ebs_kms_key_arn" {
  description = "ARN of the CMK encrypting worker/manager EBS volumes (the account's EBS default key). The module grants the Auto Scaling service-linked role use of it — required when the account enforces CMK EBS encryption, or ASG instances die with Client.InvalidKMSKey.InvalidState (D13). Null skips the grant (AWS-managed key in use)."
  type        = string
  default     = null
}

variable "iam_permissions_boundary" {
  description = "Optional IAM permissions-boundary policy ARN applied to the roles the module creates."
  type        = string
  default     = null
}

variable "manager_ssm_access" {
  description = "Attach AmazonSSMManagedInstanceCore to the manager for operator access (patching/debug)."
  type        = bool
  default     = true
}
