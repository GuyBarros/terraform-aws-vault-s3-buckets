variable "aws_region" {
  description = "AWS region where the S3 bucket will be created"
  type        = string
  default     = "us-east-1"
}

variable "bucket_name" {
  description = "Name of the S3 bucket"
  type        = string
}

variable "vault_thumbprint" {
  description = "SHA-1 thumbprint of the Vault server's TLS certificate (used for TLS verification in the Vault provider)"
  type        = string
  default     = "0000000000000000000000000000000000000000" # placeholder value, replace
 # Replace with the real SHA-1 thumbprint of your Vault TLS cert.
  # Obtain it with:
  #   openssl s_client -connect <vault_host>:443 -showcerts 2>/dev/null \
  #     | openssl x509 -fingerprint -sha1 -noout \
  #     | tr -d ':' | cut -d= -f2 | tr '[:upper:]' '[:lower:]'
}


variable "vault_aws_role_name" {
  description = "Name of the Vault AWS secrets engine role"
  type        = string
  default     = "s3-dynamic-role"
}

variable "vault_identity_token_audience" {
  description = "Audience claim for the JWT Vault sends to AWS STS (must match IAM role trust policy)"
  type        = string
  default     = "aws"
}

variable "vault_identity_token_ttl" {
  description = "TTL for the Vault-issued identity JWT"
  type        = number
  default     = 3600
}

variable "credential_ttl" {
  description = "Default TTL for dynamic IAM credentials"
  type        = string
  default     = "1h"
}

variable "credential_max_ttl" {
  description = "Max TTL for dynamic IAM credentials"
  type        = string
  default     = "24h"
}

variable "vault_policy_name" {
  description = "Name of the Vault policy that controls access to the AWS secrets engine role"
  type        = string
  default     = "s3-secrets-policy"
}
