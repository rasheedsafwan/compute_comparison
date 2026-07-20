# --- Security groups ---

resource "aws_security_group" "alb" {
  name   = "coffee-fargate-alb-sg"
  vpc_id = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]   # public entry point
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "fargate_task" {
  name   = "coffee-fargate-task-sg"
  vpc_id = var.vpc_id

  ingress {
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]   # only the ALB can reach tasks directly
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# --- Load balancer ---

resource "aws_lb" "fargate_alb" {
  name               = "coffee-fargate-alb"
  load_balancer_type = "application"
  subnets            = var.public_subnet_ids
  security_groups    = [aws_security_group.alb.id]
}

resource "aws_lb_target_group" "fargate_tg" {
  name        = "coffee-fargate-tg"
  port        = 3000
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"   # Fargate tasks register by IP, not instance ID

  health_check {
    path = "/health"
  }
}

resource "aws_lb_listener" "fargate" {
  load_balancer_arn = aws_lb.fargate_alb.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.fargate_tg.arn
  }
}

# --- Logs, cluster, task, service ---

resource "aws_cloudwatch_log_group" "fargate" {
  name              = "/ecs/coffee-fargate"
  retention_in_days = 7
}

resource "aws_ecs_cluster" "this" {
  name = "coffee-cluster"
}

resource "aws_ecs_task_definition" "coffee" {
  family                   = "coffee-fargate-task"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.task_cpu     
  memory                   = var.task_memory  
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn             = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([{
    name         = "coffee-api"
    image        = var.image_uri
    portMappings = [{ containerPort = 3000 }]
    environment  = [{ name = "TABLE_NAME", value = var.table_name }]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.fargate.name
        "awslogs-region"        = "us-east-1"
        "awslogs-stream-prefix" = "coffee"
      }
    }
  }])
}

resource "aws_ecs_service" "coffee" {
  name            = "coffee-fargate-service"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.coffee.arn
  desired_count   = var.desired_count   
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [aws_security_group.fargate_task.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.fargate_tg.arn
    container_name    = "coffee-api"
    container_port     = 3000
  }
}