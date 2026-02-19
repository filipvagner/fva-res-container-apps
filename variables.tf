variable "location" {
  description = "The Azure region where resources will be deployed."
  type        = string
}

variable "tags" {
  description = "A map of tags to assign to the resources."
  type        = map(string)
  default     = {}
}

variable "resource_group_name" {
  description = "The name of the resource group."
  type        = string
}

variable "log_analytics_workspace_id" {
  description = "The ID of the Log Analytics workspace."
  type        = string
}

variable "container_app_environment_name" {
  description = "The name of the Container App Environment."
  type        = string
}

variable "infrastructure_resource_group_enabled" {
  description = "Place resources in Azure managed resource group (false) or in the same resource group as the Container App Environment (true)."
  type        = bool
  default     = false
}

variable "container_app_environment_subnet_id" {
  description = "The subnet ID for the Container App Environment."
  type        = string
}

variable "container_app_environment_internal_load_balancer_enabled" {
  description = "Enable internal load balancer for the Container App Environment."
  type        = bool
  default     = true
}

variable "container_app_environment_zone_redundancy_enabled" {
  description = "Enable zone redundancy for the Container App Environment."
  type        = bool
  default     = false
}

variable "container_app_environment_workload_profile" {
  description = "Map of workload profiles for the Container App Environment."
  type = map(object({
    name                  = string
    workload_profile_type = string
    minimum_count         = number
    maximum_count         = number
  }))
  default = {
    "Consumption" = {
      name                  = "Consumption"
      workload_profile_type = "Consumption"
      minimum_count         = 0
      maximum_count         = 0
    }
  }
}

variable "diagnostic_setting_enabled" {
  description = "Enable diagnostic settings for the Container App Environment."
  type        = bool
  default     = false
}

variable "container_app" {
  description = "List of container app template configurations."
  type = map(object({
    name                  = string
    min_replicas          = optional(number, 0)
    max_replicas          = optional(number, 2)
    workload_profile_name = optional(string, "Consumption")
    container = map(object({
      name    = string
      image   = string
      cpu     = number
      memory  = string
      command = optional(list(string))
      args    = optional(list(string))
      env = optional(map(object({
        name        = string
        secret_name = optional(string)
        value       = optional(string)
      })), {})

    }))
    custom_scale_rule = optional(object({
      name             = string
      custom_rule_type = string
      metadata         = map(string)
    }))
    secret = optional(map(object({
      name                = string
      identity            = optional(string)
      key_vault_secret_id = optional(string)
      value               = optional(string)
    })), {})
    registry = optional(object({
      server               = string
      identity             = optional(string)
      username             = optional(string)
      password_secret_name = optional(string)
    }))
  }))
  default = {}
}
