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
