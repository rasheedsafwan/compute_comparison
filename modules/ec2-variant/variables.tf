variable "instance_type" {
  description = "EC2 instance type, e.g. \"t3.small\" — document why you picked this size in your report"
  type        = string
  default     = "t3.small"
}

variable "table_name" {
  description = "DynamoDB table name, passed in from module.data"
  type        = string
}

variable "table_arn" {
  description = "DynamoDB table ARN, used to scope the EC2 instance profile's IAM policy"
  type        = string
}

variable "image_uri" {
  description = "Full ECR image URI from Phase 4 — used by user_data.sh.tpl to pull and run the container at boot"
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