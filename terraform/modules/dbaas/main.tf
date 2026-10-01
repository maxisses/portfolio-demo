# DBaaS: eine PostgreSQL-Datenbank (Amazon RDS) pro Bestellung. AAP führt diesen Baustein im
# Execution Environment aus (cloud.terraform), mit eigenem State-Key pro Datenbank.
# Zugangsdaten landen in AWS Secrets Manager; in den Namespace kommen sie per ExternalSecret.
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
  description = "Name der Datenbank (Kleinbuchstaben, Ziffern, Bindestriche)"
  type        = string
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,30}$", var.name))
    error_message = "Name: 2-31 Zeichen, Kleinbuchstaben, Ziffern, Bindestriche, Beginn mit Buchstabe."
  }
}

variable "groesse" {
  description = "klein oder mittel"
  type        = string
  default     = "klein"
  validation {
    condition     = contains(["klein", "mittel"], var.groesse)
    error_message = "groesse: klein oder mittel"
  }
}

variable "namespace" {
  description = "Ziel-Namespace auf dem Hub (nur zur Kennzeichnung)"
  type        = string
}

variable "postgis" {
  description = "PostGIS-Erweiterung anlegen (Localnews braucht sie)"
  type        = bool
  default     = true
}

variable "requester" {
  type    = string
  default = "unbekannt"
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
  klass = { klein = "db.t4g.micro", mittel = "db.t4g.small" }
  db    = replace(var.name, "-", "_")
}

resource "random_password" "db" {
  length  = 24
  special = false
}

resource "aws_security_group" "db" {
  name        = "portfolio-demo-dbaas-${var.name}"
  description = "PostgreSQL nur aus der VPC (ROSA-Worker)"
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
  instance_class         = local.klass[var.groesse]
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

# Erweiterungen in der Datenbank. Die AAP-VM liegt in derselben VPC und erreicht RDS direkt.
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
