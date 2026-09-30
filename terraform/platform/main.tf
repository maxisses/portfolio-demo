# AWS-Seite der Plattform-Dienste im Cluster:
# - IRSA-Rolle, mit der der External Secrets Operator Secrets Manager liest
# - Zufallspasswort der MaaS-Datenbank (nur in Secrets Manager, nie in Git)
variable "region" {
  type    = string
  default = "eu-central-1"
}

data "aws_caller_identity" "current" {}

data "terraform_remote_state" "rosa" {
  backend = "s3"
  config = {
    bucket = "portfolio-demo-tfstate-${data.aws_caller_identity.current.account_id}"
    key    = "rosa/terraform.tfstate"
    region = var.region
  }
}

locals {
  oidc_host = trimprefix(data.terraform_remote_state.rosa.outputs.oidc_endpoint_url, "https://")
}

resource "aws_iam_role" "eso" {
  name = "portfolio-demo-external-secrets"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${local.oidc_host}" }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${local.oidc_host}:sub" = "system:serviceaccount:external-secrets:eso-aws"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy" "eso" {
  name = "read-portfolio-demo-secrets"
  role = aws_iam_role.eso.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
      Resource = "arn:aws:secretsmanager:${var.region}:${data.aws_caller_identity.current.account_id}:secret:portfolio-demo/*"
    }]
  })
}

resource "random_password" "maas_db" {
  length  = 24
  special = false
}

resource "aws_secretsmanager_secret" "maas_db" {
  name                    = "portfolio-demo/maas/db"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "maas_db" {
  secret_id = aws_secretsmanager_secret.maas_db.id
  secret_string = jsonencode({
    POSTGRES_USER     = "maas"
    POSTGRES_PASSWORD = random_password.maas_db.result
    POSTGRES_DB       = "maas"
    # maas-api im selben Namespace wie die Datenbank
    DB_URL_LOCAL = "postgresql://maas:${random_password.maas_db.result}@postgres:5432/maas?sslmode=disable"
    # Gateway-Infrastruktur in anderem Namespace
    DB_URL_REMOTE = "postgresql://maas:${random_password.maas_db.result}@postgres.redhat-ods-applications.svc:5432/maas?sslmode=disable"
  })
}

output "eso_role_arn" {
  value = aws_iam_role.eso.arn
}
