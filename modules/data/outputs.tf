output "table_name" {
  value = aws_dynamodb_table.coffee_inventory.name
}

output "table_arn" {
  value = aws_dynamodb_table.coffee_inventory.arn
}