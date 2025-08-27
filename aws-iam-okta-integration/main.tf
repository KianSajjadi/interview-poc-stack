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
resource "okta_app_saml" "example_okta_app" {
  provider = okta
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
  sso_url = "AWS ACS URL"
  recipient = "AWS ACS URL"
  destination = "AWS ACS URL"
  audience = "AWS ENTITY ID FROM AWS METADATA"
  preconfigured_app = "amazon_aws"

  #I believe these are not required if using the amazon_aws preconfigured application but I may be wrong
  subject_name_id_template = "${user.email}"
  subject_name_id_format = "urn:oasis:names:tc:SAML:1.1:nameid-format:emailAddress"
  response_signed = true
}

resource ""