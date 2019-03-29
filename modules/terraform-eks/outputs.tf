#
# Outputs
#

locals {
  config_map_aws_auth = <<CONFIGMAPAWSAUTH
apiVersion: v1
kind: ConfigMap
metadata:
  name: aws-auth
  namespace: kube-system
data:
  mapRoles: |
    - groups:
      - system:bootstrappers
      - system:nodes
      rolearn: ${aws_iam_role.spinnaker_auth_role.arn}
      username: system:node:{{EC2PrivateDNSName}}
  mapUsers: |
CONFIGMAPAWSAUTH

  kubeconfig = <<KUBECONFIG
apiVersion: v1
clusters:
- cluster:
    server: ${aws_eks_cluster.eks_cluster.endpoint}
    certificate-authority-data: ${aws_eks_cluster.eks_cluster.certificate_authority.0.data}
  name: ${var.cluster_name}
contexts:
- context:
    cluster: ${var.cluster_name}
    user: aws
  name: ${var.cluster_name}
current-context: ${var.cluster_name}
kind: Config
preferences: {}
users:
- name: aws
  user:
    exec:
      apiVersion: client.authentication.k8s.io/v1alpha1
      command: aws-iam-authenticator
      args:
        - "token"
        - "-i"
        - "${var.cluster_name}"
KUBECONFIG
}

output "config_map_aws_auth" {
  value = "${local.config_map_aws_auth}"
}

output "kubeconfig" {
  value = "${local.kubeconfig}"
}

output "cluster_id" {
  value = "${aws_eks_cluster.eks_cluster.id}"
}

output "s3_bucket" {
  value = "${aws_s3_bucket.spinnaker_external_storage.bucket}"
}

output "s3_bucket_key_id" {
  value = "${aws_iam_access_key.spinnaker_s3_user_keys.id}"
}

output "s3_bucket_secret_key" {
  value = "${aws_iam_access_key.spinnaker_s3_user_keys.secret}"
}

