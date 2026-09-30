terraform {
  required_version = ">= 1.10"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    rhcs = {
      source  = "terraform-redhat/rhcs"
      version = "~> 1.7.9"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
  backend "s3" {
    key          = "rosa/terraform.tfstate"
    region       = "eu-central-1"
    use_lockfile = true
    encrypt      = true
  }
}

provider "aws" {
  region = var.region
  default_tags {
    tags = {
      Project   = "portfolio-demo"
      Owner     = "mdargatz"
      ManagedBy = "terraform"
    }
  }
}

# Anmeldung über RHCS_CLIENT_ID / RHCS_CLIENT_SECRET (Red Hat Service Account) aus .env.
provider "rhcs" {}
