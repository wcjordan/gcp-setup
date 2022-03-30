# gcp-setup
## Prerequisites
[Install Terraform](https://learn.hashicorp.com/tutorials/terraform/install-cli?in=terraform/gcp-get-started).

[Create a GCP project](https://console.cloud.google.com/projectcreate)
Use `gcloud init` to configure gcloud to use the new project.  
Re-initialize a 2nd time after enabling services (see below) to allow setting zone & region  

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

Download service account key so you can set it as a variable in Terraform Cloud (see below)
```
gcloud iam service-accounts keys create <SECURE WORKSPACE>/service_account_key.json \
  --iam-account=$SERVICE_ACCOUNT@$PROJECT_ID.iam.gserviceaccount.com
```

## Set up a Workspace in Terraform Cloud
Set variables for the following fields in Terraform Cloud
See variables.tf for field descriptions

project_name & project_id - your GCP project details
admin_email - Your email address
dns_name - Your domain e.g. mysite.com

browserstack_username & browserstack_access_key - See username & access key under [Automate section of settings](https://www.browserstack.com/accounts/settings)

oauth_client_id & oauth_client_secret - See Credentials for Jenkins OAuth below

sentry_dsn - A Sentry.io DSN.  https://sentry.io/settings/<ORG_ID>/projects/<PROJECT_ID>/keys/
sentry_token - A [Sentry.io auth token](https://sentry.io/settings/account/api/auth-tokens/)

gcp_service_account_key - See Create a service account for Terraform section above
chalk_oauth_client_secret & oauth_refresh_token - See the [OAuth Setup section of Chalk README.md](https://github.com/wcjordan/chalk/blob/main/README.md)

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

Set the Client ID & Client Secret variables in Terraform Cloud  
For more details see [Google Login Plugin](https://github.com/jenkinsci/google-login-plugin/blob/master/README.md) & [StackOverlow](https://stackoverflow.com/a/55595582)

### Add Secrets
See instructions within each repos README

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
