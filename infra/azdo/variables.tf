# Terraform's two inputs, which keep this environment's names out of these files (docs/adr/0012).
# Pipeline azdo-terraform sets them from variable group azdo. A run by hand asks for them, unless
# TF_VAR_workload and TF_VAR_sonar_project_key are set.

variable "workload" {
  description = "The word in this environment's Azure resource names, as in rg-<workload>-registry"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]{3,20}$", var.workload))
    error_message = "The workload must be 3 to 20 lowercase letters or digits."
  }
}

variable "sonar_project_key" {
  description = "The key of the SonarQube Cloud project that pipeline build-groundwerk analyzes"
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9_.:-]+$", var.sonar_project_key))
    error_message = "The SonarQube Cloud project key must be letters, digits, _, ., : or -."
  }
}
