#region Container App Environment
resource "azurerm_container_app_environment" "this" {
  name                               = var.container_app_environment_name
  location                           = var.location
  resource_group_name                = var.resource_group_name
  infrastructure_resource_group_name = var.infrastructure_resource_group_enabled ? "${var.resource_group_name}-managed" : null
  infrastructure_subnet_id           = var.container_app_environment_subnet_id
  internal_load_balancer_enabled     = var.container_app_environment_internal_load_balancer_enabled
  zone_redundancy_enabled            = var.container_app_environment_zone_redundancy_enabled
  logs_destination                   = var.logs_destination != null ? var.logs_destination : null
  log_analytics_workspace_id         = var.logs_destination == "log-analytics" ? var.log_analytics_workspace_id : null
  mutual_tls_enabled                 = false
  tags                               = var.tags

  dynamic "workload_profile" {
    for_each = var.container_app_environment_workload_profile
    content {
      name                  = workload_profile.value.name
      workload_profile_type = workload_profile.value.workload_profile_type
      minimum_count         = workload_profile.value.minimum_count
      maximum_count         = workload_profile.value.maximum_count
    }
  }
}

resource "azurerm_monitor_diagnostic_setting" "this" {
  count = var.diagnostic_setting_enabled ? 1 : 0

  name                           = "diagnostic-${azurerm_container_app_environment.this.name}"
  target_resource_id             = azurerm_container_app_environment.this.id
  log_analytics_workspace_id     = var.log_analytics_workspace_id
  log_analytics_destination_type = "Dedicated"

  enabled_log {
    category_group = "allLogs"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}
#endregion Container App Environment

#region Container Apps
resource "azurerm_container_app" "this" {
  for_each = var.container_app

  container_app_environment_id = azurerm_container_app_environment.this.id
  name                         = each.value.name
  resource_group_name          = var.resource_group_name
  revision_mode                = "Single"
  tags                         = var.tags
  workload_profile_name        = each.value.workload_profile_name

  template {
    min_replicas = each.value.min_replicas
    max_replicas = each.value.max_replicas

    dynamic "container" {
      for_each = each.value.container
      content {
        name    = container.value.name
        image   = container.value.image
        cpu     = container.value.cpu
        memory  = container.value.memory
        command = try(container.value.command, null)
        args    = try(container.value.args, null)
        dynamic "env" {
          for_each = try(container.value.env, {})
          content {
            name        = env.value.name
            secret_name = try(env.value.secret_name, null)
            value       = try(env.value.value, null)
          }
        }
      }
    }

    dynamic "custom_scale_rule" {
      for_each = try(each.value.custom_scale_rule, null) != null ? [each.value.custom_scale_rule] : []
      content {
        name             = custom_scale_rule.value.name
        custom_rule_type = custom_scale_rule.value.custom_rule_type
        metadata         = custom_scale_rule.value.metadata
      }
    }
  }

  dynamic "registry" {
    for_each = try(each.value.registry, null) != null ? [each.value.registry] : []
    content {
      server               = try(registry.value.server, null)
      identity             = try(registry.value.identity, null)
      username             = try(registry.value.username, null)
      password_secret_name = try(registry.value.password_secret_name, null)
    }
  }

  dynamic "secret" {
    for_each = try(each.value.secret, {})
    content {
      name                = secret.value.name
      identity            = try(secret.value.identity, null)
      key_vault_secret_id = try(secret.value.key_vault_secret_id, null)
      value               = try(secret.value.value, null)
    }
  }
}
#endregion Container Apps

#region Container App Jobs
resource "azurerm_container_app_job" "this" {
  for_each = var.container_app_job

  container_app_environment_id = azurerm_container_app_environment.this.id
  name                         = each.value.name
  location                     = var.location
  resource_group_name          = var.resource_group_name
  replica_timeout_in_seconds   = each.value.replica_timeout_in_seconds
  replica_retry_limit          = each.value.replica_retry_limit
  tags                         = var.tags

  dynamic "registry" {
    for_each = try(each.value.registry, null) != null ? [each.value.registry] : []
    content {
      identity             = try(registry.value.identity, null)
      username             = try(registry.value.username, null)
      password_secret_name = try(registry.value.password_secret_name, null)
      server               = try(registry.value.server, null)
    }
  }

  dynamic "identity" {
    for_each = try(each.value.identity, null) != null ? [each.value.identity] : []
    content {
      type         = identity.value.type
      identity_ids = try(identity.value.identity_ids, null)
    }
  }

  dynamic "secret" {
    for_each = try(each.value.secret, null) != null ? each.value.secret : {}
    content {
      name                = secret.value.name
      identity            = try(secret.value.identity, null)
      key_vault_secret_id = try(secret.value.key_vault_secret_id, null)
      value               = try(secret.value.value, null)
    }
  }

  dynamic "event_trigger_config" {
    for_each = try(each.value.event_trigger_config, null) != null ? [each.value.event_trigger_config] : []
    content {
      parallelism              = try(event_trigger_config.value.parallelism, 1)
      replica_completion_count = try(event_trigger_config.value.replica_completion_count, 1)

      dynamic "scale" {
        for_each = try(event_trigger_config.value.scale, null) != null ? [event_trigger_config.value.scale] : []
        content {
          min_executions              = try(scale.value.min_executions, 0)
          max_executions              = try(scale.value.max_executions, 10)
          polling_interval_in_seconds = try(scale.value.polling_interval_in_seconds, 30)

          dynamic "rules" {
            for_each = try(scale.value.rules, [])
            content {
              name             = rules.value.name
              custom_rule_type = rules.value.custom_rule_type
              metadata         = rules.value.metadata

              dynamic "authentication" {
                for_each = try(rules.value.authentication, [])
                content {
                  secret_name       = authentication.value.secret_name
                  trigger_parameter = authentication.value.trigger_parameter
                }
              }
            }
          }
        }
      }
    }
  }

  template {
    container {
      image   = container.image
      name    = container.name
      cpu     = container.cpu
      memory  = container.memory
      command = try(container.command, null)
      args    = try(container.args, null)

      dynamic "env" {
        for_each = try(container.env, {})
        content {
          name        = env.value.name
          secret_name = try(env.value.secret_name, null)
          value       = try(env.value.value, null)
        }
      }
    }
  }
}
#endregion Container App Jobs
