terraform {
  required_version = ">= 1.10"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
  # Bucket kommt aus terraform/bootstrap. Name enthält die Account-ID, deshalb per
  # `-backend-config="bucket=..."` beim init (siehe scripts/tf.sh).
  backend "s3" {
    key          = "foundation/terraform.tfstate"
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
