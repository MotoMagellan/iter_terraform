variable "config_repo_files" {
  description = "Map of Git providers (github/gitlab) to their repository file configurations"
  type = map(list(object({
    repository = optional(string)
    branch     = optional(string)
    file_path  = string
    project    = optional(string)
    ref        = optional(string)
  })))
}

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}

variable "default_config_branch" {
  description = "The default branch that config files should be queried from"
  type        = string
  default     = "main"
}
