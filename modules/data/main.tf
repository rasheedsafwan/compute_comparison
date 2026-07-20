resource "aws_dynamodb_table" "coffee_inventory" {
  name         = "coffee-inventory"
  billing_mode = "PAY_PER_REQUEST"   
  hash_key     = "coffeeId"

  attribute {
    name = "coffeeId"
    type = "S"
  }
}
