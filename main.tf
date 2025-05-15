terraform {
  required_version = ">= 1.0.0"
  required_providers {
    coder = {
      source  = "coder/coder"
      version = "~> 0.11.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.22.0"
    }
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0.2"
    }
  }
}

provider "coder" {}

provider "kubernetes" {
  # Authenticate via kubeconfig file or in-cluster config
}

provider "docker" {}

data "coder_workspace" "me" {}

data "coder_parameter" "use_kubeconfig" {
  name         = "use_kubeconfig"
  display_name = "Use Local Kubeconfig"
  description  = "Use local kubeconfig file for Kubernetes cluster authentication"
  type         = "bool"
  default      = false
  mutable      = true
  icon         = "/icon/kubernetes.svg"
}

data "coder_parameter" "namespace" {
  name         = "namespace"
  display_name = "Kubernetes Namespace"
  description  = "The namespace to create workspaces in (must exist prior to creating workspaces)"
  type         = "string"
  default      = "coder-workspaces"
  mutable      = true
  icon         = "/icon/namespace.svg"
}

data "coder_parameter" "cpu" {
  name         = "cpu"
  display_name = "CPU Cores"
  description  = "Number of CPU cores for the workspace"
  type         = "number"
  default      = 4
  mutable      = true
  icon         = "/icon/cpu.svg"
  validation {
    min = 1
    max = 8
  }
}

data "coder_parameter" "memory" {
  name         = "memory"
  display_name = "Memory (GB)"
  description  = "Memory in GB for the workspace"
  type         = "number"
  default      = 8
  mutable      = true
  icon         = "/icon/memory.svg"
  validation {
    min = 4
    max = 16
  }
}

data "coder_parameter" "disk_size" {
  name         = "disk_size"
  display_name = "Disk Size (GB)"
  description  = "Disk size in GB for the workspace"
  type         = "number"
  default      = 50
  mutable      = true
  icon         = "/icon/disk.svg"
  validation {
    min = 20
    max = 100
  }
}

data "coder_parameter" "docker_host" {
  name         = "docker_host"
  display_name = "Docker Host"
  description  = "Docker daemon address to connect to (e.g., 'unix:///var/run/docker.sock' or 'tcp://localhost:2375')"
  type         = "string"
  default      = "unix:///var/run/docker.sock"
  mutable      = true
  icon         = "/icon/docker.svg"
}

data "coder_parameter" "container_image" {
  name         = "container_image"
  display_name = "Container Image"
  description  = "The container image to use for the workspace"
  type         = "string"
  default      = "ghcr.io/${split("/", data.coder_workspace.me.owner_id)[0]}/templates-dev:latest"
  mutable      = true
  icon         = "/icon/docker.svg"
}

data "coder_parameter" "kubernetes_repo" {
  name         = "kubernetes_repo"
  display_name = "Kubernetes Repository"
  description  = "The Git repository URL for Kubernetes. Can be your fork or the main repository."
  type         = "string"
  default      = "https://github.com/kubernetes/kubernetes.git"
  mutable      = true
  icon         = "/icon/git.svg"
}

data "coder_parameter" "kubernetes_branch" {
  name         = "kubernetes_branch"
  display_name = "Kubernetes Branch"
  description  = "The Git branch to clone. Use 'master' for the main branch or specify your working branch."
  type         = "string"
  default      = "master"
  mutable      = true
  icon         = "/icon/git.svg"
}

# Build custom image for development
resource "docker_image" "kubernetes_dev" {
  name = "kubernetes-dev:latest"
  build {
    context = path.module
    dockerfile = "Dockerfile"
  }
  triggers = {
    # Rebuild image when Dockerfile changes
    dockerfile = filesha256("${path.module}/Dockerfile")
  }
}

resource "coder_agent" "main" {
  os             = "linux"
  arch           = "amd64"
  startup_script = <<-EOT
    #!/bin/bash
    set -euo pipefail

    # Clone Kubernetes repository if it doesn't exist
    if [ ! -d "$HOME/go/src/k8s.io/kubernetes" ]; then
      mkdir -p $HOME/go/src/k8s.io
      cd $HOME/go/src/k8s.io
      git clone --branch ${data.coder_parameter.kubernetes_branch.value} ${data.coder_parameter.kubernetes_repo.value} kubernetes
      cd kubernetes
    else
      cd $HOME/go/src/k8s.io/kubernetes
      git fetch origin
      git checkout ${data.coder_parameter.kubernetes_branch.value}
      git pull origin ${data.coder_parameter.kubernetes_branch.value}
    fi

    # Add useful aliases
    echo 'alias k=kubectl' >> ~/.bashrc
    echo 'source <(kubectl completion bash)' >> ~/.bashrc
    echo 'complete -o default -F __start_kubectl k' >> ~/.bashrc

    # Message to display when workspace is ready
    echo "Your Kubernetes development environment is ready!"
  EOT

  env = {
    DOCKER_HOST = data.coder_parameter.docker_host.value
  }
}

resource "kubernetes_persistent_volume_claim" "home" {
  metadata {
    name      = "coder-${data.coder_workspace.me.owner}-${data.coder_workspace.me.name}-home"
    namespace = data.coder_parameter.namespace.value
  }
  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = "${data.coder_parameter.disk_size.value}Gi"
      }
    }
  }
}

resource "kubernetes_pod" "main" {
  count = data.coder_workspace.me.start_count
  metadata {
    name      = "coder-${data.coder_workspace.me.owner}-${data.coder_workspace.me.name}"
    namespace = data.coder_parameter.namespace.value
  }
  spec {
    security_context {
      run_as_user = 1000
      run_as_group = 0  # root group
      fs_group    = 1000
    }
    container {
      name    = "dev"
      image   = data.coder_parameter.container_image.value
      command = ["sh", "-c", coder_agent.main.init_script]
      env {
        name  = "CODER_AGENT_TOKEN"
        value = coder_agent.main.token
      }
      dynamic "env" {
        for_each = coder_agent.main.env
        content {
          name  = env.key
          value = env.value
        }
      }
      resources {
        requests = {
          cpu    = "${data.coder_parameter.cpu.value}"
          memory = "${data.coder_parameter.memory.value}Gi"
        }
        limits = {
          cpu    = "${data.coder_parameter.cpu.value}"
          memory = "${data.coder_parameter.memory.value}Gi"
        }
      }
      volume_mount {
        mount_path = "/home/coder"
        name       = "home"
        read_only  = false
      }
    }
    volume {
      name = "home"
      persistent_volume_claim {
        claim_name = kubernetes_persistent_volume_claim.home.metadata[0].name
      }
    }
  }
} 