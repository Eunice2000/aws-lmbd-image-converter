terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~>4.0"
    }
  }
  backend "s3" {
    bucket = "ecorm-terraform-lock-bucket"
    key    = "terraform-tfstate"
    region = "us-east-1"
  }
}

# Declaration of aws vpc availabilty zone
provider "aws" {
  region = "us-east-1"
}

resource "aws_s3_bucket" "image_object" {
  bucket = "lambda-new-image-bucket"
  acl = "private"
}

resource "aws_s3_bucket_public_access_block" "example" {
  bucket = aws_s3_bucket.image_object.id
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "image_policy" {
  bucket = aws_s3_bucket.image_object.id
  policy = file("policy.json")
  depends_on = [ aws_s3_bucket_public_access_block.example ]
}


resource "aws_s3_bucket_object" "object" {
  for_each = fileset("image/", "*")
  bucket = aws_s3_bucket.image_object.id
  key = each.value
  source = "image/${each.value}"
}

data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_policy" "s3_policy" {
  name        = "s3_policy"
  path        = "/"
  description = "My s3 policy"

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": [
          "s3:GetObject",
          "s3:ListBucket",
          "s3:PutObject"
        ],
        "Resource": [
          "arn:aws:s3:::${aws_s3_bucket.image_object.bucket}/*",
          "arn:aws:s3:::${aws_s3_bucket.image_object.bucket}"
        ]
      }
    ]
})
}

resource "aws_iam_policy" "cloudwatch_policy" {
  name        = "cloudwatch_policy"
  path        = "/"
  description = "My cloudwatch policy"

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        "Resource": "arn:aws:logs:*:*:*"
      }
    ]
})
}


resource "aws_iam_role" "iam_for_lambda" {
  name               = "iam_for_lambda"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}


resource "aws_iam_role_policy_attachment" "lambda_policy_attachment_s3" {
  policy_arn = aws_iam_policy.s3_policy.arn
  role = aws_iam_role.iam_for_lambda.name
}
resource "aws_iam_role_policy_attachment" "lambda_policy_attachment_cloudwatch" {
  policy_arn = aws_iam_policy.cloudwatch_policy.arn
  role = aws_iam_role.iam_for_lambda.name
}

data "archive_file" "lambda_code" {
  type        = "zip"
  source_dir = "lambda-package"
  output_path = "lambda_function_payload.zip"
}

resource "aws_lambda_function" "test_lambda" {
  filename      = "lambda_function_payload.zip"
  function_name = "lambda_function_name"
  role          = aws_iam_role.iam_for_lambda.arn
  source_code_hash = data.archive_file.lambda_code.output_base64sha256
  handler = "index.handler"
  runtime = "nodejs16.x"
  depends_on = [ data.archive_file.lambda_code ]
  layers = [ aws_lambda_layer_version.name.arn ] 
}

resource "aws_lambda_layer_version" "name" {
  filename = "./lambda_function_payload.zip"
  layer_name = "lambda_layer_name"
  compatible_runtimes = ["nodejs16.x"]
}

resource "aws_lambda_alias" "test_alias" {
  name             = "testalias"
  description      = "a sample description"
  function_name    = aws_lambda_function.test_lambda.function_name
  function_version = "$LATEST"
}

resource "aws_lambda_permission" "allow_s3_permission" {
  statement_id  = "Allows3Excecution"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.test_lambda.function_name
  principal     = "s3.amazonaws.com"
  /* source_arn    = "arn:aws:s3:::lambda-new-image-bucket" */
  source_arn = aws_s3_bucket.image_object.arn
  /* qualifier     = aws_lambda_alias.test_alias.name */
}



# Configure an S3 bucket notification to trigger the Lambda function when an image is uploaded
resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = aws_s3_bucket.image_object.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.test_lambda.arn
    events              = ["s3:ObjectCreated:Put"]
  }

}
