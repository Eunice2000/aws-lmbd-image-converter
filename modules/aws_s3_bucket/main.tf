variable "bucket_name" {}

variable "acl" {}

variable "policy" {}

resource "aws_s3_bucket" "image_object" {
  bucket = var.bucket_name
  acl = var.acl
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
  policy = var.policy
  depends_on = [ aws_s3_bucket_public_access_block.example ]
}


output "s3_bucket_name" {
  value = aws_s3_bucket.image_object.bucket
}

output "s3_bucket_id" {
  value = aws_s3_bucket.image_object.id
}
output "s3_bucket_arn" {
  value = aws_s3_bucket.image_object.arn
}