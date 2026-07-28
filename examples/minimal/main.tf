# Minimal caller contract, exercised under `tofu validate`.
terraform {
  required_version = "~> 1.12.5"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 6.0" }
  }
}

provider "aws" {
  region                      = "eu-west-2"
  skip_credentials_validation = true
  skip_metadata_api_check     = true
}

module "fleet" {
  source = "../../"

  name_prefix                     = "pbs-ops-runner"
  vpc_id                          = "vpc-00000000000000000"
  subnet_ids                      = ["subnet-00000000000000001", "subnet-00000000000000002"]
  runner_token_ssm_parameter_name = "/pbs-ops/gitlab-runner/authentication-token"
  ebs_kms_key_arn                 = "arn:aws:kms:eu-west-2:617908174105:key/00000000-0000-0000-0000-000000000000"

  tags = { Project = "phpboyscout", Environment = "ops" }
}
