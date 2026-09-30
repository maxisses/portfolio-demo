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
  net = data.terraform_remote_state.foundation.outputs
}

resource "random_password" "cluster_admin" {
  length           = 20
  special          = true
  override_special = "-_"
  min_upper        = 2
  min_lower        = 2
  min_numeric      = 2
}

resource "random_password" "engineer" {
  length  = 16
  special = false
}

module "hcp" {
  source  = "terraform-redhat/rosa-hcp/rhcs"
  version = "1.7.5"

  cluster_name           = var.cluster_name
  openshift_version      = var.openshift_version
  machine_cidr           = local.net.vpc_cidr
  aws_subnet_ids         = concat(local.net.public_subnet_ids, local.net.private_subnet_ids)
  aws_availability_zones = [local.net.availability_zone]
  replicas               = var.compute_replicas
  compute_machine_type   = var.compute_machine_type

  create_account_roles  = true
  account_role_prefix   = "${var.cluster_name}-account"
  create_oidc           = true
  create_operator_roles = true
  operator_role_prefix  = "${var.cluster_name}-operator"

  # cluster-admin für Bootstrap und Plattform-Betrieb
  admin_credentials_username = "cluster-admin"
  admin_credentials_password = random_password.cluster_admin.result

  # Persona für die Demo: normaler Nutzer ohne Admin-Rechte
  identity_providers = {
    demo-users = {
      name               = "demo-users"
      idp_type           = "htpasswd"
      htpasswd_idp_users = jsonencode([{ username = "engineer", password = random_password.engineer.result }])
    }
  }

  wait_for_create_complete            = true
  wait_for_std_compute_nodes_complete = true
}

# GPU-Pool für das selbst gehostete Granite. Bleibt aus, bis gpu_pool_enabled = true.
module "gpu_pool" {
  count   = var.gpu_pool_enabled ? 1 : 0
  source  = "terraform-redhat/rosa-hcp/rhcs//modules/machine-pool"
  version = "1.7.5"

  cluster_id        = module.hcp.cluster_id
  name              = "gpu"
  openshift_version = var.openshift_version
  subnet_id         = local.net.private_subnet_ids[0]
  auto_repair       = true
  autoscaling = {
    enabled      = true
    min_replicas = 1
    max_replicas = 2
  }
  aws_node_pool = {
    instance_type = var.gpu_instance_type
    tags          = {}
  }
  labels = {
    "node-role.kubernetes.io/gpu" = ""
  }
  taints = [{
    key           = "nvidia.com/gpu"
    value         = "true"
    schedule_type = "NoSchedule"
  }]
}

# Zugangsdaten nie in Git: sie landen in AWS Secrets Manager.
resource "aws_secretsmanager_secret" "rosa_users" {
  name                    = "portfolio-demo/rosa/users"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "rosa_users" {
  secret_id = aws_secretsmanager_secret.rosa_users.id
  secret_string = jsonencode({
    api_url                = module.hcp.cluster_api_url
    console_url            = module.hcp.cluster_console_url
    cluster_admin_username = "cluster-admin"
    cluster_admin_password = random_password.cluster_admin.result
    engineer_username      = "engineer"
    engineer_password      = random_password.engineer.result
  })
}
