# gcp-setup
## Prerequisites
[Install Terraform](https://learn.hashicorp.com/tutorials/terraform/install-cli?in=terraform/gcp-get-started) & [Set up GCP](https://learn.hashicorp.com/tutorials/terraform/google-cloud-platform-build?in=terraform/gcp-get-started#set-up-gcp).

Use `gcloud init` to configure gcloud to use the new project.

Enable APIs:
```
gcloud services enable compute.googleapis.com
gcloud services enable cloudresourcemanager.googleapis.com
gcloud services enable iam.googleapis.com
gcloud services enable container.googleapis.com
gcloud services enable sqladmin.googleapis.com
gcloud services enable dns.googleapis.com
```

Create a service account for Terraform
```
PROJECT_ID=<PROJECT_ID>
SERVICE_ACCOUNT=$PROJECT_ID-terraform
gcloud iam service-accounts create $SERVICE_ACCOUNT

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member "serviceAccount:$SERVICE_ACCOUNT@$PROJECT_ID.iam.gserviceaccount.com" \
  --role roles/editor
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member "serviceAccount:$SERVICE_ACCOUNT@$PROJECT_ID.iam.gserviceaccount.com" \
  --role roles/resourcemanager.projectIamAdmin
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member "serviceAccount:$SERVICE_ACCOUNT@$PROJECT_ID.iam.gserviceaccount.com" \
  --role roles/iam.serviceAccountAdmin
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member "serviceAccount:$SERVICE_ACCOUNT@$PROJECT_ID.iam.gserviceaccount.com" \
  --role roles/compute.instanceAdmin
```

Download service account key and place in directory
```
GIT_DIR=<GIT_ROOT>/gcp-setup
gcloud iam service-accounts keys create $GIT_DIR/service_account_key.json \
  --iam-account=$SERVICE_ACCOUNT@$PROJECT_ID.iam.gserviceaccount.com
```

Init Terraform
```
cd $GIT_DIR/terraform
terraform init
```

## Create GKE Cluster
Run Terraform in the terraform directory
```
cd $GIT_DIR/terraform
terraform apply
```

Setup gcloud & kubectl
```
PROJECT_NAME=<PROJECT_NAME>
gcloud container clusters get-credentials $PROJECT_NAME-gke
```
Verify with
```
gcloud config configurations list
kubectl config get-contexts
```

Also need to annotate the default namespace manually until [issue #692](https://github.com/hashicorp/terraform-provider-kubernetes/issues/692) is complete  
```
kubectl annotate namespace default cnrm.cloud.google.com/project-id=$PROJECT_ID
```

## Setup DNS
Terraform will setup the DNS, but you may need to set an NS entry in the domain parent zone.
See https://stackoverflow.com/questions/23356881/manage-only-a-subdomain-with-google-cloud-dns

## Setup Jenkins
Terraform will create a static IP, DNS entry, and install the Helm chart

May need to add repo.  Not sure?
```
helm repo add bitnami https://charts.bitnami.com/bitnami
```

Get password for user `user`
```
kubectl get secret --namespace default jenkins-ci -o jsonpath="{.data.jenkins-password}" | base64 --decode
```

```
gcloud docker -- push gcr.io/flipperkid-default/jenkins-worker
```
