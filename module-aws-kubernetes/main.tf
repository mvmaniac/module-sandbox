provider "aws" {
  region = var.aws_region
}

locals {
  cluster_name = "${var.cluster_name}-${var.env_name}"
}

# 클러스터 액세스 관리
# Amazon EKS 서비스가 사용자를 대신할 수 있는 신뢰 정책을 설정
# EKS 서비스에 대한 새로운 자격 증명과 접근 정책을 정의하고 AmazonEKSClusterPolicy 정책을 연결
resource "aws_iam_role" "ops-cluster" {
  name = local.cluster_name

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "ops-cluster-AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.ops-cluster.name
}

# VPC 보안 그룹 설정
# VPC 보안 그룹은 네트워크로 들어오고 나가는 트래픽의 종류를 제한하는 것으로
# 아웃바운드 트래픽을 무제한 허용, 인그레스 규칙은 정의하지 않았으므로 인바운드 트래픽은 허용하지 않음
resource "aws_security_group" "ops-cluster" {
  name        = local.cluster_name
  description = "Cluster communication with worker nodes"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    self        = true
  }

  tags = {
    Name = "ops-up-running"
  }
}

# EKS 클러스터 정의
resource "aws_eks_cluster" "ops-up-running" {
  name     = local.cluster_name
  role_arn = aws_iam_role.ops-cluster.arn

  vpc_config {
    security_group_ids = [aws_security_group.ops-cluster.id]
    subnet_ids         = var.cluster_subnet_ids
  }

  depends_on = [
    aws_iam_role_policy_attachment.ops-cluster-AmazonEKSClusterPolicy
  ]
}


# EKS 노드 역할
resource "aws_iam_role" "ops-node" {
  name = "${local.cluster_name}.node"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

# EKS 노드 정책
resource "aws_iam_role_policy_attachment" "ops-node-AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.ops-node.name
}

resource "aws_iam_role_policy_attachment" "ops-node-AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.ops-node.name
}

resource "aws_iam_role_policy_attachment" "ops-node-AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.ops-node.name
}

# EKS 노드 그룹 정의
resource "aws_eks_node_group" "ops-node-group" {
  cluster_name    = aws_eks_cluster.ops-up-running.name
  node_group_name = "microservices"
  node_role_arn   = aws_iam_role.ops-node.arn
  subnet_ids      = var.nodegroup_subnet_ids

  scaling_config {
    desired_size = var.nodegroup_desired_size
    max_size     = var.nodegroup_max_size
    min_size     = var.nodegroup_min_size
  }

  disk_size      = var.nodegroup_disk_size
  instance_types = var.nodegroup_instance_types

  depends_on = [
    aws_iam_role_policy_attachment.ops-node-AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.ops-node-AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.ops-node-AmazonEC2ContainerRegistryReadOnly,
  ]
}

# 생성된 클러스터를 기반으로 큐브 구성 파일 생성
resource "local_file" "kubeconfig" {
  content  = <<KUBECONFIG
apiVersion: v1
clusters:
- cluster:
    certificate-authority-data: ${aws_eks_cluster.ops-up-running.certificate_authority.0.data}
    server: ${aws_eks_cluster.ops-up-running.endpoint}
  name: ${aws_eks_cluster.ops-up-running.arn}
contexts:
- context:
    cluster: ${aws_eks_cluster.ops-up-running.arn}
    user: ${aws_eks_cluster.ops-up-running.arn}
  name: ${aws_eks_cluster.ops-up-running.arn}
current-context: ${aws_eks_cluster.ops-up-running.arn}
kind: Config
preferences: {}
users:
- name: ${aws_eks_cluster.ops-up-running.arn}
  user:
    exec:
      apiVersion: client.authentication.k8s.io/v1alpha1
      command: aws-iam-authenticator
      args:
        - "token"
        - "-i"
        - "${aws_eks_cluster.ops-up-running.name}"
    KUBECONFIG
  filename = "kubeconfig"
}

/*
#  Use data to ensure that the cluster is up before we start using it
data "aws_eks_cluster" "msur" {
  name = aws_eks_cluster.ops-up-running.id
}
# Use kubernetes provider to work with the kubernetes cluster API
provider "kubernetes" {
  load_config_file       = false
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.msur.certificate_authority.0.data)
  host                   = data.aws_eks_cluster.msur.endpoint
  exec {
    api_version = "client.authentication.k8s.io/v1alpha1"
    command     = "aws-iam-authenticator"
    args        = ["token", "-i", "${data.aws_eks_cluster.msur.name}"]
  }
}
# Create a namespace for microservice pods 
resource "kubernetes_namespace" "ops-namespace" {
  metadata {
    name = var.ops_namespace
  }
}
*/