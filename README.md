# terraform-mongodbatlas-cluster

A Terraform module for provisioning a production-ready MongoDB Atlas cluster with optional PrivateLink, automated backup schedules, database users and roles, and project network access.

## Features

- Replica set cluster with configurable instance size, node count, and IOPS
- Compute and disk auto-scaling
- Optional PrivateLink endpoint (AWS, Azure, GCP)
- Configurable Cloud Backup Schedule with hourly, daily, weekly, and monthly policies
- Optional Continuous Cloud Backup (point-in-time restore) and cross-region backup copy
- Database users with SCRAM passwords or AWS IAM authentication, scoped to the cluster or an explicit list of clusters
- Custom database roles
- Project IP access list
- Project maintenance window with protected hours
- Termination protection and minimum oplog retention on the cluster
- Supports MongoDB 6.0, 7.0, and 8.0
- Plan-time validation for provider name, MongoDB version, and node count

## Authentication

Configure the `mongodbatlas` provider in your root module. The provider reads credentials from environment variables by default — the recommended approach:

```bash
export MONGODB_ATLAS_PUBLIC_KEY="your-public-key"
export MONGODB_ATLAS_PRIVATE_KEY="your-private-key"
```

```hcl
provider "mongodbatlas" {}

module "mongodb" {
  source = "<ORG>/<NAME>/mongodbatlas"
  # ...
}
```

Or pass credentials explicitly:

```hcl
provider "mongodbatlas" {
  public_key  = var.mongodb_atlas_public_key
  private_key = var.mongodb_atlas_private_key
}
```

## Usage

### Minimal

```hcl
provider "mongodbatlas" {}

module "mongodb" {
  source = "<ORG>/<NAME>/mongodbatlas"

  project_id = "your-atlas-project-id"
  name       = "my-cluster"
}
```

### With PrivateLink

```hcl
provider "mongodbatlas" {}

module "mongodb" {
  source = "<ORG>/<NAME>/mongodbatlas"

  project_id  = "your-atlas-project-id"
  name        = "my-cluster"
  region_name = "AP_SOUTH_1"
  region_code = "AP_SOUTH_1"

  enable_privatelink  = true
  endpoint_service_id = "vpce-svc-xxxxxxxxxxxxxxxxx"
}
```

### With Custom Backup Policies

```hcl
provider "mongodbatlas" {}

module "mongodb" {
  source = "<ORG>/<NAME>/mongodbatlas"

  project_id = "your-atlas-project-id"
  name       = "my-cluster"

  enable_backup       = true
  restore_window_days = 7

  backup_policies = {
    hourly = {
      retention_value    = 2
      retention_unit     = "days"
      frequency_interval = 6
    }
    daily = {
      retention_value    = 14
      retention_unit     = "days"
      frequency_interval = 1
    }
    weekly = {
      retention_value    = 4
      retention_unit     = "weeks"
      frequency_interval = 1
    }
    monthly = {
      retention_value    = 12
      retention_unit     = "months"
      frequency_interval = 1
    }
  }

  enable_backup_copy      = true
  backup_copy_region_name = "AP_SOUTHEAST_1"
}
```

See the [example](./example) directory for a complete runnable configuration.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| project_id | MongoDB Atlas project ID | `string` | n/a | yes |
| name | Name of the MongoDB cluster | `string` | n/a | yes |
| mongodb_version | MongoDB major version (6.0, 7.0, or 8.0) | `string` | `"8.0"` | no |
| provider_name | Cloud provider (AWS, AZURE, or GCP) | `string` | `"AWS"` | no |
| region_name | Cloud provider region name (e.g. AP_SOUTH_1) | `string` | `"AP_SOUTH_1"` | no |
| mongodb_atlas_config | Cluster sizing and scaling settings (see below) | `object` | see below | no |
| enable_privatelink | Create a PrivateLink endpoint and service | `bool` | `false` | no |
| region_code | Region code for the PrivateLink endpoint | `string` | `null` | no |
| endpoint_service_id | VPC endpoint service ID for PrivateLink | `string` | `null` | no |
| enable_backup | Enable cloud backups on the cluster and create a Cloud Backup Schedule | `bool` | `true` | no |
| enable_continuous_backup | Enable Continuous Cloud Backup (point-in-time restore); `null` leaves the Atlas setting unchanged | `bool` | `null` | no |
| restore_window_days | Days back in time available for point-in-time restore | `number` | `2` | no |
| backup_reference_hour_of_day | UTC hour (0–23) to start the backup window | `number` | `0` | no |
| backup_reference_minute_of_hour | UTC minute (0–59) to start the backup window | `number` | `0` | no |
| backup_policies | Map of backup policy items (hourly, daily, weekly, monthly) | `map(object)` | see below | no |
| enable_backup_copy | Copy backups to a secondary region | `bool` | `false` | no |
| backup_copy_region_name | Secondary region for backup copies | `string` | `null` | no |
| database_users | Map of database users keyed by username (see below) | `map(object)` | `{}` | no |
| database_user_passwords | Map of username to password for SCRAM users | `map(string)` (sensitive) | `{}` | no |
| custom_db_roles | Map of custom database roles keyed by role name (see below) | `map(object)` | `{}` | no |
| ip_access_list | Project IP access list keyed by CIDR block or IP address, with an optional `comment` | `map(object)` | `{}` | no |
| maintenance_window | Project maintenance window (see below); `null` leaves it under Atlas control | `object` | `null` | no |
| termination_protection_enabled | Block deletion of the cluster; `null` leaves the Atlas setting unchanged | `bool` | `null` | no |
| oplog_min_retention_hours | Minimum oplog retention window in hours; `null` leaves the Atlas setting unchanged | `number` | `null` | no |

### mongodb_atlas_config

| Name | Description | Type | Default |
|------|-------------|------|---------|
| instance_size | Atlas instance size (e.g. M10, M20, M30) | `string` | `"M10"` |
| node_count | Number of electable nodes — must be odd (3, 5, 7) | `number` | `3` |
| disk_iops | Provisioned IOPS | `number` | `3000` |
| ebs_volume_type | EBS volume type for AWS (STANDARD or PROVISIONED) | `string` | `null` |
| compute_scaling_enabled | Enable compute auto-scaling | `bool` | `true` |
| compute_scale_down_enabled | Enable scale-down as part of compute auto-scaling | `bool` | `true` |
| compute_max_instance_size | Maximum instance size for compute auto-scaling | `string` | `"M40"` |
| compute_min_instance_size | Minimum instance size for compute scale-down | `string` | `"M10"` |
| disk_gb_scaling_enabled | Enable disk auto-scaling | `bool` | `true` |

### backup_policies

Supported keys: `hourly`, `daily`, `weekly`, `monthly`. Omitting a key means that policy type is not created.

```hcl
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
```

### database_users

Keyed by username. Users are scoped to this cluster by default (`scope_to_cluster = true`). For AWS IAM authentication, use the IAM role/user ARN as the key and set `aws_iam_type`; `auth_database_name` is set to `$external` automatically and no password is needed.

| Name | Description | Type | Default |
|------|-------------|------|---------|
| roles | List of `{ role_name, database_name, collection_name }` | `list(object)` | n/a |
| auth_database_name | Authentication database for SCRAM users | `string` | `"admin"` |
| aws_iam_type | `NONE`, `USER`, or `ROLE` | `string` | `"NONE"` |
| description | User description | `string` | `null` |
| scope_to_cluster | Restrict the user to this cluster only | `bool` | `true` |
| scopes | List of `{ name, type }` (type `CLUSTER` or `DATA_LAKE`, default `CLUSTER`); overrides `scope_to_cluster`. `[]` grants access to every cluster in the project | `list(object)` | `null` |
| labels | Key/value labels | `map(string)` | `{}` |

```hcl
database_users = {
  "app-service" = {
    roles = [{ role_name = "readWrite", database_name = "app" }]
  }
  "arn:aws:iam::123456789012:role/app-task-role" = {
    aws_iam_type = "ROLE"
    roles        = [{ role_name = "read", database_name = "app" }]
  }
}
database_user_passwords = {
  "app-service" = var.app_service_db_password
}
```

To bring an existing user under Terraform, add it to `database_users` without a password and import it:

```bash
terraform import 'module.mongodb.mongodbatlas_database_user.this["app-service"]' '<PROJECT_ID>-app-service-admin'
```

With no password in config, Terraform leaves the user's existing password unchanged. Setting one later rotates it.

### custom_db_roles

Keyed by role name. Database users can reference these roles; the module creates roles before users. `actions` is an ordered list in the provider, so when importing an existing role, list the actions in the order the Atlas API returns them.

```hcl
custom_db_roles = {
  "app-maintenance" = {
    actions = [{
      action    = "COMPACT"
      resources = [{ database_name = "app", collection_name = "" }]
    }]
    inherited_roles = [{ role_name = "read", database_name = "app" }]
  }
}
```

### maintenance_window

`day_of_week` is 1 (Sunday) through 7 (Saturday). Hours are in the project's time zone.

```hcl
maintenance_window = {
  day_of_week     = 1
  hour_of_day     = 2
  protected_hours = { start_hour_of_day = 9, end_hour_of_day = 21 }
}
```

### Importing existing project resources

Terraform 1.5+ `import` blocks in the root module can target resources inside this module:

```hcl
import {
  to = module.mongodb.mongodbatlas_custom_db_role.this["app-maintenance"]
  id = "<PROJECT_ID>-app-maintenance"
}

import {
  to = module.mongodb.mongodbatlas_project_ip_access_list.this["10.0.0.0/16"]
  id = "<PROJECT_ID>-10.0.0.0/16"
}

import {
  to = module.mongodb.mongodbatlas_maintenance_window.this[0]
  id = "<PROJECT_ID>"
}
```

Declare `mongodb/mongodbatlas` in the root module's `required_providers` when using `import` blocks; otherwise Terraform resolves the import's provider as `hashicorp/mongodbatlas`.

## Outputs

| Name | Description | Sensitive |
|------|-------------|-----------|
| cluster_id | The ID of the MongoDB Atlas cluster | no |
| cluster_name | The name of the MongoDB Atlas cluster | no |
| cluster_state | The current state of the cluster | no |
| cluster_type | The type of the cluster | no |
| cluster_configuration | Summary of cluster configuration | no |
| connection_strings | All connection strings for the cluster | yes |
| mongo_uri | Standard SRV connection URI | yes |
| mongo_uri_private | Private SRV connection URI | yes |
| privatelink_endpoint_id | PrivateLink endpoint ID (null if disabled) | no |
| privatelink_endpoint_private_link_id | PrivateLink service ID (null if disabled) | no |
| privatelink_endpoint_service_id | PrivateLink endpoint service ID (null if disabled) | no |
| backup_schedule_id | Cloud Backup Schedule ID (null if disabled) | no |
| backup_schedule_details | Full backup schedule details (null if disabled) | yes |
| database_usernames | Usernames of the managed database users | no |
| custom_db_role_names | Names of the managed custom database roles | no |

## Requirements

| Name | Version |
|------|---------|
| Terraform | >= 1.0.0 |
| mongodb/mongodbatlas | ~> 1.34.0 |

## Notes

- The cluster type is fixed to `REPLICASET`. `node_count` must be an odd number — the module validates this at plan time.
- `instance_size` and `disk_size_gb` are always in `lifecycle.ignore_changes`. When auto-scaling is enabled, Atlas manages these values and Terraform will not revert them. To resize manually, change the size via the Atlas UI or API, then update your Terraform config to match.
- To import existing PrivateLink resources, fetch the `private_link_id` via the Atlas API:

```bash
curl --user "public-key:private-key" \
  --digest \
  --header "Accept: application/vnd.atlas.2025-03-12+json" \
  -X GET "https://cloud.mongodb.com/api/atlas/v2/groups/{PROJECT_ID}/privateEndpoint/AWS/endpointService"
```

## TODO

- Add support for multi-region replication specs
- Add support for sharded clusters
- Add support for VPC peering

## License

Apache License 2.0 — see [LICENSE](./LICENSE).
