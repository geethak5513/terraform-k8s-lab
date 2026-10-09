# Recreate Zen Pharma in a new AWS account using the same GitHub repositories

Reviewed 9 October 2026 against downloaded public repository branches: terraform-k8s-lab/main, zen-gitops/main, zen-pharma-backend/develop, zen-pharma-frontend/develop. This is a fresh deployment checklist, not a database migration or changes already applied. Repository secrets and live AWS/Kubernetes configuration are not visible through public source code.

## 1. Record the target configuration

Replace NEW_ACCOUNT_ID below with the new 12-digit account ID. Keep us-east-1, pharma-dev-eks, pharma-dev-postgres, the current repository names, and current IAM role names for the simplest rebuild.

| Item | Target |
|---|---|
| AWS account | NEW_ACCOUNT_ID |
| Region | us-east-1 |
| Terraform state bucket | zen-pharma-tfstate-NEW_ACCOUNT_ID-us-east-1 (must be globally available) |
| Terraform state key | envs/dev/terraform.tfstate |
| Terraform workflow role | terraform-github-actions |
| Backend workflow role | pharma-backend-github-actions |
| Frontend workflow role | pharma-dev-github-actions-role |
| GitHub owner | geethak5513 |
| GitHub owner ID | 41056499 |
| Backend repository ID | 1389434853 |
| Frontend repository ID | 1411328384 |
| GitOps repository variable | geethak5513/zen-gitops |

The GitHub identities do not change when only the AWS account changes. Do not clone the trainer repositories again.

This checklist assumes you switch DEV to the new account. Editing the existing DEV values affects any old cluster still watching GitOps main. Pause its reconciliation or stop using it before committing the switch. To keep both accounts independently active, first add a separate environment and adjust CI write paths and Argo CD source paths/revisions for it. Updating shared repository secrets also redirects future builds to the new account.

## 2. Capture the setup that is outside these repositories

Before destroying the current cluster, use its current credentials/context to record these non-secret configurations:

```bash
aws iam get-role --role-name terraform-github-actions
aws iam list-attached-role-policies --role-name terraform-github-actions
aws iam list-role-policies --role-name terraform-github-actions
kubectl get clustersecretstore aws-secrets-manager -o yaml
kubectl get externalsecret -A
kubectl get serviceaccount external-secrets -n external-secrets -o yaml
helm list -A
helm get values external-secrets -n external-secrets
helm get values ingress-nginx -n ingress-nginx
kubectl get ingressclass
aws eks list-access-entries --region us-east-1 --cluster-name pharma-dev-eks
```

If Helm release names differ, use the names returned by `helm list -A`. Save the installed chart versions too. Retrieve the Terraform role's inline policies with `aws iam get-role-policy`; retrieve customer-managed policy versions with `aws iam get-policy` and `aws iam get-policy-version`. List-attached-role-policies alone does not capture permissions.

For each ExternalSecret, record its manifest and its Secrets Manager path/property mapping. Do not export Kubernetes Secret values into Git. When preparing captured YAML for replay, remove status, uid, resourceVersion, managedFields, creationTimestamp, and generated annotations; replace old role ARNs/endpoints.

The public GitOps repository currently does not contain the ClusterSecretStore, ESO installation values, or the DB/JWT ExternalSecret manifests. Their exact existing secret paths cannot be inferred from the values files. Capture these now; recreate them as documented bootstrap manifests, preferably under a new `zen-gitops/k8s/secrets/` folder. That folder is a proposed addition, not an existing deployed source.

## 3. Bootstrap the new AWS account

Use a separate local AWS CLI profile for the new account and verify before running changes:

```bash
export AWS_PROFILE=pharma-new
aws sts get-caller-identity
```

Authentication setup depends on whether you use SSO or another credential mechanism; never place AWS credentials in source code.

Create the new S3 state bucket with encryption, versioning, and public access blocked. The current backend uses S3 lockfiles, not DynamoDB. Give the Terraform role access to the bucket and `envs/dev/*`, including the lockfile, plus the required infrastructure provisioning permissions from the captured role policies.

Create the GitHub OIDC provider (`https://token.actions.githubusercontent.com`, audience `sts.amazonaws.com`) and bootstrap role `terraform-github-actions`. Terraform cannot use a role that it has not yet created. Its trust must reference the NEW account's OIDC provider and the Terraform repository. Capture that repository's numeric ID if immutable subjects are used; the backend/frontend IDs are not the Terraform repository ID.

The workflow's plan job does not use a GitHub environment, but its apply job uses `terraform-apply`. Account for BOTH the branch subject for the plan and the environment subject for apply, in the actual GitHub subject format. Legacy examples are `repo:geethak5513/terraform-k8s-lab:ref:refs/heads/main` and `repo:geethak5513/terraform-k8s-lab:environment:terraform-apply`. If immutable subjects are emitted, use the corresponding owner/repository IDs. Keep subject restrictions and the audience check.

IMPORTANT: Terraform also declares this GitHub OIDC provider in `modules/iam/github-actions-oidc.tf`. If bootstrap created it, import it into the NEW state before the full apply rather than attempting to create a duplicate. With new-account credentials, correct new backend, and the DB password supplied securely:

```bash
cd ~/terraform-k8s-lab/envs/dev
terraform init -reconfigure
terraform import module.iam.aws_iam_openid_connect_provider.github_actions \
  arn:aws:iam::NEW_ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com
```

The checkout folder can have another name; use the real local Terraform folder. Do not use `terraform init -migrate-state` for this fresh deployment. Do not copy the old .terraform directory or terraform.tfstate into the new account.

## 4. Terraform repository edits

Repository: https://github.com/geethak5513/terraform-k8s-lab ; branch main.

| Exact file | Action |
|---|---|
| `.github/workflows/terraform.yml` | Replace BOTH `arn:aws:iam::760396521684:role/terraform-github-actions` entries, in plan and apply, with the new account ARN. |
| `envs/dev/backend.tf` | Replace bucket with the new bucket. Keep key `envs/dev/terraform.tfstate`, region us-east-1, encryption and use_lockfile. |
| `bootstrap/terraform-state-policy.json` | Replace BOTH bucket references: bucket ARN and object-prefix ARN. Apply the edited policy to the new Terraform role. Editing the JSON alone does not attach it. |
| `envs/dev/variables.tf` | Keep github_org geethak5513, github_org_id 41056499, backend ID 1389434853, frontend ID 1411328384. No account-ID replacement here. |
| `envs/dev/main.tf` | No account-ID edit: module IAM receives account ID from aws_caller_identity. Keep project/env if retaining resource names. |
| `modules/iam/main.tf` | No blanket ARN replacement: account-specific ARNs and EKS OIDC trust are generated from variables. AWS-managed policy ARN has no account number and stays unchanged. |
| `modules/iam/github-actions-oidc.tf` | GitHub identities stay unchanged; import an already-bootstrapped provider as above. Creates the frontend CI role, not the backend CI role. |
| `modules/eks/main.tf` | Current capacity is 4 × t3.small, min/max/desired all 4. No change for same lab sizing; verify target account allows the instance types and has quota. |

GitHub → terraform-k8s-lab → Settings → Secrets and variables → Actions: set repository secret `TF_VAR_db_password` to the NEW database password. Also inspect Settings → Environments → terraform-apply for any overriding secrets and required reviewers. Retain that environment for the workflow.

Commit, inspect Terraform plan, then run the infrastructure workflow. New state should produce creation of new resources; unexpected management of old resources means credentials/backend need investigation.

Terraform creates nine ECR repositories: api-gateway, auth-service, drug-catalog-service, inventory-service, manufacturing-service, notification-service, pharma-ui, supplier-service, qc-service. It creates EKS/RDS/network/IAM resources, but it does not install Argo CD, ESO, or ingress-nginx.

## 5. Backend repository edits and IAM bootstrap

Repository: https://github.com/geethak5513/zen-pharma-backend ; build branch develop.

| Exact file/settings | Action |
|---|---|
| `bootstrap/pharma-backend-trust-policy.json` | Replace account ID in Federated OIDC provider ARN. Keep current backend develop and release/* GitHub subjects. |
| `bootstrap/pharma-backend-ecr-policy.json` | Replace account ID in all EIGHT repository ARNs. Keep us-east-1 and repository names. |
| `.github/workflows/_java-build.yml` | Role ARN already uses secrets.AWS_ACCOUNT_ID; no hardcoded account edit. Keep role name pharma-backend-github-actions. |
| `.github/workflows/_node-build.yml` | Same account-secret behavior and backend role name. |
| Settings → Secrets and variables → Actions → Secrets | Update AWS_ACCOUNT_ID to NEW_ACCOUNT_ID. Keep a valid GITOPS_TOKEN with access to your GitOps repository. |
| Same settings → Variables | Keep GITOPS_REPO = geethak5513/zen-gitops. |

The backend role is not created by your current Terraform. After Terraform creates the GitHub provider/ECR, create it in the new account using the edited bootstrap policies:

```bash
cd ~/zen-pharma-backend-trainer
git switch develop
git pull --ff-only
aws iam create-role --role-name pharma-backend-github-actions \
  --assume-role-policy-document file://bootstrap/pharma-backend-trust-policy.json
aws iam put-role-policy --role-name pharma-backend-github-actions \
  --policy-name pharma-backend-ecr \
  --policy-document file://bootstrap/pharma-backend-ecr-policy.json
```

These commands are for a fresh role; if it already exists, update its trust/policy instead. Commit the policy edits to develop; preserve them on main through your normal merge process if main is retained as a rebuild source.

Run the eight build workflows on develop: `ci-auth-service.yml`, `ci-drug-catalog.yml`, `ci-inventory-service.yml`, `ci-supplier-service.yml`, `ci-manufacturing-service.yml`, `ci-notification.yml`, `ci-qc-service.yml`, `ci-api-gateway.yml`. Their ECR names remain unchanged. Rebuilding populates the new ECR; old account images are not copied by Terraform.

Check repository/environment secret overrides. GITOPS_TOKEN is a GitHub token, not an AWS credential. NVD_API_KEY, if configured, is unrelated to the AWS account; current relevant scanning steps are disabled.

## 6. Frontend repository settings

Repository: https://github.com/geethak5513/zen-pharma-frontend ; build branch develop.

| Exact file/settings | Action |
|---|---|
| `.github/workflows/_node-build.yml` | Already constructs role ARN from secrets.AWS_ACCOUNT_ID; role name stays pharma-dev-github-actions-role. Terraform creates this role. |
| `.github/workflows/ci-pharma-ui.yml` | Keep ecr-repository pharma-ui, aws-region us-east-1, and GitOps DEV file path. |
| Settings → Secrets and variables → Actions → Secrets | Update AWS_ACCOUNT_ID to NEW_ACCOUNT_ID. Keep valid GITOPS_TOKEN. |
| Same settings → Variables | Keep GITOPS_REPO = geethak5513/zen-gitops. |
| `.env.production` | Keep REACT_APP_API_URL=/api. It has no AWS account ID. |
| `nginx.conf` | Keep proxy_pass http://api-gateway:8080. This is Kubernetes Service DNS, not the old account address. |
| `Dockerfile` | No account edit; keep non-root Nginx, port 8080, and current build configuration. |

Run ci-pharma-ui.yml on develop after setting the secret. Verify the ECR push and DEV GitOps update jobs, not just tests/build. QA PR automation may run too; that does not mean QA has been deployed.

## 7. GitOps: all active DEV image locations

Repository: https://github.com/geethak5513/zen-gitops ; branch main.

Change image.repository in EVERY file below to NEW_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/REPOSITORY:

| File | ECR repository |
|---|---|
| `envs/dev/values-auth-service.yaml` | auth-service |
| `envs/dev/values-catalog-service.yaml` | drug-catalog-service |
| `envs/dev/values-inventory-service.yaml` | inventory-service |
| `envs/dev/values-supplier-service.yaml` | supplier-service |
| `envs/dev/values-manufacturing-service.yaml` | manufacturing-service |
| `envs/dev/values-notification-service.yaml` | notification-service |
| `envs/dev/values-qc-service.yaml` | qc-service |
| `envs/dev/values-api-gateway.yaml` | api-gateway |
| `envs/dev/values-pharma-ui.yaml` | pharma-ui |

CI currently updates image.tag, not image.repository. Therefore these nine manual repository-address edits are necessary. Let successful CI runs update each tag; confirm that tag exists in the NEW ECR before applying its Application.

Keep all active DEV Application repoURL values and `argocd/projects/pharma-project.yaml` sourceRepos pointing to your same GitOps repository. Destination `https://kubernetes.default.svc` remains correct: each new Argo installation interprets it as its own cluster. No Pod, ClusterIP, node, subnet, VPC, or security-group IP/ID needs manual copying into these Applications.

For the frontend, keep ingress enabled true, className nginx, annotations {}, host empty, path /, pathType Prefix. A newly installed ingress-nginx controller will get a NEW load balancer hostname. Keep backend Ingress disabled if routing through frontend Nginx/gateway as today.

### Other locations with trainer references: optional/unused paths

| File | Action before using it |
|---|---|
| `envs/qa/values-pharma-ui.yaml` | Still has trainer ECR account 873135413040. Set NEW account ECR address and choose appropriate Ingress class/host if actually deploying QA. |
| `argocd/apps/qa/pharma-ui-app.yaml` | Still points to https://github.com/zenpharma/gitops.git. Change to your GitOps URL before using QA. |
| `k8s/raw-manifests/dev/pharma-ui-deployment.yaml` | Replace trainer image/account AND use a real tag in new ECR if using raw deployment. Do not apply alongside Helm-managed pharma-ui. |
| `envs/dev/values-api-gateway copy.yaml` | Backup file contains trainer image ARN and ServiceAccount role annotation. Archive/remove if unused; do not feed it to the active chart. |
| `envs/dev/values-pharma-ui copy.yaml` | Backup file contains trainer image/account; archive/remove if unused. |
| `k8s/raw-manifests/dev/pharma-ui-ingress.yaml` | Review ALB settings before reuse; active deployment is Helm plus Nginx. |
| `argocd/install/argocd-ingress.yaml` | Review class/host argocd.pharma.internal if exposing Argo CD. Port forwarding needs no DNS edit. |

Frontend/backend workflows can create QA values files that are not currently on GitOps main. Audit their image.repository after creation. Keep PROD promotion inactive until its environment/values actually exist.

## 8. Install cluster components and authorize your local identity

Terraform's EKS module grants cluster-creator administration to the IAM identity that creates it: normally the Terraform Actions role. Your new local IAM user/role may need its own EKS access entry and an appropriately scoped access policy before kubectl works. Grant this through an authorized identity; do not assume creating kubeconfig grants access.

```bash
aws eks update-kubeconfig --region us-east-1 \
  --name pharma-dev-eks --alias pharma-new-dev
kubectl config current-context
kubectl get nodes
```

Install Argo CD, External Secrets Operator, and ingress-nginx using the captured chart versions/installation settings. Update ESO ServiceAccount annotation to arn:aws:iam::NEW_ACCOUNT_ID:role/pharma-dev-eso-role. Terraform wires the EBS CSI add-on role automatically; do not copy the old cluster's OIDC issuer into any IAM trust. Any manually installed AWS controller must use the new cluster issuer/role as well.

Recreate `ClusterSecretStore/aws-secrets-manager` using the new region and ESO ServiceAccount authentication. Keep its name because the existing ExternalSecrets reference it. Install ESO CRDs before applying those resources.

## 9. Recreate secrets and initialize the new database

Terraform currently creates RDS with database pharmadb and username pharmaadmin. It does not populate Secrets Manager application secrets.

Find the new RDS hostname:

```bash
aws rds describe-db-instances --region us-east-1 \
  --db-instance-identifier pharma-dev-postgres \
  --query 'DBInstances[0].Endpoint.Address' --output text
```

In the new account, recreate Secrets Manager secrets at the paths captured in step 2. Use new values, then apply the captured/cleaned ExternalSecrets to generate:

| Kubernetes Secret | Namespace | Required application values |
|---|---|---|
| db-credentials | dev | DB_HOST=new RDS hostname; DB_PORT=5432; DB_NAME=pharmadb; DB_USERNAME=pharmaadmin; DB_PASSWORD=new Terraform RDS password |
| jwt-secret | dev | JWT_SECRET=new signing secret of suitable strength/length for the implementation |
| grafana-admin | monitoring | admin-user and admin-password if restoring Grafana |
| fluent-bit-elastic-credentials | dev | api_key if restoring Fluent Bit |

Keep application secret names in envFrom unchanged. Do not put passwords in values.yaml or source files. Check ExternalSecret Ready status without printing Secret contents.

Initialize PostgreSQL schemas using `zen-gitops/db-init/01-schemas.sql` through a connection inside the VPC. The script currently names supplier, but the supplier service actually uses procurement. Include procurement if doing central schema initialization; its Flyway migration also creates procurement. Confirm migration permissions and successful startup. Java services use separate schemas within pharmadb. QC currently uses in-memory H2 and has no durable data migration. Notification has SMTP placeholders; a healthy notification service does not establish email delivery.

Existing application records, credentials stored in RDS, and monitoring history do not transfer automatically. A fresh deployment uses migrations/seeds; preserving old data requires a separate backup/restore exercise.

## 10. Monitoring and Fluent Bit

You can preserve their paused state while learning application deployment:

- envs/monitoring/prometheus-values.yaml: grafana.replicas=0; prometheus.prometheusSpec.replicas=0; alertmanager.alertmanagerSpec.replicas=0; kubeStateMetrics.enabled=false; nodeExporter.enabled=false.
- envs/dev/values-fluent-bit.yaml: enabled=false.

When restoring, ensure gp2-csi StorageClass/new EBS volumes exist. `k8s/monitoring/storageclass.yaml` and `pvc.yaml` create new storage; do not transplant old PVC volumeName values. `k8s/monitoring/grafana-admin-externalsecret.yaml` reads /pharma/dev/grafana-admin; recreate that path/properties in NEW Secrets Manager.

`k8s/fluent-bit/elastic-externalsecret.yaml` reads /pharma/dev/fluent-bit/elastic property api_key. Recreate it before enabling Fluent Bit. `envs/dev/values-fluent-bit.yaml` contains the current Elastic Cloud hostname; keep it only if using the same external Elastic deployment, otherwise replace it. Chart default `helm-charts-fluent-bit/values.yaml` has a different trainer Elastic host: DEV overrides it, but review it before using chart defaults.

## 11. Create Argo CD Applications after images/secrets are ready

```bash
cd ~/zen-gitops
git pull --ff-only
kubectl apply -f k8s/namespaces.yaml
kubectl apply -f argocd/projects/pharma-project.yaml
```

Apply these individually and verify each: auth-service-app.yaml, catalog-service-app.yaml, inventory-service-app.yaml, supplier-service-app.yaml, manufacturing-service-app.yaml, notification-service-app.yaml, qc-service-app.yaml, api-gateway-app.yaml, pharma-ui-app.yaml. They all live in `argocd/apps/dev/`. Monitoring/Fluent Bit Applications are optional for initial rebuild.

```bash
kubectl get applications -n argocd
kubectl get pods -n dev
kubectl get externalsecret -A
kubectl get svc -n ingress-nginx
kubectl get ingress -n dev
```

Test login/catalog/inventory/suppliers/manufacturing/QC through the NEW frontend load balancer, or first use `kubectl port-forward -n dev svc/pharma-ui 8088:80`. If using custom DNS, point it to the new load balancer; certificates/Route 53 hosted zones may require new-account setup. No custom DNS is needed for host-empty HTTP testing.

## 12. Optional URL variables and daily sleep/wake script

The CI DAST jobs are currently disabled. If enabling them later, update these GitHub Actions variables to actual reachable NEW endpoints: DEV_PHARMA_UI_URL (frontend); DEV_AUTH_SERVICE_URL, DEV_DRUG_CATALOG_URL, DEV_INVENTORY_SERVICE_URL, DEV_SUPPLIER_SERVICE_URL, DEV_MANUFACTURING_SERVICE_URL, DEV_NOTIFICATION_SERVICE_URL, DEV_QC_SERVICE_URL, DEV_API_GATEWAY_URL (backend). Do not use private ClusterIPs or invent direct URLs for services without external routes.

Your daily script is local, not in the reviewed repositories. In the supplied script these are configurable: EXPECTED_ACCOUNT, REGION, CLUSTER_NAME, DB_INSTANCE, NODEGROUP, WAKE_DESIRED. Update EXPECTED_ACCOUNT to the new account; region/cluster/database names can stay if reused. Clear any old explicit node-group name: generated node-group names change. Discover it with `aws eks list-nodegroups --region us-east-1 --cluster-name pharma-dev-eks`. The reviewed script auto-discovers when NODEGROUP is empty and exactly one group exists. Keep AWS_PROFILE pointed to the new account and kubeconfig to its cluster.

Example, if your saved pharma-lab-new.sh retains these variable overrides:

```bash
AWS_PROFILE=pharma-new EXPECTED_ACCOUNT=NEW_ACCOUNT_ID \
  REGION=us-east-1 CLUSTER_NAME=pharma-dev-eks \
  DB_INSTANCE=pharma-dev-postgres NODEGROUP= \
  ./pharma-lab-new.sh status
```

Save the script in your own repository if you want the next rebuild to depend only on your four repositories.

## 13. Final audit before considering the rebuild reproducible

From each repository root, use git grep (works without installing ripgrep):

```bash
git grep -n -E '760396521684|873135413040|zen-pharma-terraform-state-geetha-k'
git grep -n -E 'arn:aws:|rds\.amazonaws\.com|elb\.amazonaws\.com|role-arn|repoURL'
```

Review matches, including JSON/bootstrap files, workflow branches, backup files and optional environments. Do not blindly replace every match: historical docs can stay, AWS-managed policy ARNs stay, and unchanged GitHub identities stay.

Completion checks: new-account STS identity verified; new state bucket and bootstrap role working; both CI roles correct; nine images exist in new ECR; all DEV image repositories updated; fresh EKS authorization/components installed; DB/JWT secrets ready; migrations successful; application Pods ready; browser access works; daily script targets new account. Record chart versions and bootstrap manifests so the next deployment does not depend on settings remembered from the old account.
