# Terraform state file

terraform {
    backend "s3" {
        bucket ="grk-my-tf-website-state"
        key = "global/s3/terraform.tfstate"
        region = "us-east-2"
        dynamodb_table = "grk-db-website-table"
    }
}
