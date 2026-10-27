# Implementation Plan: Put Jenkins behind SSL

**Epic:** minordomo-2hb  
**GH Issue:** https://github.com/wcjordan/gcp-setup/issues/46

## Summary

Jenkins currently serves traffic over HTTP. This plan adds HTTPS via GCP Managed SSL Certificates, which integrate natively with the existing GCP global load balancer ingress. HTTP traffic will be redirected to HTTPS. The Jenkins JCasC URL will be updated to reflect the HTTPS endpoint.

cert-manager is already installed in the cluster but its existing ClusterIssuer uses `ingressClassName: nginx` which does not match Jenkins' GCP global ingress. GCP Managed Certificates is the appropriate choice for the GCP global load balancer.

---

## Stage 1: Add GCP Managed SSL Certificate to Jenkins ingress

### Description

Add a `google_compute_managed_ssl_certificate` Terraform resource for Jenkins and annotate the Jenkins ingress to use it. Also add a `FrontendConfig` Kubernetes resource to redirect HTTP traffic to HTTPS, and annotate the ingress to use it.

Changes in `terraform/jenkins.tf`:

1. Add `google_compute_managed_ssl_certificate` resource:
   ```hcl
   resource "google_compute_managed_ssl_certificate" "jenkins" {
     name = "${var.project_name}-jenkins-cert"
     managed {
       domains = ["jenkins.${var.dns_name}"]
     }
   }
   ```

2. Add `kubectl_manifest` for a `FrontendConfig` to enable HTTP→HTTPS redirect:
   ```hcl
   resource "kubectl_manifest" "jenkins-frontend-config" {
     yaml_body = <<YAML
   apiVersion: networking.gke.io/v1beta1
   kind: FrontendConfig
   metadata:
     name: jenkins-frontend-config
     namespace: jenkins-controller
   spec:
     redirectToHttps:
       enabled: true
       responseCodeName: MOVED_PERMANENTLY_DEFAULT
   YAML
     depends_on = [kubernetes_namespace_v1.jenkins-namespace]
   }
   ```

3. Add these ingress annotations to the `helm_release.jenkins` values:
   ```yaml
   networking.gke.io/managed-certificates: "<project_name>-jenkins-cert"
   networking.gke.io/v1beta1.FrontendConfig: "jenkins-frontend-config"
   ```
   Note: The managed certificate name must be interpolated from `var.project_name`.

### Acceptance Criteria
- `google_compute_managed_ssl_certificate` resource is declared in `terraform/jenkins.tf`
- `kubectl_manifest` for `FrontendConfig` is declared in `terraform/jenkins.tf`
- Jenkins ingress annotations include `networking.gke.io/managed-certificates` and `networking.gke.io/v1beta1.FrontendConfig`
- `terraform plan` runs without errors
- `terraform apply` runs without errors (when credentials are available)

---

## Stage 2: Update Jenkins JCasC URL to HTTPS

### Description

Update the Jenkins Configuration-as-Code (JCasC) `location.url` from `http://` to `https://` so Jenkins knows its canonical URL is HTTPS. This affects redirect URLs, webhook callbacks, and other places Jenkins includes its own URL.

In `terraform/jenkins.tf`, in the `helm_release.jenkins` JCasC config block, change:
```yaml
url: "http://jenkins.${var.dns_name}/"
```
to:
```yaml
url: "https://jenkins.${var.dns_name}/"
```

### Acceptance Criteria
- JCasC `location.url` uses `https://` in `terraform/jenkins.tf`
- `terraform plan` runs without errors
- The change is committed and pushed with Stage 1's changes (or as a follow-on PR)
