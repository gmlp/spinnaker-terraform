###########################
# --- SPINNAKER S3 USER ---
###########################

resource "random_id" "bucket_id" {
  keepers {
    id = "${aws_eks_cluster.eks_cluster.id}"
  }

  byte_length = "4"
}

resource "aws_s3_bucket" "spinnaker_external_storage" {
  bucket = "spinnaker-external-store-${random_id.bucket_id.hex}"
  acl    = "private"
}

resource "aws_iam_user" "spinnaker_s3_user" {
  name = "spinnaker_s3_user"
}

resource "aws_iam_access_key" "spinnaker_s3_user_keys" {
  user = "${aws_iam_user.spinnaker_s3_user.name}"
}

locals {
  spinnaker_s3_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "s3:*"
      ],
      "Effect": "Allow",
      "Resource": [
        "arn:aws:s3:::${aws_s3_bucket.spinnaker_external_storage.bucket}",
        "arn:aws:s3:::${aws_s3_bucket.spinnaker_external_storage.bucket}/*"
      ]
    }
  ]
}
POLICY
}

resource "aws_iam_user_policy" "spinnaker_s3" {
  name   = "spinnaker_s3"
  user   = "${aws_iam_user.spinnaker_s3_user.name}"
  policy = "${local.spinnaker_s3_policy}"
}
