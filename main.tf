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

resource "coder_parameter" "use_kubeconfig" {
  name         = "use_kubeconfig"
  display_name = "Use Local Kubeconfig"
  description  = "Use local kubeconfig file for Kubernetes cluster authentication"
  type         = "bool"
  default      = false
  mutable      = true
  icon         = "/icon/kubernetes.svg"
}

resource "coder_parameter" "namespace" {
  name         = "namespace"
  display_name = "Kubernetes Namespace"
  description  = "The namespace to create workspaces in (must exist prior to creating workspaces)"
  type         = "string"
  default      = "coder-workspaces"
  mutable      = true
  icon         = "/icon/namespace.svg"
}

resource "coder_parameter" "cpu" {
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

resource "coder_parameter" "memory" {
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

resource "coder_parameter" "disk_size" {
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

resource "coder_parameter" "docker_host" {
  name         = "docker_host"
  display_name = "Docker Host"
  description  = "Docker daemon address to connect to (e.g., 'unix:///var/run/docker.sock' or 'tcp://localhost:2375')"
  type         = "string"
  default      = "unix:///var/run/docker.sock"
  mutable      = true
  icon         = "/icon/docker.svg"
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
    echo "export DOCKER_HOST=${coder_parameter.docker_host.value}" >> ~/.bashrc

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
    namespace = coder_parameter.namespace.value
  }
  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = "${coder_parameter.disk_size.value}Gi"
      }
    }
  }
}

resource "kubernetes_pod" "main" {
  count = data.coder_workspace.me.start_count
  metadata {
    name      = "coder-${data.coder_workspace.me.owner}-${data.coder_workspace.me.name}"
    namespace = coder_parameter.namespace.value
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
        value = coder_parameter.docker_host.value
      }
      resources {
        requests = {
          cpu    = "${coder_parameter.cpu.value}"
          memory = "${coder_parameter.memory.value}Gi"
        }
        limits = {
          cpu    = "${coder_parameter.cpu.value}"
          memory = "${coder_parameter.memory.value}Gi"
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