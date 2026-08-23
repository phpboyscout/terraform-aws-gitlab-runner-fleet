# AGENTS.md

This file provides guidance to AI coding agents (Claude Code, agy, codex, etc.) when
working with code in this repository.

Ways of working live in the phpboyscout skills and are not repeated here, since naming
a skill ages better than restating it.

## What this is

An OpenTofu module — 28 variables, 6 outputs, 20 resources — provisioning a GitLab
Runner *fleeting* fleet on AWS: one always-on manager in an ASG of 1 (`main.tf:454`)
running `gitlab-runner` plus `fleeting-plugin-aws`, and a spot worker ASG sitting at
`desired_capacity = 0` until the manager sizes it up (`main.tf:367`). Around those: up
to three security groups, two instance roles, an optional S3 distributed cache, an
optional EFS shared cache, and a KMS grant letting Auto Scaling use the account's EBS
CMK (`main.tf:312`). It creates no VPC, no backend and no provider block, and does not
register the runner — the caller supplies `vpc_id`, `subnet_ids` and an SSM
SecureString name holding a pre-registered group-runner token, which the manager reads
at boot and substitutes into `config.toml`
(`templates/manager-user-data.sh.tftpl:10,17`) so it never reaches state.

Why this exists rather than `cattle-ops/gitlab-runner` is in the `phpboyscout/infra`
wiki, specs 0014 and 0015; the `D<n>` markers through `variables.tf` and `main.tf` cite
0015's decisions. Read it before changing a default — most are an argument already had.

## Blast radius

`phpboyscout/infra` is the only project in the group calling this module
(`src/main.gitlab-runner.tf:65`, pinned `version = "0.1.2"` from the GitLab module
registry) — measured 2026-08-23 across all 125 non-archived group projects, searching
for `terraform-aws-gitlab-runner-fleet` and `gitlab-runner-fleet/aws`.

That one consumer is a large share of the estate's CI capacity. Sampling the last 100
finished jobs in each of the 20 most recently active group projects, 991 of 2000 ran
on the AWS fleet and 1009 on the homelab runner. Both are untagged group runners with
`run_untagged = true`, so the fleet is overflow capacity rather than the only place
jobs land: break it and pipelines queue rather than fail, break it badly and
group-wide throughput roughly halves. infra passes 8 of the 28 variables, so every
other default in `variables.tf` is live ops configuration — editing one is an
infrastructure change wearing a module diff.

## Which skills apply here

| When | Skill |
|---|---|
| Changing `main.tf`, `variables.tf` or the templates | `spec-driven-development` |
| Before calling a change safe — no credentials here, so no plan | `verify-dont-trust` |
| Writing or restructuring `docs/` and the README prose | `diataxis-docs` |
| Writing anything others will read and check | `checkable-claims` |
| Writing a commit message (the `commit-msg` hook enforces the format) | `conventional-commits` |
| Branching, pushing, opening a merge request | `forge-publish-workflow` |
| A release is due, or the Release MR needs a look | `releaser-pleaser-releases`, `pre-1-0-release-safety` |
| Bumping the pinned `phpboyscout/cicd` components or the AWS provider | `adopt-shared-components`, `assess-before-bumping` |
| Working in a repo other than the one you were invoked in | `cross-repo-worktree` |

> Skills are a Claude Code mechanism, shipped by the
> [phpboyscout marketplace](https://gitlab.com/phpboyscout/claude-code-plugins). An agent
> without them should treat a named skill as a topic to ask about, not a file it can load.

## What people get wrong here

**Almost any config change rolls the manager, and the diff does not say so.**
`config.toml` is rendered into the manager's base64 user data (`main.tf:56-61`), so
touching `idle_time`, `capacity_per_instance`, `runner_environment`,
`runner_docker_volumes`, `runner_pre_build_script`, either cache flag or
`max_instances` rewrites the launch template — and the manager ASG's
`instance_refresh` runs at `min_healthy_percentage = 0` (`main.tf:467-472`). The
fleet's control plane goes away and comes back; no plan says "CI stops dispatching".

**The fleeting plugin owns worker capacity, not OpenTofu.** The worker ASG sets
`desired_capacity = 0` with `ignore_changes` (`main.tf:371,404`) and
`protect_from_scale_in = true` (`main.tf:376`). A plan showing zero against a live
fleet of four is correct; removing either is how the ASG starts terminating workers
mid-job.

**`spot_instance_pools` is silently dropped unless the strategy is `lowest-price`**
(`main.tf:385`) — AWS rejects that pairing, so the module nulls it. Set alongside
`price-capacity-optimized` it gives no error and no effect.

**`max_instances` is three ceilings at once**: ASG `max_size` (`main.tf:370`),
`concurrent` and `limit` in the runner config (`templates/config.toml.tftpl:6`, `:18`),
and the autoscaler's own `max_instances` (`:47`). It is the cost guardrail, capped at 50
(`variables.tf:97-100`); with `worker_root_volume_size` defaulting to 200 GB
(`variables.tf:80-84`) it moves concurrency and bill at once.

**The EFS mount is deliberately best-effort and fails quietly.**
`templates/worker-user-data.sh.tftpl:14-27` runs it under `set +e` and ends `exit 0`,
so a broken mount gives slow jobs, not a failed worker. That mount is already behind
issue #2: `CARGO_HOME` lives on EFS (`variables.tf:166`), NFS cannot lock, and
`cargo-audit` / `cargo-deny` fail intermittently under concurrency. Read it before
moving anything onto or off the shared cache.

**Two things float that look pinned**: the worker AMI (`most_recent = true`,
`main.tf:11-23`) and the fleeting plugin (`aws:latest`, installed at boot —
`templates/config.toml.tftpl:42`, `templates/manager-user-data.sh.tftpl:20`).

## Working here

`tofu fmt -check -recursive`, `tofu init -backend=false && tofu validate` (root and
`examples/minimal`) and `tflint --recursive` all pass on `main` as of 2026-08-23 and
none need AWS credentials. There is no justfile and no test suite, and no `tofu plan`
is possible here — no credentials, no state — so validation is the ceiling of what is
provable locally; the proof is an apply from `phpboyscout/infra`.

Two CI checks `pre-commit run --all-files` will not catch: `checkov` runs in the
`tofu-security` component with no pre-commit hook, so a new resource may need a
`checkov:skip=` line carrying a rationale (existing ones at `main.tf:73-77`, `111`, `189`,
`231-232`); and `tofu-lint` includes a `terraform-docs-drift` job, so adding or
re-describing a variable means regenerating the `BEGIN_TF_DOCS` block in `README.md` and
`examples/minimal/README.md`. Docs-only merge requests skip the tofu jobs, which gate on
changed `.tf` paths; security jobs always run. `.github/` holds one file, `README.md`, and
no workflows — it is the front page of the read-only GitHub push mirror; CI is GitLab CI.

This project merges with a merge commit (`merge_method = merge`), unlike most of the
estate, so your merge request will produce one; that drift from the house
rebase-and-fast-forward standard is tracked in `phpboyscout/org`, so leave it be.
Conventional Commits still decide releases — only `feat` and `fix` cut one, and cutting
it is the maintainer's call, never yours. Nothing published here carries AI attribution,
and nothing at-mentions anyone.
