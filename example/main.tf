# Configure the MongoDB Atlas provider here in your root module.
# Credentials are read from environment variables by default:
#   export MONGODB_ATLAS_PUBLIC_KEY="<your-public-key>"
#   export MONGODB_ATLAS_PRIVATE_KEY="<your-private-key>"
#
# Or pass them explicitly (see variables.tf).
provider "mongodbatlas" {
  public_key  = var.mongodb_atlas_public_key != "" ? var.mongodb_atlas_public_key : null
  private_key = var.mongodb_atlas_private_key != "" ? var.mongodb_atlas_private_key : null
}

module "mongodb" {
  source = "../"

  # Required
  project_id                = var.project_id
  name                      = var.name
  mongodb_atlas_public_key  = var.mongodb_atlas_public_key
  mongodb_atlas_private_key = var.mongodb_atlas_private_key

  # Optional — cloud provider and region
  mongodb_version = var.mongodb_version
  provider_name   = "AWS"
  region_name     = "AP_SOUTH_1"

  # Cluster sizing and auto-scaling
  mongodb_atlas_config = {
    compute_scaling_enabled    = true
    compute_scale_down_enabled = true
    compute_max_instance_size  = "M40"
    compute_min_instance_size  = "M10"
    disk_gb_scaling_enabled    = true
    instance_size              = "M10"
    node_count                 = 3
    disk_iops                  = 3000
  }

  # Backup schedule
  enable_backup                   = true
  restore_window_days             = 2
  backup_reference_hour_of_day    = 0
  backup_reference_minute_of_hour = 0
  backup_policies = {
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

  # Continuous Cloud Backup / point-in-time restore (optional)
  enable_continuous_backup = true

  # Cross-region backup copy (optional)
  enable_backup_copy      = false
  backup_copy_region_name = null

  # Database users (optional)
  database_users = {
    "app-service" = {
      roles = [{ role_name = "readWrite", database_name = "app" }]
    }
    # AWS IAM authentication — no password; the app authenticates with its IAM role.
    # "arn:aws:iam::123456789012:role/app-task-role" = {
    #   aws_iam_type = "ROLE"
    #   roles        = [{ role_name = "readWrite", database_name = "app" }]
    # }
  }
  database_user_passwords = {
    "app-service" = var.app_service_db_password
  }

  # PrivateLink (optional)
  enable_privatelink  = false
  endpoint_service_id = null
  region_code         = null
}
