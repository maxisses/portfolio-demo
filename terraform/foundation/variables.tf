variable "region" {
  type    = string
  default = "eu-central-1"
}

variable "availability_zone" {
  type    = string
  default = "eu-central-1a"
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "dns_zone_name" {
  description = "Öffentliche Route53-Zone der Sandbox"
  type        = string
  default     = "sandbox3481.opentlc.com"
}

variable "admin_cidr" {
  description = "Quelle für SSH auf die AAP-VM (kommt per TF_VAR_admin_cidr, nicht aus dem Repo)"
  type        = string
}

variable "ssh_public_key_path" {
  type    = string
  default = "~/.ssh/portfolio-demo.pub"
}

variable "aap_instance_type" {
  type    = string
  default = "m6i.2xlarge"
}

variable "aap_rhel_ami_name" {
  description = "Namensmuster des RHEL-AMIs von Red Hat (PAYG). AAP 2.7 braucht RHEL 9.6+ oder 10."
  type        = string
  default     = "RHEL-9.8.0_HVM-*-x86_64-*-Hourly2-GP3"
}
