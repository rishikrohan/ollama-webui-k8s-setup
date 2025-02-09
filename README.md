# Ollama LLM System Setup

This repository contains the necessary scripts and Helm charts to set up the Ollama LLM system on a Kubernetes cluster using KIND (Kubernetes IN Docker).

## Prerequisites

### Install Homebrew

```sh
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

### Install KIND

```sh
brew install kind
```

### Install kubectl

```sh
brew install kubectl
```

### Install Helm

```sh
brew install helm
```

### Install ngrok

```sh
brew install ngrok
```



## Setup Instructions

### Step 1: Create KIND Cluster

```sh
kind create cluster --config cluster/kind-config.yaml
```

### Step 2: Add Helm Repositories

```sh
helm repo add open-webui https://open-webui.github.io/helm-charts
helm repo update
```
