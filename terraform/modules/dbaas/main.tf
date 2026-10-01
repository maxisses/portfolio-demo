# DBaaS: one PostgreSQL database (Amazon RDS) per order. AAP runs this module in its
# execution environment (cloud.terraform), with its own state key per database.
# Credentials go to AWS Secrets Manager; the namespace gets them through an ExternalSecret.
terraform {
  required_version = ">= 1.10"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    postgresql = {
      source  = "cyrilgdn/postgresql"
      version = "~> 1.25"
    }
  }
  backend "s3" {
    region       = "eu-central-1"
    use_lockfile = true
    encrypt      = true
  }
}

variable "name" {
  description = "Database name (lowercase letters, digits, dashes)"
  type        = string
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,30}$", var.name))
    error_message = "name: 2-31 characters, lowercase letters, digits, dashes, starting with a letter."
  }
}

variable "size" {
  description = "small or medium"
  type        = string
  default     = "small"
  validation {
    condition     = contains(["small", "medium"], var.size)
    error_message = "size: small or medium"
  }
}

variable "namespace" {
  description = "Target namespace on the hub (labelling only)"
  type        = string
}

variable "postgis" {
  description = "Create the PostGIS extension (Localnews needs it)"
  type        = bool
  default     = true
}

variable "requester" {
  type    = string
  default = "unknown"
}

variable "region" {
  type    = string
  default = "eu-central-1"
}

provider "aws" {
  region = var.region
  default_tags {
    tags = {
      Project   = "portfolio-demo"
      Owner     = "mdargatz"
      ManagedBy = "ansible"
      Catalog   = "dbaas"
      Requester = var.requester
      Namespace = var.namespace
    }
  }
}

data "aws_caller_identity" "current" {}

data "terraform_remote_state" "foundation" {
  backend = "s3"
  config = {
    bucket = "portfolio-demo-tfstate-${data.aws_caller_identity.current.account_id}"
    key    = "foundation/terraform.tfstate"
    region = var.region
  }
}

locals {
  net   = data.terraform_remote_state.foundation.outputs
  class = { small = "db.t4g.micro", medium = "db.t4g.small" }
  db    = replace(var.name, "-", "_")
}

resource "random_password" "db" {
  length  = 24
  special = false
}

resource "aws_security_group" "db" {
  name        = "portfolio-demo-dbaas-${var.name}"
  description = "PostgreSQL from the VPC only (ROSA workers)"
  vpc_id      = local.net.vpc_id
  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [local.net.vpc_cidr]
  }
}

resource "aws_db_instance" "db" {
  identifier             = "portfolio-demo-${var.name}"
  engine                 = "postgres"
  engine_version         = "16"
  instance_class         = local.class[var.size]
  allocated_storage      = 20
  storage_type           = "gp3"
  storage_encrypted      = true
  db_name                = local.db
  username               = "app"
  password               = random_password.db.result
  db_subnet_group_name   = local.net.database_subnet_group
  vpc_security_group_ids = [aws_security_group.db.id]
  publicly_accessible    = false
  skip_final_snapshot    = true
  apply_immediately      = true
  deletion_protection    = false
}

# Extensions in the database. The AAP VM is in the same VPC and reaches RDS directly.
provider "postgresql" {
  host            = aws_db_instance.db.address
  port            = aws_db_instance.db.port
  database        = local.db
  username        = "app"
  password        = random_password.db.result
  sslmode         = "require"
  connect_timeout = 30
  superuser       = false
}

resource "postgresql_extension" "postgis" {
  count    = var.postgis ? 1 : 0
  name     = "postgis"
  database = local.db
}

resource "aws_secretsmanager_secret" "db" {
  name                    = "portfolio-demo/dbaas/${var.name}"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "db" {
  secret_id = aws_secretsmanager_secret.db.id
  secret_string = jsonencode({
    host     = aws_db_instance.db.address
    port     = tostring(aws_db_instance.db.port)
    dbname   = local.db
    username = "app"
    password = random_password.db.result
    uri      = "postgresql://app:${random_password.db.result}@${aws_db_instance.db.address}:${aws_db_instance.db.port}/${local.db}?sslmode=require"
  })
}

output "endpoint" {
  value = "${aws_db_instance.db.address}:${aws_db_instance.db.port}"
}

output "secret_name" {
  value = aws_secretsmanager_secret.db.name
}
