variable "task_cpu" {
  description = "Fargate task CPU units, e.g. \"256\" or \"512\" — this is your sizing test"
  type        = string
}

variable "task_memory" {
  description = "Fargate task memory in MB, e.g. \"512\" or \"1024\""
  type        = string
}

variable "desired_count" {
  description = "Number of Fargate tasks to run — start at 2 for a fair comparison with EC2's ASG min"
  type        = number
  default     = 2
}

variable "table_name" {
  description = "DynamoDB table name, passed in from module.data"
  type        = string
}

variable "table_arn" {
  description = "DynamoDB table ARN, used to scope the ECS task role's IAM policy"
  type        = string
}

variable "image_uri" {
  description = "Full ECR image URI from Phase 4, e.g. <account-id>.dkr.ecr.us-east-1.amazonaws.com/coffee-api:latest"
  type        = string
}

variable "vpc_id" {
  description = "Passed in from module.network at the root level"
  type        = string
}

variable "public_subnet_ids" {
  type = list(string)
}

variable "private_subnet_ids" {
  type = list(string)
}