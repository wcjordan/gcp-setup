# DNS zone & entry for jenkins
resource "google_dns_managed_zone" "parent-zone" {
  name        = "${var.project_name}-dns"
  dns_name    = "${var.dns_name}."
  description = "Top level DNS zone for ${var.project_name}."
}

resource "google_compute_global_address" "jenkins_static_ip" {
  name = "${var.project_name}-jenkins-ip"
}

resource "google_dns_record_set" "jenkins-recordset" {
  managed_zone = google_dns_managed_zone.parent-zone.name
  name         = "jenkins.${var.dns_name}."
  type         = "A"
  rrdatas      = [google_compute_global_address.jenkins_static_ip.address]
  ttl          = 1800
}

# Jenkins Helm install
resource "helm_release" "jenkins" {
  name  = "jenkins-ci"
  chart = "bitnami/jenkins"

  values = [
    "${file("../charts/jenkins/values.yaml")}"
  ]
  set {
    name = "ingress.annotations.kubernetes\\.io/ingress\\.global-static-ip-name"
    value = "${var.project_name}-jenkins-ip"
  }
  set {
    name = "ingress.extraHosts[0].name"
    value = "jenkins.${var.dns_name}"
  }
  set {
    name = "ingress.extraHosts[0].path"
    value = "/*"
  }
}
