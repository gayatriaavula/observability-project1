github_repo = "gayatriaavula/observability-project1"

# Restrict the public EKS API endpoint to the current operator's IP instead
# of 0.0.0.0/0 (Trivy AWS-0041). Update this if your public IP changes.
cluster_endpoint_public_access_cidrs = ["174.163.160.69/32"]
