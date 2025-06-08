resource "random_id" "s3_bucket_suffix" {
  byte_length = 4
}


resource "aws_s3_bucket" "billing_upload" {
  bucket        = "${var.bucket_name_upload}-${random_id.s3_bucket_suffix.hex}"
  force_destroy = true

  tags = var.tags

}

resource "aws_s3_bucket" "billing_error" {
  bucket        = "${var.bucket_name_error}-${random_id.s3_bucket_suffix.hex}"
  force_destroy = true

  tags = var.tags

}
