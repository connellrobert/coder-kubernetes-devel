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
  }
}

provider "coder" {}

provider "kubernetes" {
  # Authenticate via kubeconfig file or in-cluster config
}

data "coder_workspace" "me" {}

variable "use_kubeconfig" {
  type        = bool
  description = "Use local kubeconfig file for Kubernetes cluster authentication"
  default     = false
}

variable "namespace" {
  type        = string
  description = "The namespace to create workspaces in (must exist prior to creating workspaces)"
  default     = "coder-workspaces"
}

variable "cpu" {
  type        = string
  description = "CPU cores for the workspace"
  default     = "4"
}

variable "memory" {
  type        = string
  description = "Memory in GB for the workspace"
  default     = "8"
}

variable "disk_size" {
  type        = string
  description = "Disk size in GB for the workspace"
  default     = "50"
}

variable "docker_host" {
  type        = string
  description = "Docker daemon address to connect to (e.g., 'unix:///var/run/docker.sock' or 'tcp://localhost:2375')"
  default     = "unix:///var/run/docker.sock"
}

resource "coder_agent" "main" {
  os             = "linux"
  arch           = "amd64"
  startup_script = <<-EOT
    #!/bin/bash
    set -euo pipefail

    # Install Go
    curl -Lo go.tar.gz https://go.dev/dl/go1.21.0.linux-amd64.tar.gz
    sudo rm -rf /usr/local/go
    sudo tar -C /usr/local -xzf go.tar.gz
    rm go.tar.gz
    echo 'export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin' >> ~/.bashrc

    # Install Docker CLI
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh ./get-docker.sh
    rm get-docker.sh
    sudo usermod -aG docker $USER

    # Configure Docker
    echo "export DOCKER_HOST=${var.docker_host}" >> ~/.bashrc

    # Install development tools
    sudo apt-get update
    sudo apt-get install -y build-essential git curl wget jq vim

    # Configure Git
    git config --global core.editor "vim"
    
    # Clone Kubernetes repository if it doesn't exist
    if [ ! -d "$HOME/go/src/k8s.io/kubernetes" ]; then
      mkdir -p $HOME/go/src/k8s.io
      cd $HOME/go/src/k8s.io
      git clone https://github.com/kubernetes/kubernetes.git
      cd kubernetes
      ./hack/install-etcd.sh
    fi

    # Add useful aliases
    echo 'alias k=kubectl' >> ~/.bashrc
    echo 'source <(kubectl completion bash)' >> ~/.bashrc
    echo 'complete -o default -F __start_kubectl k' >> ~/.bashrc

    # Install development dependencies
    cd $HOME/go/src/k8s.io/kubernetes
    make

    # Message to display when workspace is ready
    echo "Your Kubernetes development environment is ready!"
  EOT
}

resource "kubernetes_persistent_volume_claim" "home" {
  metadata {
    name      = "coder-${data.coder_workspace.me.owner}-${data.coder_workspace.me.name}-home"
    namespace = var.namespace
  }
  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = "${var.disk_size}Gi"
      }
    }
  }
}

resource "kubernetes_pod" "main" {
  count = data.coder_workspace.me.start_count
  metadata {
    name      = "coder-${data.coder_workspace.me.owner}-${data.coder_workspace.me.name}"
    namespace = var.namespace
  }
  spec {
    security_context {
      run_as_user = "1000"
      fs_group    = "1000"
    }
    container {
      name    = "dev"
      image   = "ubuntu:22.04"
      command = ["sh", "-c", coder_agent.main.init_script]
      env {
        name  = "CODER_AGENT_TOKEN"
        value = coder_agent.main.token
      }
      env {
        name  = "DOCKER_HOST"
        value = var.docker_host
      }
      resources {
        requests = {
          cpu    = "${var.cpu}"
          memory = "${var.memory}Gi"
        }
        limits = {
          cpu    = "${var.cpu}"
          memory = "${var.memory}Gi"
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