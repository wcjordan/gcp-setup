# gcp-setup
## Prerequisites
[Install Terraform](https://learn.hashicorp.com/tutorials/terraform/install-cli?in=terraform/gcp-get-started).

[Create a GCP project](https://console.cloud.google.com/projectcreate)
Use `gcloud init` to configure gcloud to use the new project.  
Enable compute engine API:
```
gcloud services enable artifactregistry.googleapis.com
gcloud services enable cloudresourcemanager.googleapis.com
gcloud services enable compute.googleapis.com
gcloud services enable container.googleapis.com
gcloud services enable dns.googleapis.com
gcloud services enable iam.googleapis.com
gcloud services enable identitytoolkit.googleapis.com
gcloud services enable sqladmin.googleapis.com
```
Re-initialize a 2nd time after enabling services (see below) to allow setting zone & region  

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

Download service account key so you can set it as a variable in Terraform Cloud (see below)
```
gcloud iam service-accounts keys create <SECURE WORKSPACE>/service_account_key.json \
  --iam-account=$SERVICE_ACCOUNT@$PROJECT_ID.iam.gserviceaccount.com
```

## Set up a Workspace in Terraform Cloud
[Create a new workspace](https://app.terraform.io/app)  
Version control workflow -> Github -> `gcp-setup` repo -> `terraform` subdirectory  

Set variables for the following fields in Terraform Cloud  
See variables.tf for field descriptions  

project_name & project_id - your GCP project details  
gcp_region & gcp_zone  
admin_email - Your email address  
dns_name - Your domain e.g. mysite.com  

browserstack_username & browserstack_access_key - See username & access key under [Automate section of settings](https://www.browserstack.com/accounts/settings)  

oauth_client_id & oauth_client_secret - See Credentials for Jenkins OAuth below  
github_app_id & github_app_private_key - Follow the [Jenkins github-branch-source-plugin instructions](https://github.com/jenkinsci/github-branch-source-plugin/blob/master/docs/github-app.adoc).  The private key needs to be set as a single line.  Remove the BEGIN PRIVATE KEY and END PRIVATE KEY parts.

gcp_service_account_key - See Create a service account for Terraform section above  

### Create Credentials for Jenkins OAuth
Navigate to `https://console.cloud.google.com/apis/credentials`  
Be sure you're in the desired project  
Press `Create Credentials => OAuth Client ID => Configure Consent Screen`  
Select `External` users.  In the future explore `Internal` if we use a workspace.  
Fill out the consent screen form.  No scopes are needed.  

Return to initial page.  Press `Create Credentials => OAuth Client ID`  
Set type to `Web Application`  
Set domain URI to `http://jenkins.${dns_name}`  
Set redirect URI to `http://jenkins.${dns_name}/securityRealm/finishLogin`  

Set the oauth_client_id & oauth_client_secret variables in Terraform Cloud  
For more details see [Google Login Plugin](https://github.com/jenkinsci/google-login-plugin/blob/master/README.md) & [StackOverlow](https://stackoverflow.com/a/55595582)

## Apply Terraform to create GKE cluster and install Jenkins
Run Terraform from Terraform Cloud

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

### Get credentials for Docker to use Google Artifact Registry
Replace us-eas4 with the region you've configured.
```
gcloud auth configure-docker us-east4-docker.pkg.dev
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
