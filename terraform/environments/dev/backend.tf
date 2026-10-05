terraform {
  backend "s3" {
    bucket       = "tfstate-286325277771-eu-west-1"
    key          = "workload/dev/terraform.tfstate"
    region       = "eu-west-1"
    encrypt      = true
    use_lockfile = true
  }
}
