variable "tags" {
  default = {
    "owner"   = "david.shea"
    "project" = "SPF-s3-replication"
    "client"  = "Arcade"
  }
}

variable "bucket_prefix" {
  default = "spf-test"
}

variable "source_account" {
  description = "ID of the source account"
}

variable "source_region" {
  default = "eu-west-2"
}

variable "source_profile" {
  description = "name of the source profile being used"
}

variable "dest_account" {
  description = "ID of the destination account"
}

variable "dest_region" {
  default = "us-west-2"
}

variable "dest_profile" {
  description = "name of the destination profile being used"
}

