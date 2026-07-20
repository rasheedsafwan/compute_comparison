output "alb_dns_name" {
  value = aws_lb.fargate_alb.dns_name
}