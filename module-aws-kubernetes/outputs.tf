output "eks_cluster_id" {
  value = aws_eks_cluster.ops-up-running.id
}

output "eks_cluster_name" {
  value = aws_eks_cluster.ops-up-running.name
}

output "eks_cluster_certificate_data" {
  value = aws_eks_cluster.ops-up-running.certificate_authority.0.data
}

output "eks_cluster_endpoint" {
  value = aws_eks_cluster.ops-up-running.endpoint
}

output "eks_cluster_nodegroup_id" {
  value = aws_eks_node_group.ops-node-group.id
}

output "eks_cluster_security_group_id" {
  value = aws_security_group.ops-cluster.id
}