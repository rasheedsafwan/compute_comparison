# --- Security groups ---

resource "aws_security_group" "alb" {
  name   = "coffee-ec2-alb-sg"
  vpc_id = var.vpc_id

  ingress {
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

resource "aws_security_group" "ec2_app" {
  name   = "coffee-ec2-app-sg"
  vpc_id = var.vpc_id

  ingress {
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]   # only the ALB can reach instances directly
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# --- Load balancer ---

resource "aws_lb" "ec2_alb" {
  name               = "coffee-ec2-alb"
  load_balancer_type = "application"
  subnets            = var.public_subnet_ids
  security_groups    = [aws_security_group.alb.id]
}

resource "aws_lb_target_group" "ec2_tg" {
  name     = "coffee-ec2-tg"
  port     = 3000
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    path = "/health"
  }
}

resource "aws_lb_listener" "ec2" {
  load_balancer_arn = aws_lb.ec2_alb.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ec2_tg.arn
  }
}

# --- AMI, launch template, ASG ---

data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

resource "aws_launch_template" "coffee_ec2" {
  name_prefix   = "coffee-ec2-"
  image_id      = data.aws_ami.al2023.id
  instance_type = var.instance_type   

  iam_instance_profile {
    name = aws_iam_instance_profile.coffee_ec2.name
  }

  user_data = base64encode(templatefile("${path.module}/user_data.sh.tpl", {
    table_name = var.table_name
    image_uri  = var.image_uri
  }))

  network_interfaces {
    security_groups = [aws_security_group.ec2_app.id]
  }
}

resource "aws_autoscaling_group" "coffee_ec2" {
  name                = "coffee-ec2-asg"
  min_size            = 2
  max_size            = 4
  desired_capacity    = 2
  vpc_zone_identifier = var.private_subnet_ids
  target_group_arns   = [aws_lb_target_group.ec2_tg.arn]

  launch_template {
    id      = aws_launch_template.coffee_ec2.id
    version = "$Latest"
  }

  health_check_type         = "ELB"
  health_check_grace_period = 120
}