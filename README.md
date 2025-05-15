# Kubernetes Development Template

This template creates a development environment for contributing to Kubernetes using Coder. It provides all the necessary tools and configurations to start developing Kubernetes core components.

## Prerequisites

- A Kubernetes cluster with Coder installed
- `kubectl` configured to access your cluster
- Sufficient cluster resources (minimum recommended: 4 CPU cores, 8GB RAM, 50GB storage)
- Access to a Docker daemon (either local or remote)

## Features

### Development Tools
- Go 1.21.0
- Git
- Docker CLI
- Build essentials (gcc, make, etc.)
- vim editor
- etcd v3.5.9
- Python 3 with PyYAML
- Network tools (ifconfig, netstat, etc.)
- rsync for file synchronization

### Environment Configuration
- Timezone configuration with tzdata
- Proper user/group setup (UID 1000, root group access)
- Persistent workspace storage
- Configurable Docker daemon connection
- GOPATH configured at /home/coder
- Kubernetes repository cloned directly in home directory

## Template Parameters

- `cpu`: Number of CPU cores (default: 4)
- `memory`: Memory in GB (default: 8)
- `disk_size`: Disk size in GB (default: 50)
- `namespace`: Kubernetes namespace for the workspace (default: coder-workspaces)
- `docker_host`: Docker daemon address to connect to (default: "unix:///var/run/docker.sock")
- `container_image`: Container image to use (default: "ghcr.io/<owner>/kubernetes-coder-dev:latest")
- `kubernetes_repo`: Git repository URL for Kubernetes (default: "https://github.com/kubernetes/kubernetes.git")
- `kubernetes_branch`: Git branch to clone (default: "master")

## Usage

1. Create a new workspace using this template
2. Configure the parameters as needed
3. Wait for the initialization script to complete
4. Connect to your workspace
5. The Kubernetes source code will be available at `$HOME/kubernetes`

## Development Workflow

1. Make your changes in the Kubernetes repository
2. Build Kubernetes using `make`
3. Run tests using `make test`
4. Submit your changes following the [Kubernetes contribution guidelines](https://github.com/kubernetes/community/blob/master/contributors/guide/README.md)

## Docker Configuration

The template supports connecting to a Docker daemon in different ways:
1. Local socket (default): `unix:///var/run/docker.sock`
2. TCP connection: `tcp://host:port` (e.g., `tcp://localhost:2375`)
3. Remote Docker host: Set the `docker_host` parameter to point to your Docker daemon

## Container Image

The development container includes:
- Ubuntu 22.04 base image
- All necessary development tools pre-installed
- Proper timezone configuration
- Network utilities
- Python with YAML support
- Development user setup with sudo access

The container image is automatically built and published to GitHub Container Registry with version tags.

## Customization

You can customize this template by:
1. Modifying the parameters when creating a workspace
2. Using your own fork of Kubernetes
3. Switching between different branches
4. Using a different container image version

## Troubleshooting

If you encounter any issues:
1. Check the workspace logs for startup script output
2. Ensure your cluster has sufficient resources
3. Verify network connectivity to GitHub and other required services
4. Check Docker daemon connectivity using `docker info`
5. Verify the container image is accessible
6. Check that all required ports are accessible
7. Ensure proper permissions for Docker socket if using local socket 