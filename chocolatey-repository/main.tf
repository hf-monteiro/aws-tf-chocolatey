provider "aws" {
  region = var.region
}

################################################################################
# Supporting Resources
################################################################################

## EC2 AMI ##
data "aws_ami" "choco_local_repo" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "image-id"
    values = [var.image_id]
  }
}

## SG ##
module "security_group" {
  source = "../modules/sg_security_group"

  name        = var.name
  description = "Security group for usage with EC2 instance"
  vpc_id      = var.vpc_id

  # ingress
  ingress_with_cidr_blocks = [
    {
      from_port   = 3389
      to_port     = 3389
      protocol    = "tcp"
      description = "RDP access"
      # Lab/demo CIDR: restrict this to trusted networks before production use.
      cidr_blocks = "0.0.0.0/0"
    },
    {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      description = "vpc all traffic"
      cidr_blocks = var.cidr_blocks
    }
  ]

  # egress
  egress_with_cidr_blocks = [
    {
      from_port   = 0
      to_port     = 65535
      protocol    = "all"
      description = "All traffic out"
      # Lab/demo CIDR: restrict this to trusted networks before production use.
      cidr_blocks = "0.0.0.0/0"
    }
  ]

  tags = local.tags
}

### S3 ROLE ###
resource "aws_iam_instance_profile" "test_profile" {
  name = "${var.name}-intance-profile"
  role = var.ec2_role
}

################################################################################
# EC2 Module
################################################################################


module "ec2" {
  source = "../modules/ec2_instance"

  name                        = var.name
  ami                         = data.aws_ami.choco_local_repo.id
  instance_type               = var.instance_type
  availability_zone           = var.availability_zone
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [module.security_group.security_group_id]
  associate_public_ip_address = true
  hibernation                 = true
  key_name                    = var.key_name
  user_data                   = file("user_data.tpl")
  iam_instance_profile        = aws_iam_instance_profile.test_profile.name
  private_ip                  = var.private_ip


  enable_volume_tags = true
  root_block_device = [
    {
      encrypted   = true
      volume_type = "gp3"
      throughput  = 200
      volume_size = 100
    },
  ]
}

resource "aws_volume_attachment" "this" {
  device_name = "/dev/sdh"
  volume_id   = aws_ebs_volume.this.id
  instance_id = module.ec2.id
}

resource "aws_ebs_volume" "this" {
  availability_zone = var.availability_zone
  size              = 50
}

## Interface ##

resource "aws_network_interface" "this" {
  subnet_id = var.subnet_id
}

module "ec2_network_interface" {
  source = "../modules/ec2_instance"

  name = "${var.name}-network-interface"

  ami           = data.aws_ami.choco_local_repo.id
  instance_type = var.instance_type

  network_interface = [
    {
      device_index          = 0
      network_interface_id  = aws_network_interface.this.id
      delete_on_termination = false
    }
  ]
}

