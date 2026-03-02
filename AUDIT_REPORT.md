# Auditoría kube-stack DEV — Reporte Final

**Repo:** `marcosmeoni/tuten-gitops-bootstrap`  
**Rama auditada:** `feat/bootstrap-gitops-dev-v2`  
**Rama de remediación:** `fix/audit-remediation-dev`  
**Fecha:** 2026-03-02  
**Auditor:** ashbot 🦾 (spec-platform-engineering)  
**Task ID:** 5611188c-59cb-460f-9569-cc444487bda1

---

## Resumen Ejecutivo

Se identificaron **12 hallazgos** distribuidos en categorías de seguridad, confiabilidad, CI/CD y documentación. Todos los hallazgos fueron remediados en la rama `fix/audit-remediation-dev`. Ningún cambio afecta entornos PRD.

| Severidad | Cantidad |
|-----------|----------|
| 🔴 Alta   | 3        |
| 🟡 Media  | 6        |
| 🟢 Baja   | 3        |

---

## Hallazgos y Remediaciones

### 🔴 FIND-01 — Terraform Backend S3 sin parámetros (Alta)
**Archivo:** `terraform/environments/dev/main.tf`  
**Problema:** El bloque `backend "s3"` estaba vacío con solo comentarios. Sin `bucket`, `endpoint` y `key`, `terraform init` fallaría en CI y el state se almacenaría localmente por accidente.  
**Riesgo:** State corruption, deployments no reproducibles, pérdida de estado.  
**Fix:** Backend declarado con bloque vacío (configuración vía `-backend-config`). Agregado `backend-dev.hcl.example` como template. `backend-dev.hcl` agregado a `.gitignore`.  
**Rollback:** Revertir `main.tf` al bloque anterior y eliminar el ejemplo.

---

### 🔴 FIND-02 — Provider Kubernetes depende de kubeconfig en disco (Alta)
**Archivo:** `terraform/environments/dev/main.tf`  
**Problema:** `config_path = var.kubeconfig_path` requiere que el archivo exista en la ruta del runner de CI. En GitHub Actions, el kubeconfig no existe por defecto.  
**Riesgo:** CI falla silenciosamente o usa el contexto equivocado.  
**Fix:** Documentado en código y README que CI debe proveer `KUBE_HOST`, `KUBE_TOKEN`, `KUBE_CA_CERT` como variables de entorno. El provider de Kubernetes los detecta automáticamente.  
**Rollback:** N/A (cambio de documentación).

---

### 🔴 FIND-03 — RBAC argocd-deployer con wildcard resources: ["*"] (Alta)
**Archivo:** `terraform/modules/rbac/main.tf`  
**Problema:** El Role `argocd-deployer` tenía `resources: ["*"]` y `verbs: ["*"]`, equivalente a `ClusterAdmin` dentro del namespace. Viola principio de menor privilegio.  
**Riesgo:** Compromiso del service account de ArgoCD → acceso total al namespace.  
**Fix:** Lista explícita de recursos: `deployments`, `services`, `configmaps`, `ingresses`, `jobs`, `roles/rolebindings`, `hpa`. Solo los verbos necesarios.  
**Rollback:** Restaurar el bloque wildcard (no recomendado).

---

### 🟡 FIND-04 — image.tag: "latest" en values base (Media)
**Archivo:** `helm/charts/app-template/values.yaml`  
**Problema:** `tag: "latest"` en los defaults de `api` y `worker`. Apps en producción/staging que olvidaran overridear heredarían `latest`, imposibilitando reproducibilidad y auditoría.  
**Riesgo:** Deployments no reproducibles, tags mutables.  
**Fix:** `tag: ""` (vacío). Helm falla con imagen vacía si no se provee override, forzando explicititud. Comentario documenta la expectativa.  
**Rollback:** Restaurar `tag: "latest"`.

---

### 🟡 FIND-05 — Worker sin liveness/readiness probes (Media)
**Archivo:** `helm/charts/app-template/templates/deployment-worker.yaml`  
**Problema:** El deployment del worker no tenía probes. Pods crasheando o bloqueados no serían detectados por el scheduler.  
**Riesgo:** Workers zombie, tráfico dirigido a pods no ready.  
**Fix:** Agregadas `livenessProbe` y `readinessProbe` con TCP socket por defecto (configurable por app). Override vía `values.yaml`.  
**Rollback:** Eliminar los bloques de probe del template.

---

### 🟡 FIND-06 — GitHub Actions trigger en push a main (Media)
**Archivo:** `.github/workflows/lint-validate.yml`  
**Problema:** `on: push: branches: [main]` ejecuta CI en cada merge a main, incluyendo merge commits ya validados en el PR. Doble ejecución innecesaria, desperdicia minutos de CI.  
**Riesgo:** Costo de CI, confusión en historial de Actions.  
**Fix:** Removido `push: main`. CI corre en PRs y ramas `feat/**`, `fix/**`, `chore/**`.  
**Rollback:** Re-agregar `main` al bloque `push`.

---

### 🟡 FIND-07 — Actions sin versiones exactas (supply chain risk) (Media)
**Archivos:** `.github/workflows/lint-validate.yml`  
**Problema:** `checkov-action@v12`, `setup-tflint@v4`, `setup-helm@v4` usan tags mutables. Un actor malicioso puede alterar el tag y ejecutar código arbitrario en el runner.  
**Riesgo:** Supply chain attack.  
**Fix:** Pinned `checkov-action` a SHA de commit. Pinned `tflint_version: v0.50.3`. Pinned `helm: v3.14.4`. Pinned `kubeconform: v0.6.4`.  
**Rollback:** Restaurar tags mutables (no recomendado).

---

### 🟡 FIND-08 — yamllint falla en templates Helm (CI bloqueante) (Media)
**Archivo:** `.github/workflows/lint-validate.yml`  
**Problema:** yamllint corría sobre `helm/` incluyendo el directorio `templates/`. Los delimitadores `{{ }}` y la indentación de Go templates no son YAML válido. CI fallaría en `deployment-api.yaml` con múltiples errores de braces.  
**Riesgo:** CI siempre rojo, PR bloqueado.  
**Fix:** yamllint excluye `helm/charts/app-template/templates/`. Solo valida `values.yaml` y `values-dev.yaml` (que sí son YAML puro). ArgoCD + CI usan jobs separados.  
**Rollback:** Restaurar `file_or_dir: helm/` en yamllint.

---

### 🟡 FIND-09 — ArgoCD app-of-apps apunta a HEAD implícito (Media)
**Archivo:** `argocd/apps/app-of-apps.yaml`  
**Problema:** `targetRevision: HEAD` es implícito y no queda registrado en qué branch/tag apunta. Al cambiar el branch por defecto del repo, ArgoCD seguiría al nuevo branch sin aviso.  
**Riesgo:** Deployments inesperados si el default branch cambia.  
**Fix:** `targetRevision: main` explícito. Comentario documenta que UAT/PRD deben usar tags. Agregado `ServerSideApply=true` para mejor manejo de managed fields.  
**Rollback:** Volver a `targetRevision: HEAD`.

---

### 🟡 FIND-10 — Terraform required_version sin upper bound (Media)
**Archivo:** `terraform/environments/dev/main.tf`  
**Problema:** `>= 1.5.0` permite Terraform 2.x que puede introducir breaking changes.  
**Riesgo:** CI rompe inesperadamente tras upgrade de Terraform.  
**Fix:** `>= 1.5.0, < 2.0.0` — permite patches pero bloquea major upgrade.  
**Rollback:** Volver a `>= 1.5.0`.

---

### 🟢 FIND-11 — podAnnotations: {} renderiza bloque vacío literal (Baja)
**Archivo:** `helm/charts/app-template/values.yaml` + templates  
**Problema:** `podAnnotations: {}` con `{{- toYaml .Values.podAnnotations | nindent 8 }}` renderizaba `annotations: {}` en el manifest. Algunas herramientas de auditoría marcan esto como anomalía.  
**Riesgo:** Cosmético, pero puede confundir mutating webhooks.  
**Fix:** `podAnnotations: ~` (null). Templates usan `{{- with .Values.podAnnotations }}` para renderizar solo si tiene valores.  
**Rollback:** Volver a `{}` y restaurar `toYaml` directo.

---

### 🟢 FIND-12 — README duplica creación de namespace argocd (Baja)
**Archivo:** `README.md`  
**Problema:** El paso 2 del bootstrap indicaba `kubectl create namespace argocd` — pero el namespace ya es creado por Terraform en el paso 1. Doble creación causa error o estado inconsistente.  
**Riesgo:** Confusión en bootstrap, namespace fuera de control de TF.  
**Fix:** Comentario en README explica que el namespace es de responsabilidad de Terraform y no debe crearse manualmente.  
**Rollback:** N/A (documentación).

---

## Changelog de Archivos Modificados

| Archivo | Tipo de cambio | Hallazgos relacionados |
|---------|---------------|----------------------|
| `terraform/environments/dev/main.tf` | Modificado | FIND-01, FIND-02, FIND-10 |
| `terraform/environments/dev/backend-dev.hcl.example` | Nuevo | FIND-01 |
| `terraform/modules/rbac/main.tf` | Modificado | FIND-03 |
| `helm/charts/app-template/values.yaml` | Modificado | FIND-04, FIND-05, FIND-11 |
| `helm/charts/app-template/templates/deployment-api.yaml` | Modificado | FIND-11 |
| `helm/charts/app-template/templates/deployment-worker.yaml` | Modificado | FIND-05, FIND-11 |
| `.github/workflows/lint-validate.yml` | Modificado | FIND-06, FIND-07, FIND-08 |
| `argocd/apps/app-of-apps.yaml` | Modificado | FIND-09 |
| `.gitignore` | Modificado | FIND-01 |
| `README.md` | Modificado | FIND-12 |

---

## Plan de Rollback Global

Si la rama `fix/audit-remediation-dev` introduce regresiones:

```bash
# Revertir todos los commits de esta rama
git revert HEAD~<N>..HEAD

# O volver a la base
git reset --hard origin/main
git push origin main --force-with-lease
```

ArgoCD detecta el cambio y re-sincroniza automáticamente al estado anterior.

---

## Herramientas de Auditoría Usadas

- `helm lint` + `helm template` — validación de chart y renderizado
- `yamllint` — lint de YAML (ArgoCD manifests + CI workflows)
- Revisión manual de Terraform HCL, RBAC, GitHub Actions
- Análisis de seguridad: RBAC, supply chain, image pinning
