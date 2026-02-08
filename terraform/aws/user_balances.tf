
resource "aws_dynamodb_table" "user_balances" {
  name           = "user_balances"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "userId"

  attribute {
    name = "userId"
    type = "S"
  }
}
