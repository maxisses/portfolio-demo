output "vpc_id" {
  value = module.vpc.vpc_id
}

output "vpc_cidr" {
  value = var.vpc_cidr
}

output "private_subnet_ids" {
  value = module.vpc.private_subnets
}

output "public_subnet_ids" {
  value = module.vpc.public_subnets
}

output "availability_zone" {
  value = var.availability_zone
}

output "aap_public_ip" {
  value = aws_eip.aap.public_ip
}

output "aap_fqdn" {
  value = aws_route53_record.aap.fqdn
}

output "aap_ami" {
  value = data.aws_ami.rhel.name
}

output "state_bucket" {
  value = local.state_bucket
}
