provider "aws" {
  region = "us-east-1"
}

##########################
# Base IAM ROLE
##########################

resource "aws_iam_role" "base_iam_role" {
  name = "base-role"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

##########################
# EKS IAM ROLE
##########################

resource "aws_iam_role" "eks_service_role" {
  name = "eks-role"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = "${aws_iam_role.eks_service_role.name}"
}

resource "aws_iam_role_policy_attachment" "eks_service_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
  role       = "${aws_iam_role.eks_service_role.name}"
}

resource "aws_iam_instance_profile" "base_instance_profile" {
  name = "base_instance_profile"
  role = "${aws_iam_role.base_iam_role.name}"
}

resource "aws_iam_instance_profile" "spinnaker_instance_profile" {
  name = "spinnaker_instance_profile"
  role = "${aws_iam_role.spinnaker_auth_role.name}"
}

##########################
# Spinnaker IAM ROLE
##########################

resource "aws_iam_role" "spinnaker_auth_role" {
  name = "spinnaker_auth_role"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "power_user_access" {
  policy_arn = "arn:aws:iam::aws:policy/PowerUserAccess"
  role       = "${aws_iam_role.spinnaker_auth_role.name}"
}

resource "aws_iam_role_policy_attachment" "eks_worker_node_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = "${aws_iam_role.spinnaker_auth_role.name}"
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = "${aws_iam_role.spinnaker_auth_role.name}"
}

resource "aws_iam_role_policy_attachment" "ec2_container_registry_ro" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = "${aws_iam_role.spinnaker_auth_role.name}"
}

#################################################
# IAM policy: Allow to assume roles of managed Accounts 
#################################################
data "aws_caller_identity" "current" {}

data "template_file" "spinnaker_assume_role_policy_tpl" {
  template = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Effect": "Allow",
      "Resource": "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/spinnakerManaged"
    }
  ]
}
EOF
}

resource "aws_iam_policy" "spinnaker_assume_role_policy" {
  name   = "spinnaker_assume_role_policy"
  policy = "${data.template_file.spinnaker_assume_role_policy_tpl.rendered}"
}

resource "aws_iam_role_policy_attachment" "spinnaker_assume_role_policy_spinnaker_auth_role_attach" {
  role       = "${aws_iam_role.spinnaker_auth_role.name}"
  policy_arn = "${aws_iam_policy.spinnaker_assume_role_policy.arn}"
}

#################################################
# IAM ROLE: for managed Accounts 
#################################################

data "template_file" "spinnaker_managed_role_policy_tpl" {
  template = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "${aws_iam_role.spinnaker_auth_role.arn}" 
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role" "spinnaker_managed_role" {
  name               = "spinnaker_managed_role"
  assume_role_policy = "${data.template_file.spinnaker_managed_role_policy_tpl.rendered}"
}

# Note: You should restrict resource only to certain set of roles, if required
resource "aws_iam_policy" "spinnaker_pass_role" {
  name = "spinnaker_pass_role"

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "iam:PassRole",
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "spinnaker_pass_role_spinnaker_managed_role_attach" {
  role       = "${aws_iam_role.spinnaker_managed_role.name}"
  policy_arn = "${aws_iam_policy.spinnaker_pass_role.arn}"
}

##########################
# EKS CLUSTER
##########################

resource "aws_default_subnet" "az1" {
  availability_zone = "us-east-1a"
}

resource "aws_default_subnet" "az2" {
  availability_zone = "us-east-1b"
}

resource "aws_eks_cluster" "eks_cluster" {
  name     = "eks_cluster"
  role_arn = "${aws_iam_role.eks_service_role.arn}"

  vpc_config {
    subnet_ids = [
      "${aws_default_subnet.az1.id}",
      "${aws_default_subnet.az2.id}",
    ]
  }
}

##########################
# EKS WORKER NODES 
##########################

