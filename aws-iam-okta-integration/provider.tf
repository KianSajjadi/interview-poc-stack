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