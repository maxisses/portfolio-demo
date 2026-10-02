variable "region" {
  type    = string
  default = "eu-central-1"
}

variable "availability_zone" {
  type    = string
  default = "eu-central-1a"
}

variable "second_availability_zone" {
  description = "Nur für die Datenbank-Subnetze (RDS braucht zwei Zonen)"
  type        = string
  default     = "eu-central-1b"
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "dns_zone_name" {
  description = "Öffentliche Route53-Zone der Sandbox"
  type        = string
  default     = "sandbox2782.opentlc.com"
}

variable "admin_cidr" {
  description = "Quelle für SSH auf die AAP-VM (kommt per TF_VAR_admin_cidr, nicht aus dem Repo)"
  type        = string
}

variable "ssh_public_key_path" {
  type    = string
  default = "~/.ssh/portfolio-demo.pub"
}

variable "ssh_public_key" {
  description = "Alternativ zum Pfad, z. B. wenn AAP den Plan im Execution Environment rechnet"
  type        = string
  default     = ""
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

variable "rosa_infra_id" {
  description = "Infrastruktur-ID des ROSA-Clusters. ROSA taggt die Subnetze damit; ohne diesen Eintrag würde Terraform den Tag wieder entfernen."
  type        = string
  default     = "2t6f3noqopu5vieu03rd38invan6davs"
}
