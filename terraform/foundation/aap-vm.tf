# RHEL-VM für Ansible Automation Platform 2.7 (containerized, Growth-Topologie).
data "aws_ami" "rhel" {
  most_recent = true
  owners      = ["309956199498"] # Red Hat
  filter {
    name   = "name"
    values = [var.aap_rhel_ami_name]
  }
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

resource "aws_key_pair" "aap" {
  key_name   = "portfolio-demo-aap"
  public_key = file(pathexpand(var.ssh_public_key_path))
}

resource "aws_security_group" "aap" {
  name        = "portfolio-demo-aap"
  description = "AAP: HTTPS fuer Portal, API und MCP; SSH nur vom Admin"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "HTTPS (Platform Gateway, MCP)"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "AAP-MCP-Server (eigener Nginx)"
    from_port   = 8448
    to_port     = 8448
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "SSH vom Admin"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.admin_cidr]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "aap" {
  ami                    = data.aws_ami.rhel.id
  instance_type          = var.aap_instance_type
  subnet_id              = module.vpc.public_subnets[0]
  vpc_security_group_ids = [aws_security_group.aap.id]
  key_name               = aws_key_pair.aap.key_name
  iam_instance_profile   = aws_iam_instance_profile.aap.name

  root_block_device {
    volume_size = 120
    volume_type = "gp3"
    encrypted   = true
  }

  # Hop-Limit 2: Auch die Execution-Environment-Container auf der VM erreichen IMDS
  # und nutzen damit die Rolle der VM statt statischer Keys.
  metadata_options {
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  tags = {
    Name = "portfolio-demo-aap"
  }

  lifecycle {
    ignore_changes = [ami]
  }
}

resource "aws_eip" "aap" {
  instance = aws_instance.aap.id
  domain   = "vpc"
  tags = {
    Name = "portfolio-demo-aap"
  }
}

data "aws_route53_zone" "sandbox" {
  name         = var.dns_zone_name
  private_zone = false
}

resource "aws_route53_record" "aap" {
  zone_id = data.aws_route53_zone.sandbox.zone_id
  name    = "aap.${var.dns_zone_name}"
  type    = "A"
  ttl     = 60
  records = [aws_eip.aap.public_ip]
}
