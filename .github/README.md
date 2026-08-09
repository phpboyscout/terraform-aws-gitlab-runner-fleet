# terraform-aws-gitlab-runner-fleet

**A GitLab Runner fleeting fleet on AWS: one always-on manager, scale-to-zero
spot workers.** Uses the `docker-autoscaler` executor with `fleeting-plugin-aws`,
and deliberately exposes the levers that off-the-shelf modules hide — spot
allocation strategy, worker Docker install and disk size, and cache backend.
Pre-1.0, so pin to a tag rather than a branch.

> **This is a read-only mirror. The canonical repository is on GitLab:**
> **https://gitlab.com/phpboyscout/iac/terraform-aws-gitlab-runner-fleet**
>
> Issues and merge requests are handled there.

## Using it

Published to GitLab's Terraform module registry, so consume it from there
rather than from a git source:

```hcl
module "runner_fleet" {
  source  = "gitlab.com/phpboyscout/gitlab-runner-fleet/aws"
  version = "0.1.0"
}
```

## Documentation

Full documentation: **https://aws-gitlab-runner-fleet.iac.phpboyscout.uk**

The infrastructure it belongs to is written up in
[Infrastructure with AWS and OpenTofu](https://phpboyscout.uk/topics/infrastructure/).
