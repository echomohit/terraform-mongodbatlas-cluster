resource "mongodbatlas_advanced_cluster" "this" {
  project_id             = var.project_id
  name                   = var.name
  cluster_type           = "REPLICASET"
  mongo_db_major_version = var.mongodb_version

  # null leaves the current Atlas setting untouched.
  termination_protection_enabled = var.termination_protection_enabled

  # Cloud backups must be enabled on the cluster for the backup schedule to apply.
  # null leaves the current Atlas setting untouched.
  backup_enabled = var.enable_backup ? true : null
  pit_enabled    = var.enable_backup ? var.enable_continuous_backup : null

  dynamic "advanced_configuration" {
    for_each = var.oplog_min_retention_hours != null ? [1] : []
    content {
      oplog_min_retention_hours = var.oplog_min_retention_hours
    }
  }

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

  # Users can reference custom roles, which must exist first.
  depends_on = [mongodbatlas_custom_db_role.this]

  project_id         = var.project_id
  username           = each.key
  auth_database_name = each.value.aws_iam_type != "NONE" ? "$external" : each.value.auth_database_name
  aws_iam_type       = each.value.aws_iam_type
  # try() rather than lookup(): a missing key must yield an unmarked null, or imported users
  # without a password plan a phantom update on the sensitive-marked null.
  password    = each.value.aws_iam_type != "NONE" ? null : try(var.database_user_passwords[each.key], null)
  description = each.value.description

  dynamic "roles" {
    for_each = each.value.roles
    content {
      role_name       = roles.value.role_name
      database_name   = roles.value.database_name
      collection_name = roles.value.collection_name
    }
  }

  dynamic "scopes" {
    for_each = each.value.scopes != null ? each.value.scopes : (
      each.value.scope_to_cluster ? [{ name = mongodbatlas_advanced_cluster.this.name, type = "CLUSTER" }] : []
    )
    content {
      name = scopes.value.name
      type = scopes.value.type
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

resource "mongodbatlas_custom_db_role" "this" {
  for_each = var.custom_db_roles

  project_id = var.project_id
  role_name  = each.key

  dynamic "actions" {
    for_each = each.value.actions
    content {
      action = actions.value.action

      dynamic "resources" {
        for_each = actions.value.resources
        content {
          cluster         = resources.value.cluster
          database_name   = resources.value.database_name
          collection_name = resources.value.collection_name
        }
      }
    }
  }

  dynamic "inherited_roles" {
    for_each = each.value.inherited_roles
    content {
      role_name     = inherited_roles.value.role_name
      database_name = inherited_roles.value.database_name
    }
  }
}

resource "mongodbatlas_project_ip_access_list" "this" {
  for_each = var.ip_access_list

  project_id = var.project_id
  cidr_block = can(regex("/", each.key)) ? each.key : null
  ip_address = can(regex("/", each.key)) ? null : each.key
  comment    = each.value.comment
}

resource "mongodbatlas_maintenance_window" "this" {
  count = var.maintenance_window != null ? 1 : 0

  project_id              = var.project_id
  day_of_week             = var.maintenance_window.day_of_week
  hour_of_day             = var.maintenance_window.hour_of_day
  auto_defer_once_enabled = var.maintenance_window.auto_defer_once_enabled

  dynamic "protected_hours" {
    for_each = var.maintenance_window.protected_hours != null ? [var.maintenance_window.protected_hours] : []
    content {
      start_hour_of_day = protected_hours.value.start_hour_of_day
      end_hour_of_day   = protected_hours.value.end_hour_of_day
    }
  }
}
