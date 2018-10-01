terraform {
  required_version = ">= 0.11.2"

  backend "s3" {}
}

variable "aws_assume_role_arn" {
  type = "string"
}

variable "domain_name" {
  type    = "string"
  default = "cloudposse.com"
}

variable "namespace" {
  type        = "string"
  description = "Namespace (e.g. `cp` or `cloudposse`)"
  default     = "cp"
}

variable "stage" {
  type        = "string"
  description = "Stage (e.g. `prod`, `dev`, `staging`)"
}

variable "name" {
  type        = "string"
  description = "Application or solution name (e.g. `app`)"
  default     = "apk"
}

variable "s3_bucket_name" {
  type        = "string"
  description = "S3 Bucket name for alpine packages (e.g. `eg-prod-apk`)"
  default     = "apk.cloudposse.com"
}

provider "aws" {
  assume_role {
    role_arn = "${var.aws_assume_role_arn}"
  }
}

locals {
  s3_bucket_name = "${var.name}.${var.domain_name}"
}

module "apk_user" {
  source    = "git::https://github.com/cloudposse/terraform-aws-iam-s3-user.git?ref=0.1.2"
  namespace = "${var.namespace}"
  stage     = "${var.stage}"
  name      = "${var.name}"

  s3_actions = [
    "s3:ListBucket",
    "s3:PutObjectAcl",
    "s3:PutObject",
    "s3:GetObject",
    "s3:DeleteObject",
    "s3:AbortMultipartUpload",
  ]

  s3_resources = ["arn:aws:s3:::${var.s3_bucket_name}", "arn:aws:s3:::${var.s3_bucket_name}/*"]
}
