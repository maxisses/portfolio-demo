variable "region" {
  type    = string
  default = "eu-central-1"
}

variable "cluster_name" {
  type    = string
  default = "portfolio-hub2"
}

variable "openshift_version" {
  description = "OpenShift AI 3.5 unterstützt höchstens 4.21"
  type        = string
  default     = "4.21.34"
}

variable "compute_machine_type" {
  type    = string
  default = "m6i.2xlarge"
}

variable "compute_replicas" {
  type    = number
  default = 4
}

variable "gpu_pool_enabled" {
  description = "GPU-Pool erst nach Freigabe durch Max einschalten"
  type        = bool
  default     = true
}

variable "gpu_instance_type" {
  description = "L4 (g6) statt L40S (g6e): am 01.10.2026 keine g6e-Kapazität; g6.xlarge (4 vCPU), weil die neue Sandbox nur 4 vCPU für G-Instanzen erlaubt"
  type        = string
  default     = "g6.xlarge"
}
