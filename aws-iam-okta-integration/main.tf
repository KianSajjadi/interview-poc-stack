terraform {
  required_version = "1.5.1"
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "5.0"
    }
    okta = {
      source = "okta/okta"
      version = "~> 4.6.1"
    }
  }
}
# mock up with no credentials
provider "aws" {
  region = "ap-southeast-2"
}

provider "okta" {
  org_name = "kiansajjadiorg"
  base_url = "kiansajjadiorg.oktapreview.com"
  http_proxy = "custom url endpoint for unit testing or local caching proxies"
  api_token = "my api token"
  scopes = "[COMMA,SEPARATED,SCOPE,VALUES]"
}

# Okta saml app for aws preconfigured application
resource "okta_app_saml" "okta" {
  # Application's name
  label = "AWS Iam Identity Center"
  # Disable self service
  accessibility_self_service = false
  # Display specific appLinks for the app - each value should be a boolean
  app_links_json = jsonencode({
    login = true
  })

  assertion_signed = false
  auto_submit_toolbar = true
  default_relay_state = "https://ap-southeast-2.console.aws.amazon.com/"
  hide_ios = false
  hide_web = false
  # According to the okta provider if a preconfigured_app is used the following block of attributes are optional
  preconfigured_app = "amazon_aws"

  # I believe these are not required if using the amazon_aws preconfigured application but I may be wrong - it is stated these are required if preconfigured_app is not defined however that doesn't mean
  # theyre _not_ required if the preconfigured_app is set
  sso_url = "AWS ACS URL"
  recipient = "AWS ACS URL"
  destination = "AWS ACS URL"
  audience = "AWS ENTITY ID FROM AWS METADATA"
  subject_name_id_template = "${user.email}"
  # is the following meant to be 1.1 or 2.0? ,
  subject_name_id_format = "urn:oasis:names:tc:SAML:1.1?:nameid-format:emailAddress"
  # can these two following be ed25519?
  signature_algorithm = "RSA_SHA256"
  digest_algorithm = "SHA256"
  authn_context_class_ref = "urn:oasis:names:tc:SAML:2.0:ac:classes:PasswordProtectedTransport"

  # SAML auth response is digitally signed
  response_signed = true
}

# Define an okta group to the SAML app and assign it to the okta app
resource "okta_app_group" "aws_readonly" {
  name = "aws_readonly"
  description = "read-only access to aws"
}

resource "okta_app_group_assigment" "aws_readonly" {
  app_id = okta_app_saml.okta
  group_id = okta_group.readonly.id
}

# Mock users for the above group - depending on how users are managed, if via terraform I would have these as an encrypted list and use terraform's loops to simplify it
resource "okta_user" "user_1" {
  first_name = "kian"
  last_name = "sajjadi"
  login = "kian.s.sajjadi@gmail.com"
  email = "kian.s.sajjadi@gmail.com"

  #ignoring optionals for timebeing e.g. display name, employee number, etc.
}

resource "okta_user" "user_2" {
  first_name = "not_kian"
  last_name = "not_sajjadi"
  login = "not.kian.s.sajjadi@gmail.com"
  email = "not.kian.s.sajjadi@gmail.com"

  #ignoring optionals for timebeing e.g. display name, employee number, etc.
}

resource "okta_group_memberships" "readonly_group" {
  group_id = okta_app_group.aws_readonly
  users = [
    okta_user.user_1.id,
    okta_user.user_2.id
  ]
}

# #################################### AWS ################################### #
data "aws_ssoadmin_instances" "aws_sso" {}

data "aws_identitystore_group" "devs" {
  identity_store_id = "identity store id"
  filter {
    attribute_path  = "DisplayName"
    attribute_value = "Developers"
  }
}

resource "aws_ssoadmin_account_assignment" "devs_sandbox" {
  instance_arn       = "sso instnace arn"
  permission_set_arn = aws_ssoadmin_permission_set.poweruser.arn
  principal_type     = "GROUP"
  principal_id       = data.aws_identitystore_group.devs.id
  target_type        = "AWS_ACCOUNT"
  target_id          = "111122223333"
}