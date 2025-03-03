variable "name" {
  description = "Name prefix for all resources created by this module"
  type        = string
}

variable "source_bucket_name" {
  description = "Name of the source bucket"
  type        = string
}

variable "dest_bucket_name" {
  description = "Name of the destination bucket"
  type        = string
}

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}

variable "enable_bucket_versioning" {
  description = "Enable versioning for both source and processed buckets"
  type        = bool
  default     = true
}
