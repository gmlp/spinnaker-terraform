resource "null_resource" "install" {
  triggers {
    id = "${var.k8s_id}"
  }

  provisioner "local-exec" {
    command = "bash ${path.module}/scripts/spinnaker_init.sh '${var.s3_bucket}' '${var.s3_bucket_key_id}' '${var.s3_bucket_secret_key}' '${path.module}'"
  }
}