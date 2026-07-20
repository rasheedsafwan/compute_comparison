variable "memory_size" {
  description = "Lambda memory in MB — deploy this module twice with different values (e.g. 128 and 1024) to compare"
  type        = number
}

variable "lambda_zip_path" {
  description = "Path to the zipped handler.py, e.g. ../../app/lambda/build/handler.zip"
  type        = string
}

variable "table_name" {
  description = "DynamoDB table name, passed in from module.data"
  type        = string
}

variable "table_arn" {
  description = "DynamoDB table ARN, used to scope the IAM policy"
  type        = string
}