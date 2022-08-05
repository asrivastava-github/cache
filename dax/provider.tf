provider "aws" {
  region = var.region
  assume_role {
    role_arn = local.account_role_arns[var.environment]
  }
}
