# orders-backend on EKS, Istio, and Argo CD

This repo contains everything needed to stand up the architecture we designed:
a Node.js orders API, running behind an Istio ingress gateway on Amazon EKS,
deployed continuously via GitHub Actions + Argo CD, and observed with
Prometheus/Grafana/Alertmanager.

```
app/                  orders-backend source, tests, Dockerfile
infra/terraform/      VPC + EKS + ECR + GitHub OIDC role (Terraform)
infra/bootstrap/      one-time shell scripts: install Istio, install Argo CD
k8s/base/             Deployment, Service, HPA, PDB, Gateway, VirtualService, mTLS
k8s/monitoring/       ServiceMonitor + PrometheusRule for orders-backend
.github/workflows/    CI: test -> build -> push to ECR -> update manifest
```

Argo CD's own Application manifests (the "app of apps" root + the three
Applications it manages) live in a separate repo,
[observability-project1-gitops](https://github.com/gayatriaavula/observability-project1-gitops),
not here. Those Applications still point their `repoURL`/`path` back at this
repo's `k8s/base` and `k8s/monitoring` — only the Argo CD registration layer
is split out.

## What you need before starting

- An AWS account and credentials with permission to create VPCs, EKS, ECR, IAM
- Terraform >= 1.5, `kubectl`, `helm`, `aws` CLI, `argocd` CLI (optional)
- A GitHub repo this code is pushed to (Argo CD and CI both pull from git)

## 1. Provision the cluster

```bash
cd infra/terraform
terraform init
terraform apply -var="github_repo=YOUR_ORG/YOUR_REPO"
```

This creates the VPC, an EKS cluster, an ECR repository, and an IAM role that
GitHub Actions can assume via OIDC (no AWS keys stored as secrets). Note the
outputs — you'll need `github_actions_role_arn` and `ecr_repository_url` next.

```bash
aws eks update-kubeconfig --region us-east-1 --name orders-eks
```

## 2. Install Istio and Argo CD onto the cluster

```bash
./infra/bootstrap/install-istio.sh
./infra/bootstrap/install-argocd.sh
```

The Istio script installs istiod into `istio-system`, a dedicated ingress
gateway into `istio-ingress`, and labels `orders-backend` for sidecar
injection. The Argo CD script installs Argo CD into `argocd` and prints the
initial admin password.

You'll also need a TLS cert for `api.company.com` as a Kubernetes Secret named
`api-company-com-tls` in the `istio-ingress` namespace (via cert-manager, ACM,
or `kubectl create secret tls`) before the Gateway can serve HTTPS.

## 3. Wire up GitHub

This repo is wired to https://github.com/gayatriaavula/observability-project1 —
the Argo CD Application manifests (in the separate
[observability-project1-gitops](https://github.com/gayatriaavula/observability-project1-gitops)
repo) already point `repoURL` here for `k8s/base` and `k8s/monitoring`.

In your GitHub repo settings:
- **Settings → Secrets and variables → Actions → Variables**: add `AWS_ROLE_ARN`
  with the `github_actions_role_arn` Terraform output.
- Replace the `orders-backend:latest` image name in `k8s/base/kustomization.yaml`
  with your `ecr_repository_url` output (or leave it — CI overwrites it on
  every push anyway).

Push this repo to `github.com/gayatriaavula/observability-project1`.

## 4. Register the apps with Argo CD

`root-app.yaml` and the three Application manifests live in
[observability-project1-gitops](https://github.com/gayatriaavula/observability-project1-gitops),
not this repo. Clone that repo and apply its root Application once:

```bash
git clone https://github.com/gayatriaavula/observability-project1-gitops.git
kubectl apply -f observability-project1-gitops/root-app.yaml
```

This one command (the "app of apps" pattern) makes Argo CD discover and
create the three real Applications — `orders-backend`, `kube-prometheus-stack`,
and `orders-backend-monitoring`, defined in that repo's `applications/`
directory — and sync them automatically with `prune: true` / `selfHeal: true`,
meaning git is the single source of truth: any manual `kubectl edit` against
the cluster gets reverted back to what's committed.

## 5. Ship a change

Edit anything under `app/`, push to `main`. From there:

```
push to main
   -> GitHub Actions: npm test
   -> docker build, push to ECR (tagged with the commit SHA)
   -> kustomize edit set image, commit the new tag back to k8s/base
   -> Argo CD notices the git change and syncs it to the cluster
   -> Deployment does a rolling update across the 3-10 orders-backend pods
```

You never run `kubectl apply` by hand for application changes — git is the
trigger, Argo CD is the only thing that talks to the cluster.

## Where the pieces map back to the architecture

| Diagram component | Where it lives here |
|---|---|
| AWS Load Balancer | Provisioned automatically from the `istio-ingressgateway` Service (type LoadBalancer) |
| Gateway Pod 1/2 | `istio-ingressgateway` Helm release in `istio-ingress` (2 replicas by chart default) |
| istiod | `istiod` Helm release in `istio-system` |
| Gateway Configuration / VirtualService | `k8s/base/gateway.yaml`, `k8s/base/virtualservice.yaml` |
| orders-backend Deployment, HPA, PDB | `k8s/base/deployment.yaml`, `hpa.yaml`, `pdb.yaml` |
| mTLS between pods | `k8s/base/peerauthentication.yaml` (STRICT) + `destinationrule.yaml` (ISTIO_MUTUAL) |
| Prometheus / Grafana / Alertmanager | `applications/kube-prometheus-stack.yaml` in observability-project1-gitops (Helm chart) |
| Metrics scraping | `k8s/monitoring/servicemonitor-orders-backend.yaml` |
| Alerts → Slack | `k8s/monitoring/kube-prometheus-stack-values.yaml` (Alertmanager Slack receiver) |

## What this does not do for you

- It does not run `terraform apply` or touch your AWS account — you run that.
- It does not create the `api-company-com-tls` certificate or the Slack
  webhook secret — both need real values only you should hold.
- `k8s/base/secret.yaml` ships a placeholder value; swap it for External
  Secrets Operator or Sealed Secrets before this touches anything real.
