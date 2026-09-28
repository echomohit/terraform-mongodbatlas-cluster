variable "project_id" {
  description = "MongoDB Atlas project ID"
  type        = string
}

variable "name" {
  description = "Name of the MongoDB cluster"
  type        = string
  default     = "example-cluster"
}

variable "mongodb_version" {
  description = "Major version of MongoDB (6.0, 7.0, or 8.0)"
  type        = string
  default     = "8.0"
}

variable "mongodb_atlas_public_key" {
  description = "MongoDB Atlas public API key. Leave empty to use MONGODB_ATLAS_PUBLIC_KEY env var."
  type        = string
  sensitive   = true
  default     = ""
}

variable "mongodb_atlas_private_key" {
  description = "MongoDB Atlas private API key. Leave empty to use MONGODB_ATLAS_PRIVATE_KEY env var."
  type        = string
  sensitive   = true
  default     = ""
}

variable "app_service_db_password" {
  description = "Password for the example app-service database user"
  type        = string
  sensitive   = true
}
