variable "confirm_paid_deployment" {
  description = "Keep false. Set true only for an approved apply of this stack."
  type        = bool
  default     = false
}

output "resource_count" {
  description = "Zero until a paid deployment is explicitly confirmed."
  value       = var.confirm_paid_deployment ? 1 : 0
}
