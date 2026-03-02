# tuten-gitops-bootstrap

> GitOps base de plataforma para entornos **no-prod** (DEV/UAT) en OKE (Oracle Kubernetes Engine).  
> ⚠️ **Este repositorio NO gestiona PRD. Ningún cambio aquí afecta producción.**

---

## Estructura

```
tuten-gitops-bootstrap/
├── terraform/
│   ├── environments/
│   │   └── dev/           # Terraform para DEV (namespaces, quotas, RBAC)
│   └── modules/
│       ├── namespaces/    # Crea namespaces + ResourceQuota + LimitRange
│       └── rbac/          # Roles y bindings (developer + argocd-deployer)
├── helm/
│   └── charts/
│       └── app-template/  # Chart base: api + worker + ingress
│           ├── values.yaml
│           └── values-dev.yaml
├── argocd/
│   ├── projects/
│   │   └── non-prod.yaml  # AppProject tutenlabs-non-prod
│   └── apps/
│       ├── app-of-apps.yaml       # Root app (app-of-apps pattern)
│       └── dev/
│           └── example-app.yaml   # Ejemplo de app DEV
└── .github/workflows/
    └── lint-validate.yml  # CI: tflint, checkov, terraform validate, helm lint, yamllint
```

---

## Bootstrap

### Pre-requisitos

- `kubectl` configurado con contexto `tutenlabs-dev`
- `terraform >= 1.5`
- `helm >= 3.14`
- `argocd` CLI (opcional, para inspección)
- Acceso a GitHub (PAT con scopes `repo`, `workflow`)

### 1. Infraestructura base (Terraform)

```bash
# Posicionarse en el entorno DEV
cd terraform/environments/dev

# Inicializar (sin backend para prueba local)
terraform init -backend=false

# Ver plan
terraform plan -var-file=terraform.tfvars

# Aplicar (requiere confirmación de Marcos = "DALE")
terraform apply -var-file=terraform.tfvars
```

> **Qué crea:** namespaces `apps-dev`, `monitoring-dev`, `argocd`, `ingress-nginx` con ResourceQuota + LimitRange + RBAC.

### 2. Instalar ArgoCD en el cluster DEV

```bash
# FIX-12: El namespace 'argocd' es creado por Terraform en el paso anterior.
# No usar 'kubectl create namespace argocd' — Terraform es la fuente de verdad.
# Si Terraform falló, revisar el output de 'terraform apply' antes de continuar.

# Instalar ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Esperar que pods estén Ready
kubectl wait --for=condition=available deployment/argocd-server -n argocd --timeout=120s
```

### 3. Configurar repo en ArgoCD

```bash
# Port-forward para acceder al API
kubectl port-forward svc/argocd-server -n argocd 8080:443 &

# Login (obtener contraseña inicial)
ARGOCD_PASS=$(kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d)
argocd login localhost:8080 --username admin --password $ARGOCD_PASS --insecure

# Agregar el repo GitOps
argocd repo add https://github.com/marcosmeoni/tuten-gitops-bootstrap \
  --username marcosmeoni \
  --password $GITHUB_PAT
```

### 4. Aplicar AppProject + App of Apps

```bash
# AppProject primero
kubectl apply -f argocd/projects/non-prod.yaml

# Root app (gestiona todas las apps DEV)
kubectl apply -f argocd/apps/app-of-apps.yaml
```

ArgoCD sincronizará automáticamente todas las apps definidas en `argocd/apps/dev/`.

---

## Deploy de una nueva app

1. Copiar `argocd/apps/dev/example-app.yaml` → `argocd/apps/dev/mi-nueva-app.yaml`
2. Editar `name`, `api.image.repository`, `ingress.host`
3. Si la app necesita valores custom, agregar en `helm/charts/app-template/values-dev.yaml` o via `parameters` en el manifest
4. Crear PR → merge a `main` → ArgoCD sincroniza automáticamente

---

## Rollback

### Rollback de una app via ArgoCD

```bash
# Ver historial de una app
argocd app history example-app-dev

# Rollback a revision anterior
argocd app rollback example-app-dev <REVISION_ID>
```

### Rollback de infraestructura (Terraform)

```bash
cd terraform/environments/dev

# Ver último estado aplicado
terraform show

# Revertir a un estado anterior (requiere backup del tfstate)
# 1. Restaurar tfstate desde backup
# 2. terraform apply para reconciliar
```

### Rollback de un commit

```bash
# Revertir el commit problemático
git revert <COMMIT_SHA>
git push origin main
# ArgoCD detecta el cambio y re-sincroniza automáticamente
```

---

## Troubleshooting

### ArgoCD app en estado `OutOfSync`

```bash
argocd app sync example-app-dev
argocd app get example-app-dev
```

### Pod crasheando

```bash
kubectl get pods -n apps-dev
kubectl describe pod <POD_NAME> -n apps-dev
kubectl logs <POD_NAME> -n apps-dev --previous
```

### Terraform error de permisos

```bash
# Verificar kubeconfig
kubectl config current-context

# Verificar que el contexto sea DEV (nunca PRD)
kubectl config get-contexts
```

### Helm chart inválido

```bash
helm lint helm/charts/app-template/ -f helm/charts/app-template/values-dev.yaml
helm template test helm/charts/app-template/ -f helm/charts/app-template/values-dev.yaml --debug
```

---

## CI/CD

El pipeline `.github/workflows/lint-validate.yml` ejecuta en cada PR:

| Check | Tool | Qué valida |
|-------|------|------------|
| Terraform Validate | `terraform validate` | Sintaxis y estructura HCL |
| Terraform Lint | `tflint` | Best practices y errores comunes |
| Security Scan | `checkov` | Misconfigs de seguridad en Terraform |
| Helm Lint | `helm lint` | Sintaxis y estructura del chart |
| YAML Lint | `yamllint` | Formato y estilo de todos los YAMLs |
| ArgoCD Manifests | `kubeconform` | Validación de CRDs de ArgoCD |

---

## Restricciones de seguridad

- ✅ Namespaces DEV/UAT únicamente
- ✅ RBAC con menor privilegio (developers: read-only, ArgoCD: namespace-scoped)
- ✅ ResourceQuota por namespace (evita resource starvation)
- ✅ LimitRange con defaults seguros
- ✅ SecurityContext: `runAsNonRoot`, `readOnlyRootFilesystem`, `drop: ALL`
- ❌ Sin `ClusterRole` de admin
- ❌ Sin wildcard IAM policies
- ❌ Sin secrets hardcodeados (usar ExternalSecrets o Vault)

---

## Maintainers

- Platform Engineering — Tutenlabs
- Repo owner: [@marcosmeoni](https://github.com/marcosmeoni)
