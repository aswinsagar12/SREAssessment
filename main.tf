terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = "ap-south-1"
}

#VPC Configure
variable "vpc_id" {
  default = "vpc-1c75e774" # Replace with your VPC ID
}

data "aws_vpc" "default" {
  id = var.vpc_id
}

resource "aws_key_pair" "deployer" {
  key_name   = "deployer-key"
  public_key = file("${path.module}/Keys/my-key.pub")
}


#LOADBALANCER
resource "aws_eip" "lb" {
  instance = aws_instance.web.id
  domain   = "vpc"
}

# EC2 INSTANCE
data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

#Tsting Pupose and rference
# resource "aws_instance" "web" {
#   ami           = data.aws_ami.ubuntu.id
#   instance_type = "t3.micro"
  

#   tags = {
#     Name = "HelloWorld"
#   }
# }
resource "aws_instance" "web" {
  #ami           = data.aws_ami.ubuntu.id
  ami           = "ami-0a1235697f4afa8a4"
  instance_type = "t3.micro"
  count = 2
  key_name      = aws_key_pair.deployer.key_name
  tags = {
   Name = "instance-${count.index}"
   }
}


#***************ECR****************
resource "aws_ecr_repository" "sre" {
  name                 = "nginx"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}





#Test EC2 Machines for loadbalaner
# resource "aws_instance" "web-server" {
#   ami           = "ami-0a1235697f4afa8a4"
#   instance_type = "t2.micro"
#   count         = 2
#   key_name      = aws_key_pair.deployer.key_name

#   tags = {
#     Name = "instance-${count.index}"
#   }
# }



#LoadBalancer Setups
resource "aws_lb" "web_alb" {
  name               = "web-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = ["sg-f558329e"]     # Add security group IDs as needed
  subnets            = ["subnet-0c178264", "subnet-4c05c000", "subnet-b1c336ca"]
   # Or specify subnet IDs

  tags = {
    Name = "web-alb"
  }
}

resource "aws_lb_target_group" "web_tg" {
  name     = "web-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default.id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}


resource "aws_lb_listener" "web_listener" {
  load_balancer_arn = aws_lb.web_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web_tg.arn
  }
}

resource "aws_lb_target_group_attachment" "web_attachment" {
  count            = length(aws_instance.web)
  target_group_arn = aws_lb_target_group.web_tg.arn
  target_id        = aws_instance.web[count.index].id
  port             = 80
}
