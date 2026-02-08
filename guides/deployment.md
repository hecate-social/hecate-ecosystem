# Deployment Guide

This guide covers deploying Hecate to Kubernetes clusters using GitOps.

## Overview

Hecate uses Flux for GitOps-based deployments:

1. Code changes pushed to GitHub trigger CI/CD
2. CI builds and pushes Docker images to ghcr.io
3. Update manifests in hecate-gitops repository
4. Flux reconciles the cluster to match the manifests

## Prerequisites

- Kubernetes cluster (k3s, k8s, or KinD)
- Flux installed on the cluster
- Access to hecate-gitops repository
- kubectl configured for your cluster

## Repository Structure

```
hecate-gitops/
├── infrastructure/
│   └── hecate/
│       ├── namespace.yaml
│       ├── configmap.yaml
│       ├── sealed-secret.yaml
│       └── daemonset.yaml
└── clusters/
    └── beam-cluster/
        └── hecate-kustomization.yaml
```

## Deployment Model

Hecate daemon runs as a **DaemonSet**, deploying one pod per node:

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: hecate-daemon
  namespace: hecate
spec:
  selector:
    matchLabels:
      app: hecate-daemon
  template:
    spec:
      hostNetwork: true
      containers:
        - name: daemon
          image: ghcr.io/hecate-social/hecate-daemon:0.7.2
          volumeMounts:
            - name: socket-dir
              mountPath: /run/hecate
      volumes:
        - name: socket-dir
          hostPath:
            path: /run/hecate
```

Key points:
- `hostNetwork: true` - Binds to host network for Ollama access
- Socket at `/run/hecate/daemon.sock` on the host
- Each node gets its own daemon instance

## Step-by-Step Deployment

### 1. Create Namespace

```yaml
# infrastructure/hecate/namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: hecate
```

### 2. Create ConfigMap

```yaml
# infrastructure/hecate/configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: hecate-config
  namespace: hecate
data:
  OLLAMA_HOST: "http://localhost:11434"
  HECATE_LOG_LEVEL: "info"
```

### 3. Create Sealed Secret (for API keys)

First, create the secret locally:

```bash
kubectl create secret generic hecate-secrets \
  --namespace hecate \
  --from-literal=OPENAI_API_KEY=sk-... \
  --from-literal=ANTHROPIC_API_KEY=sk-ant-... \
  --dry-run=client -o yaml > /tmp/hecate-secrets.yaml
```

Then seal it using kubeseal:

```bash
kubeseal --format yaml < /tmp/hecate-secrets.yaml > infrastructure/hecate/sealed-secret.yaml
rm /tmp/hecate-secrets.yaml
```

### 4. Create DaemonSet

```yaml
# infrastructure/hecate/daemonset.yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: hecate-daemon
  namespace: hecate
  labels:
    app.kubernetes.io/name: hecate-daemon
spec:
  selector:
    matchLabels:
      app: hecate-daemon
  template:
    metadata:
      labels:
        app: hecate-daemon
    spec:
      hostNetwork: true
      dnsPolicy: ClusterFirstWithHostNet

      volumes:
        - name: socket-dir
          hostPath:
            path: /run/hecate
            type: DirectoryOrCreate
        - name: data-dir
          hostPath:
            path: /var/lib/hecate
            type: DirectoryOrCreate

      containers:
        - name: daemon
          image: ghcr.io/hecate-social/hecate-daemon:0.7.2
          imagePullPolicy: Always

          envFrom:
            - configMapRef:
                name: hecate-config
            - secretRef:
                name: hecate-secrets
                optional: true

          volumeMounts:
            - name: socket-dir
              mountPath: /run/hecate
            - name: data-dir
              mountPath: /var/lib/hecate

          livenessProbe:
            exec:
              command: ["test", "-S", "/run/hecate/daemon.sock"]
            initialDelaySeconds: 10
            periodSeconds: 30

          readinessProbe:
            exec:
              command: ["test", "-S", "/run/hecate/daemon.sock"]
            initialDelaySeconds: 5
            periodSeconds: 10

          resources:
            requests:
              memory: "256Mi"
              cpu: "100m"
            limits:
              memory: "1Gi"
              cpu: "1000m"
```

### 5. Create Kustomization

```yaml
# clusters/beam-cluster/hecate-kustomization.yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: hecate
  namespace: flux-system
spec:
  interval: 5m
  path: ./infrastructure/hecate
  prune: true
  sourceRef:
    kind: GitRepository
    name: hecate-gitops
  targetNamespace: hecate
```

### 6. Commit and Push

```bash
cd hecate-gitops
git add -A
git commit -m "deploy: Add hecate daemon v0.7.2"
git push
```

### 7. Verify Deployment

```bash
# Check Flux reconciliation
flux get kustomizations

# Check pods
kubectl get pods -n hecate -o wide

# Check daemon status
kubectl exec -n hecate hecate-daemon-xxxxx -- \
  curl -s --unix-socket /run/hecate/daemon.sock http://localhost/api/health
```

## Updating the Daemon

### 1. Push Code Changes

```bash
cd hecate-daemon
# Make changes
git add -A
git commit -m "feat: Add new feature"
git push
```

### 2. Tag a Release

```bash
git tag v0.7.3
git push origin v0.7.3
```

CI/CD will build and push `ghcr.io/hecate-social/hecate-daemon:0.7.3`.

### 3. Update GitOps Manifest

```bash
cd hecate-gitops
# Edit daemonset.yaml to use new version
sed -i 's/hecate-daemon:0.7.2/hecate-daemon:0.7.3/' infrastructure/hecate/daemonset.yaml
git add -A
git commit -m "deploy: Update hecate-daemon to v0.7.3"
git push
```

### 4. Flux Reconciles

Flux will automatically detect the change and update the cluster.

```bash
# Watch rollout
kubectl rollout status daemonset/hecate-daemon -n hecate

# Verify new version
kubectl get pods -n hecate -o jsonpath='{.items[0].spec.containers[0].image}'
```

## Rolling Back

### Via GitOps (Recommended)

Revert the manifest change:

```bash
cd hecate-gitops
git revert HEAD
git push
```

### Manual (Emergency)

```bash
kubectl rollout undo daemonset/hecate-daemon -n hecate
```

**Note:** Manual changes will be overwritten by Flux on next reconciliation.

## Monitoring

### Pod Status

```bash
kubectl get pods -n hecate -o wide
```

### Logs

```bash
# All pods
kubectl logs -n hecate -l app=hecate-daemon

# Specific pod
kubectl logs -n hecate hecate-daemon-xxxxx -f
```

### Health Checks

```bash
# From inside cluster
kubectl exec -n hecate hecate-daemon-xxxxx -- \
  curl -s --unix-socket /run/hecate/daemon.sock http://localhost/api/health

# From node (SSH)
ssh beam00.lab "curl -s --unix-socket /run/hecate/daemon.sock http://localhost/api/health"
```

## Troubleshooting

### Pods Not Starting

Check events:

```bash
kubectl describe pod -n hecate hecate-daemon-xxxxx
```

Common issues:
- Image pull errors - Check ghcr.io access
- Volume mount errors - Check hostPath permissions
- Resource limits - Increase if OOM killed

### Socket Not Created

Check daemon logs:

```bash
kubectl logs -n hecate hecate-daemon-xxxxx
```

Verify the socket directory exists on the host:

```bash
ssh node "ls -la /run/hecate/"
```

### Flux Not Reconciling

Check Flux status:

```bash
flux get sources git
flux get kustomizations
flux logs --follow
```

Force reconciliation:

```bash
flux reconcile kustomization hecate --with-source
```

## Multi-Cluster Deployment

For multiple clusters, create separate directories:

```
hecate-gitops/
├── infrastructure/
│   └── hecate/
│       └── ... (shared manifests)
└── clusters/
    ├── beam-cluster/
    │   └── hecate-kustomization.yaml
    ├── edge-cluster/
    │   └── hecate-kustomization.yaml
    └── dev-cluster/
        └── hecate-kustomization.yaml
```

Each cluster's kustomization can reference the shared infrastructure with cluster-specific patches.
