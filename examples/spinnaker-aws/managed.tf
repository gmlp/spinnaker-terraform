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
