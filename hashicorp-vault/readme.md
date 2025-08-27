# My Hashicorp POC for kubernetes
I'm doing this without a GitOPS implementation to keep things simple, the reason I chose kubernetes for this is because I am currently working on a kubernetes cluster on my homelab   
I've used some quite verbose naming in the roles and k8s manifests to make things easier for myself   

There's a number of ways I could deal with the dynamic password - be it:
  1. Kill the pod and restart it: `vault.hashicorp.com/agent-inject-command-db.env: "kill -TERM 1 || true"`
  2. Use a static role + scheduled rotation I believe vault has a **Database Static Role** which will sync it into a kubernetes secret and let a reloader restart pods (would have to add secretStoreRef into the deployment)   
  3. Something like PgBouncer or RDS proxy if i was on AWS
  4. Code my application to poll for updates somehow

  I like solution 4 quite a bit, but many of the applications running in my homelab aren't applications of my own design, I would have to either fork them and add that functionality in or just gracefully restart them

## CI/CD Workflow
This works with the assumption that the cicd-runner role for this repo exists with this trust policy:

```{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {
      "Federated": "arn:aws:iam::<ACCOUNT_ID>:oidc-provider/token.actions.githubusercontent.com"
    },
    "Action": "sts:AssumeRoleWithWebIdentity",
    "Condition": {
      "StringEquals": {
        "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
      },
      "StringLike": {
        "token.actions.githubusercontent.com:sub": "repo:<ORG>/<REPO>:ref:refs/heads/main"
      }
    }
  }]
}
```

Allowing for the repo to use Github OIDC + AWS Iam to allow the workflow to have access to AWS with the following permissions policy: 

```
{
  "Version": "2012-10-17",
  "Statement": [
    { "Effect": "Allow", "Action": [
        "ecr:GetAuthorizationToken"
      ], "Resource": "*" },
    { "Effect": "Allow", "Action": [
        "ecr:BatchCheckLayerAvailability","ecr:CompleteLayerUpload","ecr:CreateRepository",
        "ecr:DescribeImages","ecr:DescribeRepositories","ecr:GetDownloadUrlForLayer",
        "ecr:InitiateLayerUpload","ecr:ListImages","ecr:PutImage","ecr:UploadLayerPart"
      ], "Resource": "arn:aws:ecr:ap-southeast-2:<ACCOUNT_ID>:repository/*" }
  ]
}
```

I was initially planning on using hashicorp vault to pass AWS credentials to github actions but there's no need with the github + aws oidc auth,
however the manifests for the application integrate the vault agent and use that to manage dynamic secrets between the app and db


## Hashicorp Vault in kubernetes
This would also require me do some one-off configuration in hashicorp vault - which according to the [docs page](https://developer.hashicorp.com/vault/tutorials/db-credentials/database-secrets) looks like this:

1. Setup DB engine 
`vault secrets enable database`
```
vault write database/config/my-go-app-pg \
  plugin_name=postgresql-database-plugin \
  allowed_roles="my-go-app-vault-role" \
  connection_url="postgresql://{{username}}:{{password}}@postgres.postgres.svc.cluster.local:5432/postgres?sslmode=disable" \
  username="vault_admin" \
  password="vault_pass"`
```

```
vault write database/roles/my-go-app-vault-role \
  db_name=my-go-app-pg \
  default_ttl=30m \
  max_ttl=1h \
  creation_statements="
    CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}';
    GRANT CONNECT ON DATABASE my-go-app-pg TO \"{{name}}\"; 
    GRANT USAGE ON SCHEMA public TO \"{{name}}\"; 
    GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO \"{{name}}\"; 
    ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO \"{{name}}\";"
```

I would of course need to setup a policy for my-go-app

my-go-app.hcl
```
path "database/creds/my-go-app-vault-role" {
  capabilities = ["read"]
}
```
and run: `vault policy write my-go-app-vault-role-policy my-go-app.hcl`

Kubernetes also needs auth, thus:

`vault auth enable kubernetes`

```
vault write auth/kubernetes/config \
  kubernetes_host="https://$KUBERNETES_URL:443 \
  kubernetes_ca_cert=@/var/run/secrets/kubernetes.i/serviceaccount/ca.crt
```

```
vault write auth/kubernetes/role/my-go-app-vault-role \
  bound_service_account_names=my-go-app-serviceaccount \
  bound_service_account_namespaces=spoolman \
  policies=my-go-app-vault-role-policy \
  ttl=1h
```

