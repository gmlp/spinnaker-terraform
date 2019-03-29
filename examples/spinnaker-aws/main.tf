provider "aws" {
  region = "us-east-1"
}

##########################
# EKS CLUSTER SUBNETS
##########################

resource "aws_default_subnet" "az1" {
  availability_zone = "us-east-1a"
}

resource "aws_default_subnet" "az2" {
  availability_zone = "us-east-1b"
}

##########################
# EKS CLUSTER SUBNETS
##########################

resource "random_id" "bucket_id" {
  keepers {
    id = "${module.eks.cluster_id}"
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

resource "aws_default_vpc" "default" {
}

variable "kubeconfig_name" {
  default= "kubeconfig"
}
variable "config_output_path" {
  default= "./.config/"
}
variable "cluster_name" {
  default ="eks_cluster"
}


module "eks" {
  source = "../../modules/terraform-aws-eks"
  cluster_name = "${var.cluster_name}"
  subnets = ["${aws_default_subnet.az1.id}","${aws_default_subnet.az2.id}"]
  vpc_id = "${aws_default_vpc.default.id}"
  config_output_path = "${var.config_output_path}"
  kubeconfig_name = "${var.kubeconfig_name}"
  worker_groups = [
      {
          instance_type = "t2.medium"
          asg_max_size = "3"
          asg_desired_capacity ="3"
      }
  ]
  tags = {
      environment = "test"
  }
}

module "spinnaker" {
  source = "../../modules/spinnaker-install"
  k8s_id = "${module.eks.cluster_id}"
  s3_bucket ="${aws_s3_bucket.spinnaker_external_storage.bucket}"
  s3_bucket_key_id ="${aws_iam_access_key.spinnaker_s3_user_keys.id}"
  s3_bucket_secret_key ="${aws_iam_access_key.spinnaker_s3_user_keys.secret}"
  kubeconfig = "${var.config_output_path}${var.kubeconfig_name}_${var.cluster_name}"
}