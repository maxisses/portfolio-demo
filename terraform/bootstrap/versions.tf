terraform {
  required_version = ">= 1.10"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
  # Bewusst lokaler State: Dieser Baustein erzeugt erst den Bucket, in dem alle
  # anderen States liegen. Die Datei ist gitignoriert.
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
