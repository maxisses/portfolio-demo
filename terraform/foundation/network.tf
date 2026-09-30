# Single-AZ-VPC für ROSA HCP und die AAP-VM. Die Subnetz-Tags braucht ROSA,
# damit Load Balancer im richtigen Subnetz landen.
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 6.0"

  name = "portfolio-demo"
  cidr = var.vpc_cidr
  azs  = [var.availability_zone]

  private_subnets = [cidrsubnet(var.vpc_cidr, 2, 0)] # 10.0.0.0/18
  public_subnets  = [cidrsubnet(var.vpc_cidr, 4, 8)] # 10.0.128.0/20

  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true
  enable_dns_support   = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
  }
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
  }
}
