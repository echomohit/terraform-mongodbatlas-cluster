resource "mongodbatlas_advanced_cluster" "this" {
  project_id             = var.project_id
  name                   = var.name
  cluster_type           = "REPLICASET"
  mongo_db_major_version = var.mongodb_version

  # Cloud backups must be enabled on the cluster for the backup schedule to apply.
  # null leaves the current Atlas setting untouched.
  backup_enabled = var.enable_backup ? true : null
  pit_enabled    = var.enable_backup ? var.enable_continuous_backup : null

  replication_specs {
    zone_name = "Zone 1"
    region_configs {
      priority      = 7
      provider_name = var.provider_name
      region_name   = var.region_name

      auto_scaling {
        compute_enabled            = var.mongodb_atlas_config.compute_scaling_enabled
        compute_max_instance_size  = var.mongodb_atlas_config.compute_scaling_enabled ? var.mongodb_atlas_config.compute_max_instance_size : null
        compute_min_instance_size  = var.mongodb_atlas_config.compute_scale_down_enabled ? var.mongodb_atlas_config.compute_min_instance_size : null
        compute_scale_down_enabled = var.mongodb_atlas_config.compute_scale_down_enabled
        disk_gb_enabled            = var.mongodb_atlas_config.disk_gb_scaling_enabled
      }

      electable_specs {
        disk_iops       = var.mongodb_atlas_config.disk_iops
        ebs_volume_type = var.mongodb_atlas_config.ebs_volume_type
        instance_size   = var.mongodb_atlas_config.instance_size
        node_count      = var.mongodb_atlas_config.node_count
      }

      analytics_specs {
        disk_iops       = var.mongodb_atlas_config.disk_iops
        ebs_volume_type = var.mongodb_atlas_config.ebs_volume_type
        instance_size   = var.mongodb_atlas_config.instance_size
        node_count      = 0
      }

      read_only_specs {
        disk_iops       = var.mongodb_atlas_config.disk_iops
        ebs_volume_type = var.mongodb_atlas_config.ebs_volume_type
        instance_size   = var.mongodb_atlas_config.instance_size
        node_count      = 0
      }
    }
  }

  lifecycle {
    # When compute or disk auto-scaling is enabled, Atlas updates instance_size and
    # disk_size_gb directly on the cluster. Ignoring these prevents Terraform from
    # reverting Atlas-managed changes on the next plan/apply.
    ignore_changes = [
      replication_specs[0].region_configs[0].electable_specs[0].instance_size,
      replication_specs[0].region_configs[0].electable_specs[0].disk_size_gb,
      replication_specs[0].region_configs[0].analytics_specs[0].instance_size,
      replication_specs[0].region_configs[0].analytics_specs[0].disk_size_gb,
      replication_specs[0].region_configs[0].read_only_specs[0].instance_size,
      replication_specs[0].region_configs[0].read_only_specs[0].disk_size_gb,
    ]
  }
}

resource "mongodbatlas_privatelink_endpoint" "this" {
  count         = var.enable_privatelink ? 1 : 0
  project_id    = var.project_id
  provider_name = var.provider_name
  region        = var.region_code

  timeouts {
    create = "30m"
    delete = "20m"
  }
}

resource "mongodbatlas_privatelink_endpoint_service" "this" {
  count               = var.enable_privatelink ? 1 : 0
  project_id          = var.project_id
  private_link_id     = mongodbatlas_privatelink_endpoint.this[0].private_link_id
  endpoint_service_id = var.endpoint_service_id
  provider_name       = var.provider_name
}

resource "mongodbatlas_cloud_backup_schedule" "this" {
  count        = var.enable_backup ? 1 : 0
  project_id   = mongodbatlas_advanced_cluster.this.project_id
  cluster_name = mongodbatlas_advanced_cluster.this.name

  reference_hour_of_day    = var.backup_reference_hour_of_day
  reference_minute_of_hour = var.backup_reference_minute_of_hour
  restore_window_days      = var.restore_window_days

  dynamic "copy_settings" {
    for_each = var.enable_backup_copy ? [1] : []
    content {
      cloud_provider     = var.provider_name
      frequencies        = ["WEEKLY"]
      region_name        = var.backup_copy_region_name
      should_copy_oplogs = false
      zone_id            = mongodbatlas_advanced_cluster.this.replication_specs.*.zone_id[0]
    }
  }

  dynamic "policy_item_hourly" {
    for_each = contains(keys(var.backup_policies), "hourly") ? [var.backup_policies["hourly"]] : []
    content {
      retention_value    = policy_item_hourly.value.retention_value
      retention_unit     = policy_item_hourly.value.retention_unit
      frequency_interval = policy_item_hourly.value.frequency_interval
    }
  }

  dynamic "policy_item_daily" {
    for_each = contains(keys(var.backup_policies), "daily") ? [var.backup_policies["daily"]] : []
    content {
      retention_value    = policy_item_daily.value.retention_value
      retention_unit     = policy_item_daily.value.retention_unit
      frequency_interval = policy_item_daily.value.frequency_interval
    }
  }

  dynamic "policy_item_weekly" {
    for_each = contains(keys(var.backup_policies), "weekly") ? [var.backup_policies["weekly"]] : []
    content {
      retention_value    = policy_item_weekly.value.retention_value
      retention_unit     = policy_item_weekly.value.retention_unit
      frequency_interval = policy_item_weekly.value.frequency_interval
    }
  }

  dynamic "policy_item_monthly" {
    for_each = contains(keys(var.backup_policies), "monthly") ? [var.backup_policies["monthly"]] : []
    content {
      retention_value    = policy_item_monthly.value.retention_value
      retention_unit     = policy_item_monthly.value.retention_unit
      frequency_interval = policy_item_monthly.value.frequency_interval
    }
  }
}

resource "mongodbatlas_database_user" "this" {
  for_each = var.database_users

  project_id         = var.project_id
  username           = each.key
  auth_database_name = each.value.aws_iam_type != "NONE" ? "$external" : each.value.auth_database_name
  aws_iam_type       = each.value.aws_iam_type
  password           = each.value.aws_iam_type != "NONE" ? null : lookup(var.database_user_passwords, each.key, null)
  description        = each.value.description

  dynamic "roles" {
    for_each = each.value.roles
    content {
      role_name       = roles.value.role_name
      database_name   = roles.value.database_name
      collection_name = roles.value.collection_name
    }
  }

  dynamic "scopes" {
    for_each = each.value.scope_to_cluster ? [1] : []
    content {
      name = mongodbatlas_advanced_cluster.this.name
      type = "CLUSTER"
    }
  }

  dynamic "labels" {
    for_each = each.value.labels
    content {
      key   = labels.key
      value = labels.value
    }
  }
}
