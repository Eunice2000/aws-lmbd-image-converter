variable "key" {
  
}

variable "obj_source" {
  
}

variable "s3_bucket_id" {
  
}

resource "aws_s3_bucket_object" "object" {
  bucket = var.s3_bucket_id
  key = var.key
  source = var.obj_source
}