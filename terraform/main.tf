# create Vpd and sypplier

provider "aws" {
  region = var.aws_region
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Security Group to allow HTTP traffic

resource "aws_security_group" "web_sg" {
  name        = "web-access-sg"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "HTTP desde Internet"
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

#User Data to install Docker and run the container

locals {
  user_data = <<-EOT
    #!/bin/bash
    sudo yum update -y
    sudo amazon-linux-extras install docker -y
    sudo service docker start
    sudo usermod -a -G docker ec2-user
    # Ejecuta tu contenedor Docker
    sudo docker run -d -p 80:80 ${var.image_repo_name}
    EOT
}

# Launch Template y Auto Scaling Group (ASG)

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

resource "aws_launch_template" "web_lt" {
  name_prefix   = "web-app-lt"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type
  key_name      = "conect_instance"
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  user_data     = base64encode(local.user_data)
}

resource "aws_autoscaling_group" "web_asg" {
  name                      = "web-app-asg"
  vpc_zone_identifier       = data.aws_subnets.default.ids
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

# Create loud Balance

# 1. ALB
resource "aws_lb" "web_lb" {
  name               = "web-app-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.web_sg.id]
  subnets            = data.aws_subnets.default.ids
}

# 2. Target Group 
resource "aws_lb_target_group" "web_tg" {
  name     = "web-app-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default.id

  health_check {
    path                = "/" # Comprueba la raíz del sitio
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

# 3. Listener (listens to requests in the ALB and forwards them to the TG)
resource "aws_lb_listener" "web_listener" {
  load_balancer_arn = aws_lb.web_lb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web_tg.arn
  }
}

# 4. Connect ESG to Target Group
resource "aws_autoscaling_attachment" "asg_attachment" {
  autoscaling_group_name = aws_autoscaling_group.web_asg.id
  lb_target_group_arn    = aws_lb_target_group.web_tg.arn
}