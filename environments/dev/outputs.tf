output "lambda_128_endpoint" {
  value = module.lambda_128.endpoint
}

output "lambda_1024_endpoint" {
  value = module.lambda_1024.endpoint
}

output "fargate_alb_dns" {
  value = module.fargate.alb_dns_name
}

output "ec2_alb_dns" {
  value = module.ec2.alb_dns_name
}