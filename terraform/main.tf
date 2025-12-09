# Configure AWS provider
provider "aws" {
  region = var.aws_region
}

# Data source for default VPC
data "aws_vpc" "default" {
  default = true
}

# Data source for public subnets in different Availability Zones (Required for ALB)
data "aws_subnets" "public_subnets" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
  # Filter for public subnets
  filter {
    name   = "map-public-ip-on-launch"
    values = ["true"]
  }
}

# Security Group to allow HTTP traffic (Port 80)
resource "aws_security_group" "web_sg" {
  name        = "web-access-sg"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "HTTP from Internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# User Data script to install Docker and run the container
locals {
  user_data = <<-EOT
    #!/bin/bash
    sudo yum update -y
    sudo amazon-linux-extras install docker -y
    sudo service docker start
    sudo usermod -a -G docker ec2-user
    # Run the Docker container
    sudo docker run -d -p 80:80 ${var.image_repo_name}
    EOT
}

# Data source for the Amazon Linux AMI
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# Launch Template definition
resource "aws_launch_template" "web_lt" {
  name_prefix   = "web-app-lt"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type
  key_name      = "conect_instance"
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  user_data     = base64encode(local.user_data)
}

# Auto Scaling Group (ASG) configuration
resource "aws_autoscaling_group" "web_asg" {
  name                      = "web-app-asg"
  # Use public subnets from different AZs
  vpc_zone_identifier       = data.aws_subnets.public_subnets.ids 
  min_size                  = 2 
  max_size                  = 4
  desired_capacity          = 2

  launch_template {
    id      = aws_launch_template.web_lt.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "web-app-instance"
    propagate_at_launch = true
  }
}

# 1. Application Load Balancer (ALB)
resource "aws_lb" "web_lb" {
  name               = "web-app-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.web_sg.id]
  # Use public subnets to satisfy the multi-AZ requirement
  subnets            = data.aws_subnets.public_subnets.ids 
}

# 2. Target Group (where traffic is sent)
resource "aws_lb_target_group" "web_tg" {
  name     = "web-app-tg"
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

# 3. Listener (listens on ALB port 80 and forwards to TG)
resource "aws_lb_listener" "web_listener" {
  load_balancer_arn = aws_lb.web_lb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web_tg.arn
  }
}

# 4. Attach ASG to Target Group
resource "aws_autoscaling_attachment" "asg_attachment" {
  autoscaling_group_name = aws_autoscaling_group.web_asg.id
  lb_target_group_arn    = aws_lb_target_group.web_tg.arn
}