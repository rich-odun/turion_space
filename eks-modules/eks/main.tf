# Provides an EKS Cluster
resource "aws_eks_cluster" "eks_cluster" {
  name     = var.cluster_name
  role_arn = aws_iam_role.eks_cluster_role.arn


  version = "1.30"

  encryption_config {
    resources = ["secrets"]

    provider {
      key_arn = aws_kms_key.eks_secrets_encryption.arn
    }
  }
  vpc_config {
    subnet_ids = [
      aws_subnet.eks_private_1.id,
      aws_subnet.eks_private_2.id,
      aws_subnet.eks_private_3.id,
      aws_subnet.eks_public_1.id,
      aws_subnet.eks_public_2.id,
      aws_subnet.eks_public_3.id
    ]
    endpoint_public_access  = false # Disable public access
    endpoint_private_access = true  # Enable private access
  }


  # Ensure that IAM Role permissions are created before and deleted after EKS Cluster handling.
  # Otherwise, EKS will not be able to properly delete EKS managed EC2 infrastructure such as Security Groups.
  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy_attachment,
    aws_iam_role_policy_attachment.eks_service_policy_attachment,
    aws_iam_role_policy_attachment.eks-AmazonEKSVPCResourceController
  ]

}

data "tls_certificate" "eks" {
  url = aws_eks_cluster.eks_cluster.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
  url             = data.tls_certificate.eks.url
}

# Provides an EKS Node Group 
resource "aws_eks_node_group" "eks_node_group" {
  cluster_name    = aws_eks_cluster.eks_cluster.name
  node_group_name = var.node_group_name
  node_role_arn   = aws_iam_role.eks_node_group_role.arn
  subnet_ids = [
    aws_subnet.eks_private_1.id,
    aws_subnet.eks_private_2.id,
    aws_subnet.eks_private_3.id
  ]

  # Enable Auto-scaling for EKS Node Group
  scaling_config {
    desired_size = 2
    max_size     = 5
    min_size     = 1
  }
  update_config {
    max_unavailable = 1
  }

  instance_types = ["t3.medium"]

  # Ensure that IAM Role permissions are created before and deleted after EKS Node Group handling.
  # Otherwise, EKS will not be able to properly delete EC2 Instances and Elastic Network Interfaces.
  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node_policy_attachment,
    aws_iam_role_policy_attachment.eks_cni_policy_attachment,
    aws_iam_role_policy_attachment.ec2_container_registry_readonly,
  ]
}
# Extra resources 
resource "aws_ebs_volume" "volume_space" {
  availability_zone = "us-east-1a"
  size              = 40
  encrypted         = true
  type              = "gp2"
}