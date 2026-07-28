terraform {
  required_version = "~> 1.12.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    # Manager↔worker SSH key generation for the fleeting connector.
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}
