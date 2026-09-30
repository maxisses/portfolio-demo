# Rolle der AAP-VM. Damit laufen Terraform (DBaaS) und certbot ohne statische Keys.
data "aws_caller_identity" "current" {}

locals {
  state_bucket = "portfolio-demo-tfstate-${data.aws_caller_identity.current.account_id}"
}

resource "aws_iam_role" "aap" {
  name = "portfolio-demo-aap-vm"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "aap" {
  name = "portfolio-demo-aap-vm"
  role = aws_iam_role.aap.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "TerraformState"
        Effect   = "Allow"
        Action   = ["s3:ListBucket", "s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
        Resource = ["arn:aws:s3:::${local.state_bucket}", "arn:aws:s3:::${local.state_bucket}/*"]
      },
      {
        Sid      = "DbaasSecrets"
        Effect   = "Allow"
        Action   = ["secretsmanager:*"]
        Resource = "arn:aws:secretsmanager:${var.region}:${data.aws_caller_identity.current.account_id}:secret:portfolio-demo/*"
      },
      {
        Sid    = "DbaasRds"
        Effect = "Allow"
        Action = [
          "rds:*",
          "ec2:Describe*",
          "ec2:CreateSecurityGroup", "ec2:DeleteSecurityGroup",
          "ec2:AuthorizeSecurityGroupIngress", "ec2:RevokeSecurityGroupIngress",
          "ec2:AuthorizeSecurityGroupEgress", "ec2:RevokeSecurityGroupEgress",
          "ec2:CreateTags", "ec2:DeleteTags"
        ]
        Resource = "*"
      },
      {
        Sid      = "CertbotDns"
        Effect   = "Allow"
        Action   = ["route53:ChangeResourceRecordSets", "route53:GetChange", "route53:ListHostedZones", "route53:ListResourceRecordSets"]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_instance_profile" "aap" {
  name = "portfolio-demo-aap-vm"
  role = aws_iam_role.aap.name
}
