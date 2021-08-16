credentials:
  system:
    domainCredentials:
      - credentials:
        - googleRobotPrivateKey:
            projectId: "gke_key"
            serviceAccountConfig:
              json:
                secretJsonKey: $${jenkins/google_service_account_key}
        - browserStack:
            id: "browserstack_key"
            username: "${browserstack_username}"
            accesskey: $${jenkins/browserstack_access_key}
jenkins:
  authorizationStrategy:
    globalMatrix:
      permissions:
      - "Overall/Administer:${admin_email}"
  clouds:
  - kubernetes:
      containerCap: 2
      containerCapStr: "2"
      credentialsId: "gke_key"
      name: "kubernetes"
      webSocket: true
  globalNodeProperties:
  - envVars:
      env:
      - key: "GCP_PROJECT"
        value: "${project_id}"
  numExecutors: 0
  securityRealm:
    googleOAuth2:
      clientId: "${oauth_client_id}"
      clientSecret: $${jenkins/oauth_client_secret}
security:
  queueItemAuthenticator:
    authenticators:
    - global:
        strategy:
          specificUsersAuthorizationStrategy:
            userid: "${admin_email}"
unclassified:
  defaultFolderConfiguration:
    healthMetrics:
    - "primaryBranchHealthMetric"
  location:
    adminAddress: "${admin_email}"
    url: "http://jenkins.${dns_name}/"
  timestamper:
    allPipelines: true

