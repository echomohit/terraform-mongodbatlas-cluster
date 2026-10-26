variable "project_id" {
  description = "MongoDB Atlas project ID"
  type        = string
}

variable "name" {
  description = "Name of the MongoDB cluster"
  type        = string
}

variable "mongodb_version" {
  description = "Major version of MongoDB to deploy (6.0, 7.0, or 8.0)"
  type        = string
  default     = "8.0"

  validation {
    condition     = contains(["6.0", "7.0", "8.0"], var.mongodb_version)
    error_message = "Supported MongoDB versions are 6.0, 7.0, and 8.0."
  }
}

variable "provider_name" {
  description = "Cloud provider for the cluster (AWS, AZURE, or GCP)"
  type        = string
  default     = "AWS"

  validation {
    condition     = contains(["AWS", "AZURE", "GCP"], var.provider_name)
    error_message = "Supported cloud providers are AWS, AZURE, and GCP."
  }
}

variable "region_name" {
  description = "Cloud provider region name for the cluster (e.g. AP_SOUTH_1 for AWS, INDIA_CENTRAL for Azure)"
  type        = string
  default     = "AP_SOUTH_1"
}

variable "region_code" {
  description = "Region code used for the PrivateLink endpoint (e.g. AP_SOUTH_1). Required when enable_privatelink = true."
  type        = string
  default     = null
}

variable "mongodb_atlas_config" {
  description = "Configuration settings for the MongoDB Atlas cluster"
  type = object({
    compute_scaling_enabled    = optional(bool, true)
    compute_scale_down_enabled = optional(bool, true)
    compute_max_instance_size  = optional(string, "M40")
    compute_min_instance_size  = optional(string, "M10")
    disk_gb_scaling_enabled    = optional(bool, true)
    ebs_volume_type            = optional(string, null)
    instance_size              = optional(string, "M10")
    node_count                 = optional(number, 3)
    disk_iops                  = optional(number, 3000)
  })
  default = {}

  validation {
    condition     = var.mongodb_atlas_config.node_count % 2 != 0
    error_message = "Node count must be an odd number (3, 5, 7, ...) as required by MongoDB replica sets."
  }
}

# PrivateLink

variable "enable_privatelink" {
  description = "Whether to create a PrivateLink endpoint and service. Requires endpoint_service_id and region_code when true."
  type        = bool
  default     = false
}

variable "endpoint_service_id" {
  description = "VPC endpoint service ID (AWS VPC endpoint, Azure Private Endpoint, or GCP endpoint). Required when enable_privatelink = true."
  type        = string
  default     = null
}

# Backup

variable "enable_backup" {
  description = "Whether to create a Cloud Backup Schedule. When false, no backup resources are created."
  type        = bool
  default     = true
}

variable "enable_continuous_backup" {
  description = "Whether to enable Continuous Cloud Backup (point-in-time restore) on the cluster. Required for restore_window_days to take effect. null leaves the current Atlas setting untouched."
  type        = bool
  default     = null
}

variable "restore_window_days" {
  description = "Number of days back in time you can restore to with Continuous Cloud Backup."
  type        = number
  default     = 2
}

variable "backup_reference_hour_of_day" {
  description = "UTC hour of day (0–23) when Atlas starts the backup snapshot window."
  type        = number
  default     = 0

  validation {
    condition     = var.backup_reference_hour_of_day >= 0 && var.backup_reference_hour_of_day <= 23
    error_message = "Backup reference hour must be between 0 and 23."
  }
}

variable "backup_reference_minute_of_hour" {
  description = "UTC minute of the hour (0–59) when Atlas starts the backup snapshot window."
  type        = number
  default     = 0

  validation {
    condition     = var.backup_reference_minute_of_hour >= 0 && var.backup_reference_minute_of_hour <= 59
    error_message = "Backup reference minute must be between 0 and 59."
  }
}

variable "enable_backup_copy" {
  description = "Whether to copy backups to a secondary region. Requires backup_copy_region_name when true."
  type        = bool
  default     = false
}

variable "backup_copy_region_name" {
  description = "Region to copy backups to. Required when enable_backup_copy = true."
  type        = string
  default     = null
}

variable "mongodb_atlas_public_key" {
  description = "The public key for the MongoDB Atlas API."
  type        = string
  sensitive   = true
}

variable "mongodb_atlas_private_key" {
  description = "The private key for the MongoDB Atlas API."
  type        = string
  sensitive   = true
}

variable "backup_policies" {
  description = <<-EOT
    Map of backup policy items by frequency type. Supported keys: hourly, daily, weekly, monthly.
    Omitting a key means that policy type will not be created.

    Example:
    {
      daily  = { retention_value = 10, retention_unit = "days", frequency_interval = 1 }
      hourly = { retention_value = 2,  retention_unit = "days", frequency_interval = 12 }
    }
  EOT
  type = map(object({
    retention_value    = number
    retention_unit     = string
    frequency_interval = number
  }))
  default = {
    daily = {
      retention_value    = 10
      retention_unit     = "days"
      frequency_interval = 1
    }
    hourly = {
      retention_value    = 2
      retention_unit     = "days"
      frequency_interval = 12
    }
  }
}

# Database users

variable "database_users" {
  description = <<-EOT
    Map of database users to manage, keyed by username. For AWS IAM authentication, the key is the
    IAM role or user ARN and auth_database_name is forced to "$external".

    Passwords for SCRAM users are passed separately through database_user_passwords so this map stays
    non-sensitive. Omit a user's password only when importing an existing user whose password should
    be left unchanged.

    scopes overrides scope_to_cluster when set: [] means all clusters and data lakes in the project, or
    list the clusters (type = "CLUSTER") / data lakes (type = "DATA_LAKE") the user may access.

    Example:
    {
      "app-service" = {
        roles = [{ role_name = "readWrite", database_name = "app" }]
      }
      "arn:aws:iam::123456789012:role/app-task-role" = {
        aws_iam_type = "ROLE"
        roles        = [{ role_name = "readWrite", database_name = "app" }]
      }
    }
  EOT
  type = map(object({
    auth_database_name = optional(string, "admin")
    aws_iam_type       = optional(string, "NONE")
    description        = optional(string)
    scope_to_cluster   = optional(bool, true)
    scopes = optional(list(object({
      name = string
      type = optional(string, "CLUSTER")
    })))
    labels = optional(map(string), {})
    roles = list(object({
      role_name       = string
      database_name   = string
      collection_name = optional(string)
    }))
  }))
  default = {}

  validation {
    condition     = alltrue([for u in values(var.database_users) : contains(["NONE", "USER", "ROLE"], u.aws_iam_type)])
    error_message = "aws_iam_type must be one of NONE, USER, or ROLE."
  }

  validation {
    condition     = alltrue([for u in values(var.database_users) : length(u.roles) > 0])
    error_message = "Each database user must have at least one role."
  }
}

variable "database_user_passwords" {
  description = "Map of username to password for SCRAM (non-IAM) users in database_users."
  type        = map(string)
  default     = {}
  sensitive   = true
}

# Cluster settings

variable "termination_protection_enabled" {
  description = "Whether to block deletion of the cluster. null leaves the current Atlas setting untouched."
  type        = bool
  default     = null
}

variable "oplog_min_retention_hours" {
  description = "Minimum oplog retention window in hours. null leaves the current Atlas setting untouched."
  type        = number
  default     = null
}

# Project access

variable "custom_db_roles" {
  description = <<-EOT
    Map of custom database roles keyed by role name. actions keeps the order Atlas returns them in,
    so list them in that order when importing existing roles to avoid a spurious diff.

    Example:
    {
      "app-compact" = {
        actions = [{
          action    = "COMPACT"
          resources = [{ database_name = "app", collection_name = "" }]
        }]
        inherited_roles = [{ role_name = "read", database_name = "app" }]
      }
    }
  EOT
  type = map(object({
    actions = optional(list(object({
      action = string
      resources = list(object({
        cluster         = optional(bool)
        database_name   = optional(string)
        collection_name = optional(string)
      }))
    })), [])
    inherited_roles = optional(list(object({
      role_name     = string
      database_name = string
    })), [])
  }))
  default = {}

  validation {
    condition     = alltrue([for r in values(var.custom_db_roles) : length(r.actions) + length(r.inherited_roles) > 0])
    error_message = "Each custom role must have at least one action or inherited role."
  }
}

variable "ip_access_list" {
  description = "Project IP access list keyed by CIDR block (e.g. 10.0.0.0/16) or single IP address."
  type = map(object({
    comment = optional(string)
  }))
  default = {}
}

variable "maintenance_window" {
  description = <<-EOT
    Project maintenance window. null leaves the window under Atlas control. day_of_week is 1 (Sunday)
    through 7 (Saturday); hours are in the project's time zone. protected_hours blocks Atlas from
    starting urgent maintenance during that range.
  EOT
  type = object({
    day_of_week             = number
    hour_of_day             = optional(number)
    auto_defer_once_enabled = optional(bool)
    protected_hours = optional(object({
      start_hour_of_day = number
      end_hour_of_day   = number
    }))
  })
  default = null

  validation {
    condition     = var.maintenance_window == null || try(var.maintenance_window.day_of_week >= 1 && var.maintenance_window.day_of_week <= 7, false)
    error_message = "maintenance_window.day_of_week must be between 1 (Sunday) and 7 (Saturday)."
  }
}
