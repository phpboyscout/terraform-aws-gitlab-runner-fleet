# Changelog

## [v0.3.1](https://gitlab.com/phpboyscout/iac/terraform-aws-gitlab-runner-fleet/-/releases/v0.3.1)

[Compare to previous version](https://gitlab.com/phpboyscout/iac/terraform-aws-gitlab-runner-fleet/-/compare/v0.3.0...v0.3.1)

### Notes

- The declared `required_version` is widened from `~> 1.12.5` to the floor `>= 1.5.0`, the oldest version the module supports. OpenTofu 1.12 and later do not enforce it in a `.tf` file, and Terraform users on any release from 1.5 onward are no longer refused. CI still tests on the OpenTofu release pinned in `.opentofu-version`.

- The module once again constrains the `hashicorp/aws` provider to `~> 6.0` rather than an exact version. From 2026-09-01 until this release, Renovate had re-pinned it exactly, so a consuming stack whose lock file was on a different 6.x provider could not `init` with this module.

### Bug Fixes

- declare required_version as the floor >= 1.5.0 ([d99a568](https://gitlab.com/phpboyscout/iac/terraform-aws-gitlab-runner-fleet/-/commit/d99a56802d915f81a6170a99763c745fa5b1fd6c))
- constrain the aws provider by range again ([342c7d6](https://gitlab.com/phpboyscout/iac/terraform-aws-gitlab-runner-fleet/-/commit/342c7d6a4c43bfc41265456aac465f94c0f2d5c0))

## [v0.3.0](https://gitlab.com/phpboyscout/iac/terraform-aws-gitlab-runner-fleet/-/releases/v0.3.0)

[Compare to previous version](https://gitlab.com/phpboyscout/iac/terraform-aws-gitlab-runner-fleet/-/compare/v0.2.0...v0.3.0)

### Notes

- The default `runner_pre_build_script` no longer exports `CARGO_TARGET_DIR`; it exports only `RUST_CACHE_DIR`. Jobs on the cicd Rust components are unaffected, since they set their own target directory under it. A hand-written job that relied on the runner's shared `/opt/rust-cache/<slug>/target` now builds in its checkout unless it sets `CARGO_TARGET_DIR` itself. Adopting this version replaces the manager instance.

- The usage examples now pin `version = "~> 0.2.0"`. The `0.1.0` they named was never in the module registry, so copying the old snippet failed at `tofu init`.

### Features

- stop setting CARGO_TARGET_DIR in the default pre_build_script ([8af20f7](https://gitlab.com/phpboyscout/iac/terraform-aws-gitlab-runner-fleet/-/commit/8af20f7563dc46ad93b1c425f7f69ea9362a816d))

### Bug Fixes

- **docs**: pin the usage snippets to a version the registry serves ([f54b7d7](https://gitlab.com/phpboyscout/iac/terraform-aws-gitlab-runner-fleet/-/commit/f54b7d78411665950b6393c43643701257f9939b))

## [v0.2.0](https://gitlab.com/phpboyscout/iac/terraform-aws-gitlab-runner-fleet/-/releases/v0.2.0)

[Compare to previous version](https://gitlab.com/phpboyscout/iac/terraform-aws-gitlab-runner-fleet/-/compare/v0.1.4...v0.2.0)

### Notes

- The default `runner_pre_build_script` also exports `RUST_CACHE_DIR=/opt/rust-cache/${CI_PROJECT_PATH_SLUG}`, the project's Rust cache root for the cicd Rust components to key their target directory under. Nothing reads it until those components are released, so job behaviour is unchanged. Like any runner config change, adopting this version replaces the manager instance.

- Releases are announced to the estate's release feed.

### Features

- export RUST_CACHE_DIR beside CARGO_TARGET_DIR in the default pre_build_script ([409e918](https://gitlab.com/phpboyscout/iac/terraform-aws-gitlab-runner-fleet/-/commit/409e91824e867b8efdd4b607b1a1bd273df1f4ec))

### Bug Fixes

- **examples**: use AWS's placeholder account ID in the minimal example KMS ARN ([e3ebddd](https://gitlab.com/phpboyscout/iac/terraform-aws-gitlab-runner-fleet/-/commit/e3ebddd77dfd28819ea1a72b885fa8ddebe272a6))

## [v0.1.4](https://gitlab.com/phpboyscout/iac/terraform-aws-gitlab-runner-fleet/-/releases/v0.1.4)

[Compare to previous version](https://gitlab.com/phpboyscout/iac/terraform-aws-gitlab-runner-fleet/-/compare/v0.1.3...v0.1.4)

### Bug Fixes

- constrain the aws provider by range, not an exact pin ([a57df65](https://gitlab.com/phpboyscout/iac/terraform-aws-gitlab-runner-fleet/-/commit/a57df65f06e555101d3263a79e9242eeec83cca7))

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
