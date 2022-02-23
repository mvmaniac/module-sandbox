# 쿠버네티스 공급자 구성
# AWS 인증자를 사용하여 지정한 쿠버네티스 인증서로 클러스터에 연결
provider "kubernetes" {
  # load_config_file       = false
  cluster_ca_certificate = base64decode(var.kubernetes_cluster_cert_data)
  host                   = var.kubernetes_cluster_endpoint
  exec {
    api_version = "client.authentication.k8s.io/v1alpha1"
    command     = "aws-iam-authenticator"
    args        = ["token", "-i", "${var.kubernetes_cluster_name}"]
  }
}

# 헬름 공급자 구성
# 헬름은 리눅스 환경의 apt-get과 같은 패키지 관리 도구로서 
# 쿠버네티스 기반 애플리케이션을 간단하고 쉽게 설치 할 수 있도록 설계됨
provider "helm" {
  kubernetes {
    # load_config_file       = false
    cluster_ca_certificate = base64decode(var.kubernetes_cluster_cert_data)
    host                   = var.kubernetes_cluster_endpoint
    exec {
      api_version = "client.authentication.k8s.io/v1alpha1"
      command     = "aws-iam-authenticator"
      args        = ["token", "-i", "${var.kubernetes_cluster_name}"]
    }
  }
}

# 헬름 차트를 사용하여 Argo CD 서버를 설치
resource "kubernetes_namespace" "argo-ns" {
  metadata {
    name = "argocd"
  }
}

resource "helm_release" "argocd" {
  name       = "ops-ur"
  chart      = "argo-cd"
  repository = "https://argoproj.github.io/argo-helm"
  namespace  = "argocd"
}