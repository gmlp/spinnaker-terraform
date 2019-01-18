variable "node_instance_type" {
  default = "t2.medium"
}

variable "node_asg_max_size" {
  default = "4"
}

variable "node_asg_min_size" {
  default = "3"
}

variable "cluster_name" {
  default = "eks_cluster"
}
