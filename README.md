# Vault AWS Secrets Engine + S3 — WIF Edition

Provisions an S3 bucket and configures Vault's AWS Secrets Engine using
**Workload Identity Federation (WIF)** — no static IAM access keys stored in Vault.

## Files

| File | Purpose |
|---|---|
| `main.tf` | S3 bucket, IAM OIDC provider, IAM role, Vault backend + role |
| `variables.tf` | Input variables |
| `outputs.tf` | Useful outputs after apply |
| `vault-policy.hcl` | Vault HCL policy template (rendered by Terraform) |
| `terraform.tfvars.example` | Example variable values — copy to `terraform.tfvars` |

## Prerequisites

- Vault ≥ 1.15 (WIF support for AWS secrets engine)
- Vault TLS enabled (AWS OIDC provider requires HTTPS)
- AWS credentials available to Terraform (via env vars or instance profile)

## Quick Start

```bash
# 1. Copy and fill in your variables
cp terraform.tfvars.example terraform.tfvars

# 2. Get your Vault TLS thumbprint and update thumbprint_list in main.tf
openssl s_client -connect <vault_host>:443 -showcerts 2>/dev/null \
  | openssl x509 -fingerprint -sha1 -noout \
  | tr -d ':' | cut -d= -f2 | tr '[:upper:]' '[:lower:]'

# 3. Init and apply
terraform init
terraform apply

# 4. Generate dynamic S3 credentials
vault read aws/creds/s3-dynamic-role

# 5. Assign the policy to a token or AppRole
vault token create -policy="s3-secrets-policy"
vault write auth/approle/role/my-app token_policies="s3-secrets-policy"
```

## Python Usage (hvac)

```python
import hvac
import boto3

client = hvac.Client(url="https://vault.example.com:8200", token="<token>")

creds = client.secrets.aws.generate_credentials(name="s3-dynamic-role")
access_key = creds["data"]["access_key"]
secret_key = creds["data"]["secret_key"]
lease_id   = creds["lease_id"]

s3 = boto3.client(
    "s3",
    aws_access_key_id=access_key,
    aws_secret_access_key=secret_key,
)

# Don't forget to revoke the lease when done
client.sys.revoke_lease(lease_id=lease_id)
```

## Vault Policy

The `vault-policy.hcl` template grants a token/entity the minimum permissions to:
- Generate dynamic IAM credentials (`aws/creds/s3-dynamic-role`)
- Renew and revoke its own leases
- Renew itself
- Read (not modify) the backend config and role definition

Assign it to any auth method via `token_policies`.
