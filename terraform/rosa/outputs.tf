output "cluster_id" {
  value = module.hcp.cluster_id
}

output "api_url" {
  value = module.hcp.cluster_api_url
}

output "console_url" {
  value = module.hcp.cluster_console_url
}

output "cluster_domain" {
  value = module.hcp.cluster_domain
}

output "oidc_endpoint_url" {
  value = module.hcp.oidc_endpoint_url
}

output "credentials_secret" {
  value = aws_secretsmanager_secret.rosa_users.name
}
