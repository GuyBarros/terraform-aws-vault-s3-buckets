output "s3_bucket_name" {
  description = "Name of the created S3 bucket"
  value       = aws_s3_bucket.main.bucket
}

output "s3_bucket_arn" {
  description = "ARN of the created S3 bucket"
  value       = aws_s3_bucket.main.arn
}

output "vault_aws_backend_path" {
  description = "Vault AWS secrets engine mount path"
  value       = vault_aws_secret_backend.aws.path
}

output "vault_role_name" {
  description = "Vault role name to request dynamic credentials"
  value       = vault_aws_secret_backend_role.s3_role.name
}

output "vault_policy_name" {
  description = "Vault policy name to assign to tokens/entities that need S3 access"
  value       = vault_policy.s3_secrets.name
}

output "vault_cred_command" {
  description = "CLI command to generate dynamic S3 credentials"
  value       = "vault read aws/creds/${var.vault_aws_role_name}"
}

output "vault_oidc_issuer" {
  description = "Vault OIDC issuer URL used in the IAM OIDC provider"
  value       = local.vault_oidc_issuer
}

output "iam_role_arn" {
  description = "IAM role ARN assumed by Vault via WIF"
  value       = aws_iam_role.vault_admin.arn
}

output "iam_oidc_provider_arn" {
  description = "ARN of the IAM OIDC provider created for Vault"
  value       = aws_iam_openid_connect_provider.vault.arn
}
