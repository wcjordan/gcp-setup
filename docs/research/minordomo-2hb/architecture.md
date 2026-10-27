# Architecture Research: Put Jenkins behind SSL

## Current Jenkins Setup

Jenkins is deployed via Helm chart (`helm_release.jenkins` in `terraform/jenkins.tf`) with:
- **Ingress**: GCP global load balancer via `kubernetes.io/ingress.global-static-ip-name` annotation
- **Static IP**: `google_compute_global_address.jenkins_static_ip`
- **DNS**: A record pointing `jenkins.${var.dns_name}` to the static IP
- **Protocol**: Currently HTTP only (`url: "http://jenkins.${var.dns_name}/"` in JCasC)
- **Namespace**: `jenkins-controller`

## Existing SSL Infrastructure

cert-manager is already installed (`helm_release.cert-manager` in `terraform/gke_cluster.tf`):
- Version: v1.17.1
- A `ClusterIssuer` (`letsencrypt-cluster-cert-issuer`) exists using Let's Encrypt ACME
- The ClusterIssuer uses HTTP01 solver with `ingressClassName: nginx`
- **No nginx ingress controller is installed** — this ClusterIssuer cannot be used directly with the GCP global ingress

## SSL Options Considered

### Option A: GCP Managed Certificates (Recommended)
- Use `google_compute_managed_ssl_certificate` Terraform resource
- Annotate Jenkins ingress with `networking.gke.io/managed-certificates`
- GCP handles cert issuance and auto-renewal from Let's Encrypt
- Works natively with existing GCP global load balancer ingress
- Simplest Terraform change

### Option B: cert-manager with DNS01 Challenge
- Create a new `ClusterIssuer` using DNS01 solver (via GCP Cloud DNS)
- Requires IAM service account with `roles/dns.admin` for cert-manager
- More complex but consistent with existing cert-manager installation

### Option C: cert-manager HTTP01 via GCP Ingress
- Modify ClusterIssuer to use GCP ingress class instead of nginx
- GCP global load balancer provisioning is slow (~5-10 min) which may cause ACME challenge timeouts
- Not recommended

## Decision: Option A - GCP Managed Certificates

Rationale:
- Jenkins already uses GCP global ingress; managed certs integrate natively
- No ingress class mismatch
- No extra IAM or cert-manager configuration needed
- Auto-renewal handled by GCP

## Changes Required

1. `terraform/jenkins.tf`:
   - Add `google_compute_managed_ssl_certificate` resource for Jenkins
   - Add `networking.gke.io/managed-certificates` annotation to Jenkins ingress
   - Add `networking.gke.io/v1beta1.FrontendConfig` annotation for HTTP→HTTPS redirect
   - Update JCasC `url` from `http://` to `https://`
   - Add `kubernetes_manifest` for `FrontendConfig` resource (HTTP→HTTPS redirect)
