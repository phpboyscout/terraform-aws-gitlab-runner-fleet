terraform {
  required_version = "~> 1.12.5"

  required_providers {
    aws = {
      source = "hashicorp/aws"
      # Range, not an exact pin. Provider constraints from every module in a
      # configuration are intersected, so an exact pin here forces the whole
      # consuming stack onto one provider build — and then the consumer cannot
      # init until its own lock file happens to match. Matches the estate's
      # other registry modules (bootstrap, security-baseline, encryption-kms).
      #
      # It was "6.61.0" up to v0.1.3, which is Renovate treating this like a
      # root module. phpboyscout/infra could not take v0.1.3 at all: its lock
      # was on 6.60.0 and the intersected constraint became unsatisfiable.
      version = "6.62.0"
    }
  }
}
