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

variable "node_instance_type" {
  default = "t2.medium"
}

variable "node_asg_max_size" {
  default = "4"
}

variable "node_asg_min_size" {
  default = "3"
}

resource "aws_default_subnet" "az1" {
  availability_zone = "us-east-1a"
}

resource "aws_default_subnet" "az2" {
  availability_zone = "us-east-1b"
}

resource "aws_security_group" "control_plane_sg" {
  name        = "control_plane_sg"
  description = "Cluster communication with worker nodes"

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_eks_cluster" "eks_cluster" {
  name     = "eks_cluster"
  role_arn = "${aws_iam_role.eks_service_role.arn}"

  vpc_config {
    security_group_ids = ["${aws_security_group.control_plane_sg.id}"]

    subnet_ids = [
      "${aws_default_subnet.az1.id}",
      "${aws_default_subnet.az2.id}",
    ]
  }
}

##########################
# EKS WORKER NODES 
##########################

resource "aws_security_group" "node_security_group" {
  description = "Cluster communication with worker nodes"

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = "${
    map(
     "Name", "eks_cluster-node",
     "kubernetes.io/cluster/eks_cluster", "owned",
    )
  }"
}

resource "aws_security_group_rule" "node_sg_ingress" {
  description              = "Allow node to communicate with each other"
  from_port                = 0
  to_port                  = 65535
  protocol                 = "-1"
  security_group_id        = "${aws_security_group.node_security_group.id}"
  source_security_group_id = "${aws_security_group.node_security_group.id}"
  type                     = "ingress"
}

resource "aws_security_group_rule" "node_sg_from_control_plane_ingress" {
  description              = "Allow worker Kubelets and pods to receive communication from the cluster control plane"
  from_port                = 1025
  to_port                  = 65535
  protocol                 = "tcp"
  security_group_id        = "${aws_security_group.node_security_group.id}"
  source_security_group_id = "${aws_security_group.control_plane_sg.id}"
  type                     = "ingress"
}

resource "aws_security_group_rule" "control_plane_egress_2_node_sg" {
  description              = "Allow the cluster control plane to communicate with worker Kubelet and pods"
  from_port                = 1025
  to_port                  = 65535
  protocol                 = "tcp"
  security_group_id        = "${aws_security_group.control_plane_sg.id}"
  source_security_group_id = "${aws_security_group.node_security_group.id}"
  type                     = "egress"
}

resource "aws_security_group_rule" "control_plane_sg_ingress" {
  description              = "Allow pods to communicate with the cluster API Server"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = "${aws_security_group.control_plane_sg.id}"
  source_security_group_id = "${aws_security_group.node_security_group.id}"
  type                     = "ingress"
}

locals {
  aws-eks-node-userdata = <<USERDATA
#!/bin/bash
set -o xtrace
/etc/eks/bootstrap.sh \
 --apiserver-endpoint '${aws_eks_cluster.eks_cluster.endpoint}' \
 --b64-cluster-ca '${aws_eks_cluster.eks_cluster.certificate_authority.0.data}' \
  'eks_cluster'
USERDATA
}

data "aws_ami" "aws_eks_worker" {
  filter {
    name   = "name"
    values = ["amazon-eks-node-v*"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  most_recent = true
  owners      = ["602401143452"] # Amazon EKS AMI Account ID
}

resource "aws_launch_configuration" "node_launch_config" {
  associate_public_ip_address = true
  iam_instance_profile        = "${aws_iam_instance_profile.spinnaker_instance_profile.name}"
  image_id                    = "${data.aws_ami.aws_eks_worker.id}"
  instance_type               = "${var.node_instance_type}"
  name_prefix                 = "eks_cluster"
  security_groups             = ["${aws_security_group.node_security_group.id}"]
  user_data_base64            = "${base64encode(local.aws-eks-node-userdata)}"

  lifecycle {
    create_before_destroy = true
  }

  root_block_device {
    volume_size = "50"
  }
}

resource "aws_autoscaling_group" "node_group" {
  name                 = "eks_cluster_asg_node"
  desired_capacity     = "${var.node_asg_max_size}"
  launch_configuration = "${aws_launch_configuration.node_launch_config.id}"
  max_size             = "${var.node_asg_max_size}"
  min_size             = "${var.node_asg_min_size}"

  vpc_zone_identifier = [
    "${aws_default_subnet.az1.id}",
    "${aws_default_subnet.az2.id}",
  ]

  tag {
    key                 = "Name"
    value               = "eks_cluster_asg_node"
    propagate_at_launch = true
  }

  tag {
    key                 = "kubernetes.io/cluster/eks_cluster"
    value               = "owned"
    propagate_at_launch = true
  }
}
