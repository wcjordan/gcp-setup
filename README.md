# gcp-setup
## Prerequisites
[Install Terraform](https://learn.hashicorp.com/tutorials/terraform/install-cli?in=terraform/gcp-get-started) & [Set up GCP](https://learn.hashicorp.com/tutorials/terraform/google-cloud-platform-build?in=terraform/gcp-get-started#set-up-gcp).

Use `gcloud init` to configure gcloud to use the new project.  
Re-initialize a 2nd time after enabling services to allow setting zone & region  

Enable APIs:
```
gcloud services enable compute.googleapis.com
gcloud services enable cloudresourcemanager.googleapis.com
gcloud services enable iam.googleapis.com
gcloud services enable container.googleapis.com
gcloud services enable sqladmin.googleapis.com
gcloud services enable dns.googleapis.com
gcloud services enable identitytoolkit.googleapis.com
```

## Create a service account for Terraform
```
PROJECT_ID=<PROJECT_ID>
SERVICE_ACCOUNT=$PROJECT_ID-terraform
gcloud iam service-accounts create $SERVICE_ACCOUNT

# For reference https://cloud.google.com/iam/docs/permissions-reference
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
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member "serviceAccount:$SERVICE_ACCOUNT@$PROJECT_ID.iam.gserviceaccount.com" \
  --role roles/container.admin
```

Download service account key and place in directory
```
GIT_DIR=<GIT_ROOT>/gcp-setup
gcloud iam service-accounts keys create $GIT_DIR/secrets/service_account_key.json \
  --iam-account=$SERVICE_ACCOUNT@$PROJECT_ID.iam.gserviceaccount.com
```

## Init & Prepare Terraform
```
cd $GIT_DIR/terraform
terraform init
touch terraform.tfvars
```

Set the contents of terraform.tfvars with the values filled in:
```
project_name =
project_id   =
admin_email  =
dns_name     =

browserstack_username   =
browserstack_access_key =

oauth_client_id     =
oauth_client_secret =
oauth_refresh_token =

sentry_dsn   =
sentry_token =
```

### Create Credentials for Jenkins OAuth
Navigate to `https://console.cloud.google.com/apis/credentials`  
Be sure you're in the desired project  
Press `Create Credentials => OAuth Client ID => Configure Consent Screen`  
Select `External` users.  In the future explore `Internal` if we use a workspace.  
Fill out the consent screen form.  No scopes are needed.  

Return to initial page.  Press `Create Credentials => OAuth Client ID`  
Set type to `Web Application`  
Set domain URI to `http://${JENKINS_ROOT_URL}`  
Set redirect URI to `http://${JENKINS_ROOT_URL}/securityRealm/finishLogin`  

Copy the Client ID & Client Secret for terraform.tfvars  
For more details see [Google Login Plugin](https://github.com/jenkinsci/google-login-plugin/blob/master/README.md) & [StackOverlow](https://stackoverflow.com/a/55595582)

### Add Helm repo
```
helm repo add jenkinsci https://charts.jenkins.io
helm repo update
```

### Add Secrets
See instructions within each repos README

## Apply Terraform to create GKE cluster and install Jenkins
Run Terraform in the terraform directory
```
cd $GIT_DIR/terraform
terraform apply
```

### Setup gcloud & kubectl for GKE cluster
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
Terraform will setup the DNS, but you may need to update name servers in Google Domains (see [this GCloud tutorial, step #5](https://cloud.google.com/dns/docs/tutorials/create-domain-tutorial#update-nameservers)) or set an NS entry in the domain parent zone (see [this StackOverflow answer](https://stackoverflow.com/questions/23356881/manage-only-a-subdomain-with-google-cloud-dns)).

Your DNS NS data for this step can be found on [the GCloud DNS page](https://console.cloud.google.com/net-services/dns).

## Setup Jenkins
Terraform will create a static IP, DNS entry, and install the Helm chart

### Add Builds
See instructions within each repos README

### Other
Under `Configure System`, verify that all `Administrative Monitors` are enabled.
