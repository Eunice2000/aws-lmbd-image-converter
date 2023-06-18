variable "filename" {}

variable "function_name" {}

variable "handler" {}

variable "runtime" {}

variable "layer_name" {}

variable "role_permission" {}

variable "source_code_hash" {}

variable "source_arn" {}


resource "aws_lambda_function" "test_lambda" {
  filename      = var.filename
  function_name = var.function_name
  role          = var.role_permission
  source_code_hash = var.source_code_hash
  handler = var.handler
  runtime =  var.runtime
  layers = [ aws_lambda_layer_version.name.arn ] 
}

resource "aws_lambda_layer_version" "name" {
  filename = var.filename
  layer_name = var.layer_name
  compatible_runtimes = [var.runtime]
}


resource "aws_lambda_permission" "allow_s3_permission" {
  statement_id  = "Allows3Excecution"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.test_lambda.function_name
  principal     = "s3.amazonaws.com"
  source_arn = var.source_arn
}

output "lambda_function_arn" {
  value = aws_lambda_function.test_lambda.arn
}