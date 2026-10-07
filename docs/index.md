# terraform-aws-gitlab-runner-fleet

A lean OpenTofu module for a **GitLab Runner fleeting fleet** on AWS: one
always-on manager plus **scale-to-zero spot workers** (the
`docker-autoscaler` executor with `fleeting-plugin-aws`). Purpose-built for the
phpboyscout ops account to replace `cattle-ops/gitlab-runner`, giving full
control over the levers that module hid: spot allocation strategy (no forced
`spot_instance_pools`), the workers' Docker install and disk size, an EFS and S3
cache layer, and no plan-time Lambda (so CI can plan and apply in separate jobs).

The design is spec 0015, *A hand-rolled terraform-aws-gitlab-runner-fleet
module*, in the `phpboyscout/infra` wiki. That project is private, so it is
named here rather than linked.

## Usage

```hcl
module "runner_fleet" {
  source  = "gitlab.com/phpboyscout/gitlab-runner-fleet/aws"
  version = "~> 0.2.0" # pre-1.0, a minor release may break: take patches only

  name_prefix                     = "pbs-ops-runner"
  vpc_id                          = var.vpc_id
  subnet_ids                      = var.subnet_ids
  runner_token_ssm_parameter_name = aws_ssm_parameter.runner_token.name
  ebs_kms_key_arn                 = data.aws_kms_key.ebs_default.arn

  max_instances = 4 # hard spot-instance ceiling (cost guardrail)

  tags = { Project = "phpboyscout", Environment = "ops" }
}
```

Every input and output, with its default, is in the generated tables in the
[README](https://gitlab.com/phpboyscout/iac/terraform-aws-gitlab-runner-fleet/-/blob/main/README.md#inputs).

## Further reading

The blog carries a curated route through this subject: **[Infrastructure with AWS and OpenTofu](https://phpboyscout.uk/topics/infrastructure/)** collects
everything written about it, ordered so you can start at the beginning rather
than newest-first.

!!! tip "Ask phpbotscout"

    ![phpbotscout](https://phpboyscout.uk/images/projects/logo-phpbotscout.png){ width="84" align=left style="border-radius:10px;margin-right:1rem" }

    He answers questions about the projects over on the Discord, citing the docs
    where they already cover it, and offering to raise an issue where they don't.
    Bring a bug, an idea, or a questionable engineering decision.

    [Join the Discord](https://discord.gg/mQzGbmGyzZ){ .md-button .md-button--primary }
