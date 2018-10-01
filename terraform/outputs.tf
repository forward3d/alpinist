output "apk_user_name" {
  value       = "${module.apk_user.user_name}"
  description = "Normalized IAM user name"
}

output "apk_user_arn" {
  value       = "${module.apk_user.user_arn}"
  description = "The ARN assigned by AWS for the user"
}

output "apk_user_unique_id" {
  value       = "${module.apk_user.user_unique_id}"
  description = "The user unique ID assigned by AWS"
}

output "apk_user_access_key_id" {
  value       = "${module.apk_user.access_key_id}"
  description = "The access key ID"
}

output "apk_user_secret_access_key" {
  value       = "${module.apk_user.secret_access_key}"
  description = "The secret access key. This will be written to the state file in plain-text"
}

output "apk_s3_bucket_name" {
  value = "${local.s3_bucket_name}"
}
