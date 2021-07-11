# gcp-setup
Prerequisites: Install Terraform & [Set up GCP](https://learn.hashicorp.com/tutorials/terraform/google-cloud-platform-build?in=terraform/gcp-get-started#set-up-gcp).

Enable APIs:
- Compute Engine - https://console.cloud.google.com/apis/library/compute.googleapis.com
- Cloud Resource Manager - https://console.cloud.google.com/apis/library/cloudresourcemanager.googleapis.com
- IAM - https://console.developers.google.com/apis/library/iam.googleapis.com
- Kubernetes Engine - https://console.cloud.google.com/apis/library/container.googleapis.com
- Cloud SQL Admin - https://console.cloud.google.com/apis/library/sqladmin.googleapis.com

Also grant the Terraform service account the roles in the project:
- roles/editor
- roles/resourcemanager.projectIamAdmin
- roles/iam.serviceAccountAdmin
- roles/compute.instanceAdmin

Also need to annotate the default namespace manually until issue #692 is complete
https://github.com/hashicorp/terraform-provider-kubernetes/issues/692
kubectl annotate namespace default cnrm.cloud.google.com/project-id=PROJECT_ID
