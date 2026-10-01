# Single-AZ-VPC für ROSA HCP und die AAP-VM. Die Subnetz-Tags braucht ROSA,
# damit Load Balancer im richtigen Subnetz landen.
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 6.0"

  name = "portfolio-demo"
  cidr = var.vpc_cidr
  # ROSA und AAP laufen Single-AZ in der ersten Zone. RDS verlangt eine Subnetzgruppe über
  # mindestens zwei Zonen, deshalb gibt es nur für Datenbanken ein Subnetz in einer zweiten Zone.
  azs = [var.availability_zone, var.second_availability_zone]

  private_subnets = [cidrsubnet(var.vpc_cidr, 2, 0)] # 10.0.0.0/18
  public_subnets  = [cidrsubnet(var.vpc_cidr, 4, 8)] # 10.0.128.0/20

  database_subnets                   = [cidrsubnet(var.vpc_cidr, 8, 192), cidrsubnet(var.vpc_cidr, 8, 193)] # 10.0.192.0/24, 10.0.193.0/24
  create_database_subnet_group       = true
  create_database_subnet_route_table = true

  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true
  enable_dns_support   = true

  public_subnet_tags = merge(
    { "kubernetes.io/role/elb" = "1" },
    var.rosa_infra_id != "" ? { "kubernetes.io/cluster/${var.rosa_infra_id}" = "shared" } : {}
  )
  private_subnet_tags = merge(
    { "kubernetes.io/role/internal-elb" = "1" },
    var.rosa_infra_id != "" ? { "kubernetes.io/cluster/${var.rosa_infra_id}" = "shared" } : {}
  )
}
