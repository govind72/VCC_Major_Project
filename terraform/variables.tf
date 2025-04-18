variable "gcp_project" {
  description = "Your GCP project ID "
  type        = string
}

variable "gcp_region" {
  description = "Primary region (for master)"
  type        = string
  default     = "asia-south2"
}

variable "gcp_zone_master" {
  description = "Zone for master VM"
  type        = string
  default     = "asia-south2-a"
}

variable "gcp_zone_worker1" {
  description = "Zone for worker1 VM"
  type        = string
  default     = "us-east1-b"
}

variable "gcp_zone_worker2" {
  description = "Zone for worker2 VM"
  type        = string
  default     = "australia-southeast1-b"
}

variable "machine_type" {
  description = "Machine type for all VMs"
  type        = string
  default     = "e2-medium"
}

variable "ssh_pub_key_path" {
  description = "Path to your SSH public key"
  type        = string
  default     = "../ssh/gcp.pub"
}
