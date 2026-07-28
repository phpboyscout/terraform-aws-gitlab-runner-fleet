# Security Policy

## Supported Versions

Pre-1.0: only the latest `0.y` minor receives security fixes. The current
supported line is whatever appears as the latest tag on the `main` branch.

## Reporting a Vulnerability

**Please do not open public GitLab issues for security problems.**

Report vulnerabilities by email to **security@phpboyscout.uk**. Include:

- A description of the issue and its potential impact.
- Steps to reproduce, or a proof-of-concept.
- The module version (tag or commit SHA) you observed it in.
- Your name and affiliation, if you'd like to be credited.

You should receive an acknowledgement within **48 hours**. We will follow up
with a remediation plan and disclosure timeline. Credit will be given in the
changelog and release notes unless you request otherwise.

## Scope

**In scope**

- The OpenTofu / Terraform module code in this repository.
- The CI/CD configuration (GitHub Actions workflows).
- Default AWS resource configurations the module produces (IAM trust policies,
  S3 bucket policies, KMS key policies).

**Out of scope**

- Vulnerabilities in upstream providers (`hashicorp/aws`) — report to the
  provider's maintainers.
- Vulnerabilities in upstream modules we depend on (`terraform-aws-modules/*`) —
  report to those projects.
- Misconfiguration in *callers* of this module (we provide secure defaults;
  callers can override them).
