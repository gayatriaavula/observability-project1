github_repo = "gayatriaavula/observability-project1"

# This AWS account already has a token.actions.githubusercontent.com OIDC
# provider (created by an unrelated pre-existing project in this account,
# not by this repo) -- IAM only allows one per account, so reuse it instead
# of trying to create a duplicate.
create_github_oidc_provider = false

# One node (t3.medium, 17-pod cap) isn't enough room for istiod + ingress
# gateway + Argo CD + kube-prometheus-stack + app pods all at once -- bump to
# the existing max_size of 2 so Prometheus/Alertmanager can schedule.
node_desired_size = 2

# Restrict the public EKS API endpoint to the current operator's IP instead
# of 0.0.0.0/0 (Trivy AWS-0041). Update this if your public IP changes.
cluster_endpoint_public_access_cidrs = ["98.252.212.24/32"]
