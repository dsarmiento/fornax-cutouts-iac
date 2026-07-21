resource "aws_s3_bucket" "stage_bucket" {
  bucket = "${var.project_name}-${var.env}-stage"
}

resource "aws_s3_bucket_lifecycle_configuration" "stage_bucket_lifecycle" {
  bucket = aws_s3_bucket.stage_bucket.id

  rule {
    id = "Delete after ${var.cutout_prefix_ttl_days} days"

    filter {
      prefix = "cutouts/"
    }

    expiration {
      days = var.cutout_prefix_ttl_days
    }

    status = "Enabled"
  }
}
