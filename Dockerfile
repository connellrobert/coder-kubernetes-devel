FROM ubuntu:22.04

# Avoid prompts from apt
ENV DEBIAN_FRONTEND=noninteractive

# Install basic tools and dependencies
RUN apt-get update && apt-get install -y \
    curl \
    sudo \
    git \
    build-essential \
    wget \
    jq \
    vim \
    pkg-config \
    apt-transport-https \
    ca-certificates \
    software-properties-common \
    lsb-release \
    gnupg \
    rsync \
    python3 \
    python3-pip \
    && rm -rf /var/lib/apt/lists/*

# Install Python packages
RUN pip3 install --no-cache-dir PyYAML

# Install Go
RUN curl -Lo go.tar.gz https://go.dev/dl/go1.21.0.linux-amd64.tar.gz \
    && tar -C /usr/local -xzf go.tar.gz \
    && rm go.tar.gz

# Install Docker CLI
RUN curl -fsSL https://get.docker.com -o get-docker.sh \
    && sh ./get-docker.sh \
    && rm get-docker.sh

# Create coder user
RUN groupadd -g 1000 coder \
    && useradd -l -u 1000 -g coder -G root,docker -md /home/coder -s /bin/bash -p "" coder \
    && echo "coder ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/coder

# Install etcd (required for Kubernetes development)
RUN ETCD_VERSION=v3.5.9 && \
    curl -L https://github.com/etcd-io/etcd/releases/download/${ETCD_VERSION}/etcd-${ETCD_VERSION}-linux-amd64.tar.gz -o etcd.tar.gz && \
    tar xzvf etcd.tar.gz && \
    mv etcd-${ETCD_VERSION}-linux-amd64/etcd* /usr/local/bin/ && \
    rm -rf etcd-${ETCD_VERSION}-linux-amd64 etcd.tar.gz

# Set environment variables
ENV PATH="/usr/local/go/bin:${PATH}"
ENV GOPATH="/home/coder/go"
ENV PATH="${GOPATH}/bin:${PATH}"

USER coder
WORKDIR /home/coder 