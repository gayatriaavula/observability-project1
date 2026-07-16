# orders-backend on EKS, Istio, and Argo CD

This repo contains everything needed to stand up the architecture we designed:
a Node.js orders API, running behind an Istio ingress gateway on Amazon EKS,
deployed continuously via GitHub Actions + Argo CD, and observed with
Prometheus/Grafana/Alertmanager.

```
app/                  orders-backend source, tests, Dockerfile
infra/terraform/      VPC + EKS + ECR + GitHub OIDC role (Terraform)
infra/bootstrap/      one-time shell script: install Istio (Argo CD is installed by Terraform)
.github/workflows/    CI: test -> build -> push to ECR -> update manifest (in the gitops repo)
```

This repo only ever holds application source code — no Kubernetes manifests
and no Argo CD registration live here. Both live in a separate repo,
[observability-project1-gitops](https://github.com/gayatriaavula/observability-project1-gitops):

```
k8s/base/             Deployment, Service, HPA, PDB, Gateway, VirtualService, mTLS
k8s/monitoring/       ServiceMonitor + PrometheusRule for orders-backend
root-app.yaml         app-of-apps root Application
applications/         the three Applications Argo CD manages
```

CI here pushes image-tag-bump commits into that repo's `k8s/base`; Argo CD is
the only thing that ever talks to the cluster (`kubectl apply` by hand is
only for the one-time `root-app.yaml` registration below).

## What you need before starting

- An AWS account and credentials with permission to create VPCs, EKS, ECR, IAM
- Terraform >= 1.5, `kubectl`, `helm`, `aws` CLI, `argocd` CLI (optional)
- A GitHub repo this code is pushed to (Argo CD and CI both pull from git)

## 1. Provision the cluster (and Argo CD)

```bash
cd infra/terraform/environments/dev   # or environments/prod
terraform init
terraform apply -var="github_repo=YOUR_ORG/YOUR_REPO"
```

This creates the VPC, EKS cluster, ECR repository, IAM roles for GitHub
Actions OIDC — and, as soon as the cluster is up, installs Argo CD into the
`argocd` namespace via `module.argocd` (the upstream Helm chart), all in this
one apply. No separate install step or manual kubeconfig dance in between.
Note the outputs — you'll need `github_actions_role_arn` and
`ecr_repository_url` next, and `argocd_initial_admin_password_command` to log
into the Argo CD UI.

```bash
aws eks update-kubeconfig --region us-east-1 --name $(terraform output -raw cluster_name)
```

## 2. Install Istio onto the cluster

```bash
./infra/bootstrap/install-istio.sh
```

This installs istiod into `istio-system`, a dedicated ingress gateway into
`istio-ingress`, and labels `orders-backend` for sidecar injection.

You'll also need a TLS cert for `api.company.com` as a Kubernetes Secret named
`api-company-com-tls` in the `istio-ingress` namespace (via cert-manager, ACM,
or `kubectl create secret tls`) before the Gateway can serve HTTPS.

## 3. Wire up GitHub

This repo is wired to https://github.com/gayatriaavula/observability-project1;
manifests live in the separate
[observability-project1-gitops](https://github.com/gayatriaavula/observability-project1-gitops)
repo, and CI here needs write access to push into it.

In this repo's GitHub settings:
- **Settings → Secrets and variables → Actions → Variables**: add `AWS_ROLE_ARN`
  with the `github_actions_role_arn` Terraform output.
- **Settings → Secrets and variables → Actions → Secrets**: add `GITOPS_PAT`, a
  fine-grained Personal Access Token restricted to the
  `observability-project1-gitops` repo with read/write access to Contents.
  `.github/workflows/ci-cd.yml`'s `update-manifest` job uses this to check out
  and push to that repo — `GITHUB_TOKEN` can't write across repos.
- Replace the `orders-backend:latest` image name in
  `observability-project1-gitops/k8s/base/kustomization.yaml` with your
  `ecr_repository_url` output (or leave it — CI overwrites it on every push
  anyway).

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
push to main (observability-project1)
   -> GitHub Actions: npm test
   -> docker build, push to ECR (tagged with the commit SHA)
   -> checkout observability-project1-gitops (via GITOPS_PAT)
   -> kustomize edit set image, commit + push the new tag to its k8s/base
   -> Argo CD (watching that repo) notices the change and syncs it to the cluster
   -> Deployment does a rolling update across the 3-10 orders-backend pods
```

You never run `kubectl apply` by hand for application changes — git is the
trigger, Argo CD is the only thing that talks to the cluster.

## Where the pieces map back to the architecture

All `k8s/` paths below live in observability-project1-gitops, not this repo.

| Diagram component | Where it lives |
|---|---|
| AWS Load Balancer | Provisioned automatically from the `istio-ingressgateway` Service (type LoadBalancer) |
| Gateway Pod 1/2 | `istio-ingressgateway` Helm release in `istio-ingress` (2 replicas by chart default) |
| istiod | `istiod` Helm release in `istio-system` |
| Gateway Configuration / VirtualService | `k8s/base/gateway.yaml`, `k8s/base/virtualservice.yaml` |
| orders-backend Deployment, HPA, PDB | `k8s/base/deployment.yaml`, `hpa.yaml`, `pdb.yaml` |
| mTLS between pods | `k8s/base/peerauthentication.yaml` (STRICT) + `destinationrule.yaml` (ISTIO_MUTUAL) |
| Prometheus / Grafana / Alertmanager | `applications/kube-prometheus-stack.yaml` (Helm chart) |
| Metrics scraping | `k8s/monitoring/servicemonitor-orders-backend.yaml` |
| Alerts → Slack | `k8s/monitoring/kube-prometheus-stack-values.yaml` (Alertmanager Slack receiver) |

## What this does not do for you

- It does not run `terraform apply` or touch your AWS account — you run that.
- It does not create the `api-company-com-tls` certificate or the Slack
  webhook secret — both need real values only you should hold.
- `k8s/base/secret.yaml` (in observability-project1-gitops) ships a
  placeholder value; swap it for External Secrets Operator or Sealed Secrets
  before this touches anything real.
