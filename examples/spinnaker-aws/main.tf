module "eks" {
  source = "../../modules/terraform-eks"
}

#module "spinnaker" {
#  source = "../../modules/spinnaker-install"
#  k8s_id = "${module.eks.cluster_id}"
#  s3_bucket ="${module.eks.s3_bucket}"
#  s3_bucket_key_id ="${module.eks.s3_bucket_key_id}"
#  s3_bucket_secret_key ="${module.eks.s3_bucket_secret_key}"
#}


