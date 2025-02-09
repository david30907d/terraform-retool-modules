terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "3.50.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

resource "aws_security_group" "this" {
  name        = "${var.instance_name}-sg"
  description = "Retool EC2 security group"
  vpc_id      = var.vpc_id


  dynamic "ingress" {
    for_each = var.ingress_rules

    content {
      description      = ingress.value["description"]
      from_port        = ingress.value["from_port"]
      to_port          = ingress.value["to_port"]
      protocol         = ingress.value["protocol"]
      cidr_blocks      = ingress.value["cidr_blocks"]
      ipv6_cidr_blocks = ingress.value["ipv6_cidr_blocks"]
    }
  }

  dynamic "egress" {
    for_each = var.egress_rules

    content {
      description      = egress.value["description"]
      from_port        = egress.value["from_port"]
      to_port          = egress.value["to_port"]
      protocol         = egress.value["protocol"]
      cidr_blocks      = egress.value["cidr_blocks"]
      ipv6_cidr_blocks = egress.value["ipv6_cidr_blocks"]
    }
  }
}

resource "aws_instance" "this" {
  ami           = var.instance_ami
  instance_type = var.instance_type
  key_name      = var.ssh_key_name

  associate_public_ip_address = var.associate_public_ip_address
  vpc_security_group_ids      = [aws_security_group.this.id]
  subnet_id                   = var.subnet_id

  root_block_device {
    encrypted   = var.storage_encrypted
    volume_type = var.storage_type
    volume_size = var.storage_size
  }

  monitoring = var.enable_monitoring

  tags = merge(
    var.additional_tags,
    {
      Name = var.instance_name
    }
  )

  user_data = <<-EOF
  #!/bin/bash

  # Clone Retool repository
  git clone https://github.com/david30907d/retool-onpremise.git
  cd retool-onpremise

  # Rewrite Dockerfile
  echo FROM tryretool/backend:${var.version_number} > Dockerfile
  echo CMD ./docker-scripts/start_api.sh >> Dockerfile

  # Initialize Docker and Retool Installation
  ./install.sh

  # Run services
  echo ${var.license_key} > license_key
  sed -i 's/LICENSE_KEY=EXPIRED-LICENSE-KEY-TRIAL/LICENSE_KEY=${var.license_key}/g' docker.env
  echo COOKIE_INSECURE=true >> docker.env
  docker-compose up -d
  # it's a workaround, have no idea why it would fail the first time!
  sleep 120
  docker-compose restart
  EOF
}
