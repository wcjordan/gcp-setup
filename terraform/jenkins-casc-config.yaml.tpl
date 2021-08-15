credentials:
  system:
    domainCredentials:
      - credentials:
        - googleRobotPrivateKey:
            projectId: "${project_id}"
            serviceAccountConfig:
              json:
                secretJsonKey: "${google_service_account_key}"
        - browserStack:
            accesskey: "${browserstack_access_key}"
            description: "Browserstack credentials"
            id: "${browserstack_id}"
            username: "${browserstack_username}"
jenkins:
  authorizationStrategy:
    globalMatrix:
      permissions:
      - "Overall/Administer:${admin_email}"
  clouds:
  - kubernetes:
      containerCap: 2
      containerCapStr: "2"
      credentialsId: "${project_id}"
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
      clientSecret: "${oauth_client_secret}"
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

