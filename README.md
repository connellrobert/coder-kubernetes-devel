# Kubernetes Development Template

This template creates a development environment for contributing to Kubernetes using Coder. It provides all the necessary tools and configurations to start developing Kubernetes core components.

## Prerequisites

- A Kubernetes cluster with Coder installed
- `kubectl` configured to access your cluster
- Sufficient cluster resources (minimum recommended: 4 CPU cores, 8GB RAM, 50GB storage)

## Features

- Pre-installed development tools:
  - Go 1.21.0
  - Git
  - Docker
  - Build essentials (gcc, make, etc.)
  - vim editor
  - kubectl with shell completion
  - etcd

- Automatic setup:
  - Clones the Kubernetes repository
  - Configures Go workspace
  - Sets up development environment
  - Builds Kubernetes from source

## Usage

1. Create a new workspace using this template
2. Wait for the initialization script to complete (this may take several minutes)
3. Connect to your workspace
4. The Kubernetes source code will be available at `$HOME/go/src/k8s.io/kubernetes`

## Development Workflow

1. Make your changes in the Kubernetes repository
2. Build Kubernetes using `make`
3. Run tests using `make test`
4. Submit your changes following the [Kubernetes contribution guidelines](https://github.com/kubernetes/community/blob/master/contributors/guide/README.md)

## Template Parameters

- `cpu`: Number of CPU cores (default: 4)
- `memory`: Memory in GB (default: 8)
- `disk_size`: Disk size in GB (default: 50)
- `namespace`: Kubernetes namespace for the workspace (default: coder-workspaces)
- `use_kubeconfig`: Whether to use local kubeconfig for authentication (default: false)

## Customization

You can customize this template by:
1. Modifying the `startup_script` in `main.tf`
2. Adjusting resource allocations through template parameters
3. Adding additional tools or configurations as needed

## Troubleshooting

If you encounter any issues:
1. Check the workspace logs for startup script output
2. Ensure your cluster has sufficient resources
3. Verify network connectivity to GitHub and other required services
4. Check that all required ports are accessible 