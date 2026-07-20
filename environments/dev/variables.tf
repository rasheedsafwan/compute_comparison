variable "lambda_zip_path" {
  type    = string
  default = "../../app/lambda/build/handler.zip"
}

variable "ecr_image_uri" {
  description = "Set after Phase 4's docker push, e.g. <account-id>.dkr.ecr.us-east-1.amazonaws.com/coffee-api:latest"
  type        = string
}

variable "fargate_task_cpu" {
  type    = string
  default = "256"
}

variable "fargate_task_memory" {
  type    = string
  default = "512"
}

variable "ec2_instance_type" {
  type    = string
  default = "t3.small"
}
