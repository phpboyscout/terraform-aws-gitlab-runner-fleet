# AGENTS.md

This file provides guidance to AI coding agents (Claude Code, agy, codex, etc.) when working with code in this repository.

**This file is a seed.** It carries what could be derived from the repository
and checked. What this is really for, where it has got to, and the traps it sets
are not here yet. Issue #4 tracks filling that in.

Ways of working live in the phpboyscout skills and are not repeated here, since
naming a skill ages better than restating it.

## What this is

`terraform-aws-gitlab-runner-fleet` is a reusable OpenTofu and Terraform module in the estate's
infrastructure-as-code set. It carries `examples/` and `docs/`, pins its
OpenTofu version in `.opentofu-version`, and generates reference from
`.terraform-docs.yml`.

**The estate has no Terraform-specific skills**, in the way it has sixteen for
Go. The table below is the language-agnostic set, which is a known gap rather
than an oversight.

## Which skills apply here

| When | Skill |
|---|---|
| Writing or restructuring the module's documentation | `diataxis-docs` |
| Checking this repo against the house defaults | `create-a-phpboyscout-project` |
| Writing anything others will read and check | `checkable-claims` |
| Writing a commit message or a merge request description | `conventional-commits`, `pre-1-0-release-safety` |
| Committing, branching, merging, or opening a merge request | `forge-publish-workflow` |
| Working in a repo other than the one you were invoked in | `cross-repo-worktree` |

> Skills are a Claude Code mechanism, shipped by the
> [phpboyscout marketplace](https://gitlab.com/phpboyscout/claude-code-plugins).
> An agent without them should treat a named skill as a topic to ask about
> rather than a file it can load.

## House rules

- Linear history. Rebase and fast-forward; never squash-merge from the UI.
- Conventional Commits, and the type decides whether a release is cut. Only
  `feat` and `fix` release.
- No AI attribution in anything published, and never at-mention anyone.
- Never cut a release yourself. That is the maintainer's call, every time.

