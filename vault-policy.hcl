# ──────────────────────────────────────────────────────────────────────────────
# Vault Policy: s3-secrets-policy
#
# Grants a token/entity the minimum permissions needed to:
#   1. Generate dynamic IAM credentials for the S3 bucket role
#   2. Renew and revoke its own leases
#   3. Read AWS secrets engine configuration (read-only, for observability)
#
# Assign this policy to a Vault token, AppRole, or identity entity:
#   vault token create -policy="${vault_policy_name}"
#   vault write auth/approle/role/my-app token_policies="${vault_policy_name}"
# ──────────────────────────────────────────────────────────────────────────────

# Generate dynamic IAM credentials for the S3 role
path "${aws_backend_path}/creds/${role_name}" {
  capabilities = ["read"]
}

# Allow STS credentials too (if role is switched to assumed_role type later)
path "${aws_backend_path}/sts/${role_name}" {
  capabilities = ["read", "create", "update"]
}

# Allow the token to renew its own leases
path "sys/leases/renew" {
  capabilities = ["update"]
}

# Allow the token to revoke its own leases (clean up credentials on exit)
path "sys/leases/revoke" {
  capabilities = ["update"]
}

# Allow self-renewal of the token itself
path "auth/token/renew-self" {
  capabilities = ["update"]
}

# Allow the token to look up its own metadata (useful for debugging)
path "auth/token/lookup-self" {
  capabilities = ["read"]
}

# Read-only access to the AWS backend config (for observability/debugging)
# Remove this block if you want to restrict visibility entirely
path "${aws_backend_path}/config/root" {
  capabilities = ["read"]
}

# Read-only access to the role definition
path "${aws_backend_path}/roles/${role_name}" {
  capabilities = ["read"]
}
