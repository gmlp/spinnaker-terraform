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

###########################
#-- EKS CONTROL PLANE SG --
###########################

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

######################################
#---- EKS CLUSTER CONTROL PLANE ------
######################################

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

######################################
#---- EKS CLUSTER CONTROL PLANE ------
######################################

##########################
#------ EKS NODES SG -----
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

##########################
#------ EKS NODES SG -----
##########################

######################################
#------ EKS LAUNCH CONFIGURATION -----
######################################

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

######################################
#------ EKS LAUNCH CONFIGURATION -----
######################################

###########################
#--------- EKS ASG --------
###########################

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

###########################
#--------- EKS ASG --------
###########################

resource "null_resource" "init" {
  triggers {
    id = "${aws_eks_cluster.eks_cluster.id}"
  }

  provisioner "local-exec" {
    command = "bash scripts/init.sh '${local.kubeconfig}' '${local.config_map_aws_auth}'"
  }

  provisioner "local-exec" {
    command = "bash scripts/spinnaker_init.sh '${aws_s3_bucket.spinnaker_external_storage.bucket}' '${aws_iam_access_key.spinnaker_s3_user_keys.id}' '${aws_iam_access_key.spinnaker_s3_user_keys.secret}'"
  }
}
