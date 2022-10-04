//resource "aws_iam_role" "addepar-us-pipeline-artifacts-replication" {
//  provider = aws.dest
//  name     = "destinarion-replication"
//
//  assume_role_policy = data.aws_iam_policy_document.destination-replication-assume-role-policy.json
//}

data "aws_iam_policy_document" "destination-replication-assume-role-policy" {
  provider = aws.dest

  statement {
    actions = ["sts:AssumeRole"]
    effect  = "Allow"

    principals {
      type        = "Service"
      identifiers = [
        "s3.amazonaws.com",
        "batchoperations.s3.amazonaws.com"
      ]
    }
  }
}

# ------------------------------------------------------------------------------
# KMS key for server side encryption on the destination bucket
# ------------------------------------------------------------------------------
resource "aws_kms_key" "destination" {
  provider                = aws.dest
  deletion_window_in_days = 7

  tags = merge(
    {
      "Name" = "destination_data"
    },
    var.tags,
  )

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "Enable IAM User Permissions",
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::${var.dest_account}:root"
      },
      "Action": "kms:*",
      "Resource": "*"
    },
    {
      "Sid": "Enable cross account encrypt access for S3 Cross Region Replication",
      "Effect": "Allow",
      "Principal": {
        "AWS": "${var.source_account}"
      },
      "Action": [
        "kms:Encrypt"
      ],
      "Resource": "*"
    }
  ]
}
POLICY

}

resource "aws_kms_alias" "destination" {
  provider      = aws.dest
  name          = "alias/destination"
  target_key_id = aws_kms_key.destination.key_id
}


//resource "aws_s3_bucket_acl" "destination" {
//  provider = aws.dest
//  bucket = aws_s3_bucket.destination.id 
//  acl = "private"
//}


//
//  @TODO
//  The bucket setup fails with this block activated ... why?
//
//// ISR and SecEng request we block S3 public access
////
//// this is new and needs testing before hitting prod
////
//resource "aws_s3_bucket_public_access_block" "destination_access_block" {
//  bucket = aws_s3_bucket.destination.id
//
//  block_public_acls       = true
//  block_public_policy     = true
//  ignore_public_acls      = true
//  restrict_public_buckets = true
//}
//


# ------------------------------------------------------------------------------
# S3 bucket to act as the replication target.
# ------------------------------------------------------------------------------
resource "aws_s3_bucket" "destination" {
  provider      = aws.dest
  bucket_prefix = var.bucket_prefix

  // disable here, move to aws_s3_bucket_acl resource
  acl           = "private"

  force_destroy = true

  versioning {
    enabled = true
  }

  lifecycle {
    prevent_destroy = false
  }

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        kms_master_key_id = aws_kms_key.destination.arn
        sse_algorithm     = "aws:kms"
      }
    }
  }

  tags = merge(
    {
      "Name" = "Destination Bucket"
    },
    var.tags,
  )
}

# ------------------------------------------------------------------------------
# The destination bucket needs a policy that allows the source account to
# replicate into it.
# ------------------------------------------------------------------------------
resource "aws_s3_bucket_policy" "destination" {
  provider = aws.dest
  bucket   = aws_s3_bucket.destination.id

  policy = <<POLICY
{
  "Version": "2008-10-17",
  "Id": "",
  "Statement": [
    {
      "Sid": "AllowReplication",
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::${var.source_account}:root"
      },
      "Action": [
        "s3:GetBucketVersioning",
        "s3:PutBucketVersioning",
        "s3:ReplicateObject",
        "s3:ReplicateDelete",
        "s3:ObjectOwnerOverrideToBucketOwner"
      ],
      "Resource": [
        "${aws_s3_bucket.destination.arn}",
        "${aws_s3_bucket.destination.arn}/*"
      ]
    },
    {
      "Sid": "AllowRead",
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::${var.source_account}:root"
      },
      "Action": [
        "s3:List*",
        "s3:Get*"
      ],
      "Resource": [
        "${aws_s3_bucket.destination.arn}",
        "${aws_s3_bucket.destination.arn}/*"
      ]
    }
  ]
}
POLICY

}

