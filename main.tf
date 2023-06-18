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

module "aws_s3_bucket" {
  source = "./modules/aws_s3_bucket"
  bucket_name = "lambda-new-image-bucket"
  acl = "private"
  policy = file("policy.json")
}

module "aws_s3_bucket_object" {
  source = "./modules/aws_s3_bucket_object"
  s3_bucket_id = module.aws_s3_bucket.s3_bucket_id
  for_each = fileset("image/", "*")
  key = each.value
  obj_source = "image/${each.value}"
}

module "lambda_iam_role_attachment" {
  source = "./modules/aws_iam_role"
  bucket_name = module.aws_s3_bucket.s3_bucket_name
  depends_on = [ module.aws_s3_bucket ]
}

data "archive_file" "lambda_code" {
  type        = "zip"
  source_dir = "lambda-package"
  output_path = "lambda_function_payload.zip"
}

module "lambda_function" {
  source = "./modules/aws_lambda_function"
  filename = "lambda_function_payload.zip"
  function_name = "lambda_function_name"
  role_permission = module.lambda_iam_role_attachment.iam_role_arn
  source_code_hash = data.archive_file.lambda_code.output_base64sha256
  handler = "index.handler"
  runtime = "nodejs16.x"
  layer_name = "lambda_layer_name"
  source_arn = module.aws_s3_bucket.s3_bucket_arn
  depends_on = [ module.aws_s3_bucket, module.lambda_iam_role_attachment]
}

# Configure an S3 bucket notification to trigger the Lambda function when an image is uploaded
resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = module.aws_s3_bucket.s3_bucket_id

  lambda_function {
    lambda_function_arn = module.lambda_function.lambda_function_arn
    events              = ["s3:ObjectCreated:Put"]
  }

}
