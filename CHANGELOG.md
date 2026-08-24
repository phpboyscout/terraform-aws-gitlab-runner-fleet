# Changelog

## [v0.1.3](https://gitlab.com/phpboyscout/iac/terraform-aws-gitlab-runner-fleet/-/releases/v0.1.3)

[Compare to previous version](https://gitlab.com/phpboyscout/iac/terraform-aws-gitlab-runner-fleet/-/compare/v0.1.0...v0.1.3)

### Bug Fixes

- roll the manager on config change, and stop sharing the rustup home ([bfc8549](https://gitlab.com/phpboyscout/iac/terraform-aws-gitlab-runner-fleet/-/commit/bfc85490d54ab38874f4e0f3ca3a680b1750c568))

## [v0.1.0](https://gitlab.com/phpboyscout/iac/terraform-aws-gitlab-runner-fleet/-/releases/v0.1.0)

### Features

- hand-rolled terraform-aws-gitlab-runner-fleet module (core) ([f8e9c91](https://gitlab.com/phpboyscout/iac/terraform-aws-gitlab-runner-fleet/-/commit/f8e9c91b8274be1e25faf505855a6ed4dea0a0b8))

### Bug Fixes

- **security**: metadata hop-limit 1, SG rule descriptions, justified scan skips ([968b41c](https://gitlab.com/phpboyscout/iac/terraform-aws-gitlab-runner-fleet/-/commit/968b41cac5e0ceeb2e8e877811274ff2d07fa9dd))
- worker EFS cache mount (root+bind, best-effort) so cloud-init never fails ([b20b689](https://gitlab.com/phpboyscout/iac/terraform-aws-gitlab-runner-fleet/-/commit/b20b68949d55a1042aaa8c8b8bd37aaa2325ba7e))
- protect worker ASG instances from scale-in (fleeting requirement) ([7b20114](https://gitlab.com/phpboyscout/iac/terraform-aws-gitlab-runner-fleet/-/commit/7b20114a3b950f3644f31199961f035a1be3b26d))
