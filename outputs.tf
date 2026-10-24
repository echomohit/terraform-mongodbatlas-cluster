output "cluster_id" {
  description = "The ID of the MongoDB Atlas cluster"
  value       = mongodbatlas_advanced_cluster.this.id
}

output "cluster_name" {
  description = "The name of the MongoDB Atlas cluster"
  value       = mongodbatlas_advanced_cluster.this.name
}

output "connection_strings" {
  description = "The connection strings for the MongoDB Atlas cluster"
  value       = mongodbatlas_advanced_cluster.this.connection_strings
  sensitive   = true
}

output "mongo_uri" {
  description = "The standard SRV connection URI"
  value       = mongodbatlas_advanced_cluster.this.connection_strings[0].standard_srv
  sensitive   = true
}

output "mongo_uri_private" {
  description = "The private SRV connection URI (null if PrivateLink is not configured)"
  value       = try(mongodbatlas_advanced_cluster.this.connection_strings[0].private_srv, null)
  sensitive   = true
}

output "cluster_state" {
  description = "The current state of the MongoDB Atlas cluster"
  value       = mongodbatlas_advanced_cluster.this.state_name
}

output "cluster_type" {
  description = "The type of the MongoDB Atlas cluster"
  value       = mongodbatlas_advanced_cluster.this.cluster_type
}

output "privatelink_endpoint_id" {
  description = "The ID of the PrivateLink endpoint (null if PrivateLink is disabled)"
  value       = var.enable_privatelink ? mongodbatlas_privatelink_endpoint.this[0].id : null
}

output "privatelink_endpoint_private_link_id" {
  description = "The PrivateLink service ID (null if PrivateLink is disabled)"
  value       = var.enable_privatelink ? mongodbatlas_privatelink_endpoint.this[0].private_link_id : null
}

output "privatelink_endpoint_service_id" {
  description = "The ID of the PrivateLink endpoint service (null if PrivateLink is disabled)"
  value       = var.enable_privatelink ? mongodbatlas_privatelink_endpoint_service.this[0].id : null
}

output "backup_schedule_id" {
  description = "The ID of the Cloud Backup Schedule (null if backup is disabled)"
  value       = var.enable_backup ? mongodbatlas_cloud_backup_schedule.this[0].id : null
}

output "backup_schedule_details" {
  description = "Full details of the Cloud Backup Schedule (null if backup is disabled)"
  value       = var.enable_backup ? mongodbatlas_cloud_backup_schedule.this[0] : null
  sensitive   = true
}

output "cluster_configuration" {
  description = "Summary of the cluster configuration"
  value = {
    name                = mongodbatlas_advanced_cluster.this.name
    id                  = mongodbatlas_advanced_cluster.this.id
    version             = mongodbatlas_advanced_cluster.this.mongo_db_major_version
    provider            = var.provider_name
    region              = var.region_name
    instance_size       = var.mongodb_atlas_config.instance_size
    node_count          = var.mongodb_atlas_config.node_count
    backup_enabled      = var.enable_backup
    privatelink_enabled = var.enable_privatelink
  }
}

output "database_usernames" {
  description = "Usernames of the database users managed by this module"
  value       = [for u in mongodbatlas_database_user.this : u.username]
}
