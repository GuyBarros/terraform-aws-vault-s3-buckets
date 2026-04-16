terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "~> 4.0"
    }
  }
}

# ──────────────────────────────────────────────
# Providers
# ──────────────────────────────────────────────

provider "aws" {
  region = var.aws_region
}

provider "vault" {
  
}

# ──────────────────────────────────────────────
# S3 Bucket
# ──────────────────────────────────────────────

resource "aws_s3_bucket" "main" {
  bucket = var.bucket_name

  tags = {
    Name      = var.bucket_name
    ManagedBy = "Terraform"
  }
}

resource "aws_s3_bucket_versioning" "main" {
  bucket = aws_s3_bucket.main.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "main" {
  bucket = aws_s3_bucket.main.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "main" {
  bucket                  = aws_s3_bucket.main.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ──────────────────────────────────────────────
# Vault OIDC — fetch issuer URL
# ──────────────────────────────────────────────

data "vault_generic_secret" "oidc_config" {
  path = "identity/oidc/.well-known/openid-configuration"
}

locals {
  vault_oidc_issuer = data.vault_generic_secret.oidc_config.data["issuer"]
}

# ──────────────────────────────────────────────
# IAM OIDC Provider — trusts Vault's JWKS endpoint
# ──────────────────────────────────────────────

resource "aws_iam_openid_connect_provider" "vault" {
  url            = local.vault_oidc_issuer
  client_id_list = [var.vault_identity_token_audience]

  # Replace with the real SHA-1 thumbprint of your Vault TLS cert.
  # Obtain it with:
  #   openssl s_client -connect <vault_host>:443 -showcerts 2>/dev/null \
  #     | openssl x509 -fingerprint -sha1 -noout \
  #     | tr -d ':' | cut -d= -f2 | tr '[:upper:]' '[:lower:]'
  thumbprint_list = [var.vault_thumbprint]

  tags = {
    ManagedBy = "Terraform"
  }
}

# ──────────────────────────────────────────────
# IAM Role — assumed by Vault via WIF
# ──────────────────────────────────────────────

data "aws_iam_policy_document" "vault_wif_trust" {
  statement {
    sid     = "VaultWIF"
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.vault.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(local.vault_oidc_issuer, "https://", "")}:aud"
      values   = [var.vault_identity_token_audience]
    }

    condition {
      test     = "StringLike"
      variable = "${replace(local.vault_oidc_issuer, "https://", "")}:sub"
      values   = ["plugin-identity:root:aws:*"]
    }
  }
}

resource "aws_iam_role" "vault_admin" {
  name               = "vault-aws-secrets-engine-wif"
  assume_role_policy = data.aws_iam_policy_document.vault_wif_trust.json

  tags = {
    ManagedBy = "Terraform"
    Purpose   = "Vault AWS Secrets Engine via WIF"
  }
}

data "aws_iam_policy_document" "vault_admin_permissions" {
  statement {
    sid    = "VaultIAMManagement"
    effect = "Allow"
    actions = [
      "iam:AttachUserPolicy",
      "iam:CreateAccessKey",
      "iam:CreateUser",
      "iam:DeleteAccessKey",
      "iam:DeleteUser",
      "iam:DeleteUserPolicy",
      "iam:DetachUserPolicy",
      "iam:GetUser",
      "iam:ListAccessKeys",
      "iam:ListAttachedUserPolicies",
      "iam:ListGroupsForUser",
      "iam:ListUserPolicies",
      "iam:PutUserPolicy",
      "iam:RemoveUserFromGroup",
      "iam:TagUser"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "vault_admin" {
  name   = "vault-admin-inline-policy"
  role   = aws_iam_role.vault_admin.name
  policy = data.aws_iam_policy_document.vault_admin_permissions.json
}

# ──────────────────────────────────────────────
# Vault AWS Secrets Engine — WIF config
# ──────────────────────────────────────────────

resource "vault_aws_secret_backend" "aws" {
  path = "aws"

  role_arn                = aws_iam_role.vault_admin.arn
  identity_token_audience = var.vault_identity_token_audience
  identity_token_ttl      = var.vault_identity_token_ttl

  default_lease_ttl_seconds = 3600
  max_lease_ttl_seconds     = 86400

  depends_on = [aws_iam_role_policy.vault_admin]
}

# ──────────────────────────────────────────────
# Vault Role — dynamic IAM creds scoped to S3
# ──────────────────────────────────────────────

data "aws_iam_policy_document" "s3_access" {
  statement {
    sid       = "ListBucket"
    effect    = "Allow"
    actions   = ["s3:ListBucket", "s3:GetBucketLocation"]
    resources = [aws_s3_bucket.main.arn]
  }

  statement {
    sid    = "ObjectOperations"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:GetObjectVersion",
      "s3:GetObjectTagging",
      "s3:PutObjectTagging"
    ]
    resources = ["${aws_s3_bucket.main.arn}/*"]
  }
}

resource "vault_aws_secret_backend_role" "s3_role" {
  backend         = vault_aws_secret_backend.aws.path
  name            = var.vault_aws_role_name
  credential_type = "iam_user"
  policy_document = data.aws_iam_policy_document.s3_access.json
}

# ──────────────────────────────────────────────
# Vault Policy — controls who can read S3 creds
# ──────────────────────────────────────────────

resource "vault_policy" "s3_secrets" {
  name   = var.vault_policy_name
  policy = templatefile("${path.module}/vault-policy.hcl", {
    aws_backend_path = vault_aws_secret_backend.aws.path
    role_name        = var.vault_aws_role_name
  })
}
