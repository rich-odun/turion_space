resource "aws_kms_key" "eks_secrets_encryption" {
  description         = "KMS key for EKS secrets encryption"
  enable_key_rotation = true
}

resource "aws_kms_alias" "eks_secrets_encryption_alias" {
  name          = var.aws_kms_alias_name
  target_key_id = aws_kms_key.eks_secrets_encryption.id
}