module "tags_network" {
  source      = "git::https://github.com/cloudposse/terraform-null-label.git"
  namespace   = var.name
  environment = var.env
  name        = "devops-bootcamp"
  delimiter   = "_"

  tags = {
    owner = var.name
    type  = "network"
  }
}

module "tags_bastion" {
  source      = "git::https://github.com/cloudposse/terraform-null-label.git"
  namespace   = var.name
  environment = var.env
  name        = "bastion-devops-bootcamp"
  delimiter   = "_"

  tags = {
    owner = var.name
    type  = "bastion"
  }
}

module "tags_jenkins" {
  source      = "git::https://github.com/cloudposse/terraform-null-label.git"
  namespace   = var.name
  environment = var.env
  name        = "jenkins-devops-bootcamp"
  delimiter   = "_"

  tags = {
    owner = var.name
    type  = "jenkins"
    Name  = "Jenkins"
  }
}

data "aws_ami" "latest_jenkins_server" {
  most_recent = true
  owners      = ["772816346052"]

  filter {
    name   = "name"
    values = ["bryan-jenkins-server*"]
  }
}

resource "aws_vpc" "jenkins" {
  cidr_block           = "110.0.0.0/16"
  tags                 = module.tags_network.tags
  enable_dns_hostnames = true
}

data "aws_route53_zone" "labs_central" {
  name         = "labs.dobc"
  private_zone = true
}

resource "aws_route53_zone_association" "jenkins" {
  zone_id = data.aws_route53_zone.labs_central.id
  vpc_id  = aws_vpc.jenkins.id
}

resource "aws_internet_gateway" "jenkins_gateway" {
  vpc_id = aws_vpc.jenkins.id
  tags   = module.tags_network.tags
}

resource "aws_route" "jenkins_internet_access" {
  route_table_id         = aws_vpc.jenkins.main_route_table_id
  gateway_id             = aws_internet_gateway.jenkins_gateway.id
  destination_cidr_block = "0.0.0.0/0"
}

resource "aws_subnet" "bastion" {
  vpc_id                  = aws_vpc.jenkins.id
  cidr_block              = "110.0.1.0/24"
  map_public_ip_on_launch = true
  tags                    = module.tags_bastion.tags
}

resource "aws_subnet" "jenkins" {
  vpc_id                  = aws_vpc.jenkins.id
  cidr_block              = "110.0.10.0/24"
  map_public_ip_on_launch = false
  tags                    = module.tags_jenkins.tags
}

resource "aws_security_group" "bastion" {
  vpc_id = aws_vpc.jenkins.id
  tags   = module.tags_bastion.tags

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "jenkins" {
  vpc_id = aws_vpc.jenkins.id
  tags   = module.tags_jenkins.tags

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }

  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }
}

resource "aws_key_pair" "jenkins_keypair" {
  key_name   = format("%s%s", var.name, "_keypair")
  public_key = file(var.public_key_path)
}

resource "aws_instance" "jenkins" {
  ami                    = data.aws_ami.latest_jenkins_server.id
  instance_type          = "t3.large"
  subnet_id              = aws_subnet.jenkins.id
  vpc_security_group_ids = [aws_security_group.jenkins.id]
  key_name               = aws_key_pair.jenkins_keypair.id
  tags                   = module.tags_jenkins.tags
}

resource "aws_route53_record" "jenkins" {
  zone_id = data.aws_route53_zone.labs_central.id
  name    = "jenkins"
  type    = "A"
  ttl     = 300
  records = [aws_instance.jenkins.private_ip]
}

resource "aws_instance" "bastion" {
  ami                    = "ami-02c7c728a7874ae7a"
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.bastion.id
  vpc_security_group_ids = [aws_security_group.bastion.id]
  key_name               = aws_key_pair.jenkins_keypair.id
  tags                   = module.tags_bastion.tags
}

resource "aws_eip" "jenkins" {
  vpc        = true
  instance   = aws_instance.jenkins.id
  depends_on = [aws_internet_gateway.jenkins_gateway]
}
