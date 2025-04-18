
data "google_client_openid_userinfo" "me" {}

resource "google_os_login_ssh_public_key" "default" {
  user = data.google_client_openid_userinfo.me.email
  key  = file(var.ssh_pub_key_path)
}

# -----------------------------------------------------------------------------
# 1. Master node
# -----------------------------------------------------------------------------
resource "google_compute_instance" "master" {
  name = "kube-master"
  zone = var.gcp_zone_master
  machine_type = var.machine_type

  # ────────── Kubernetes requires IP forwarding enabled ──────────
  can_ip_forward     = true            # ← allow pods’ traffic to be forwarded
  deletion_protection = false          # ← optional, prevents accidental delete
  allow_stopping_for_update = true
  boot_disk {
    initialize_params {
      image = "projects/ubuntu-os-cloud/global/images/ubuntu-2204-jammy-v20231030"
      size  = 50
      type  = "pd-balanced"
    }
  }

  network_interface {
    subnetwork    = "projects/${var.gcp_project}/regions/asia-south2/subnetworks/default"
    access_config {}                   # ← gives it an external IP
  }

  # ────────── Optional VM metadata & hostname ──────────
  metadata = {
    enable-oslogin = "true"
  }
  hostname = "kube-master.vcc"         # ← sets the VM’s hostname

  # ────────── Tags for firewall rules ──────────
  # If you’ve got firewall rules that allow HTTP/HTTPS or LB health checks,
  # tagging helps GCP apply them.
  tags = [
    "kube",
    "http-server",
    "https-server",
    "lb-health-check",
  ]
}

# -----------------------------------------------------------------------------
# 2. Worker 1
# -----------------------------------------------------------------------------
resource "google_compute_instance" "worker1" {
  name               = "kube-worker1"
  zone               = var.gcp_zone_worker1
  machine_type       = var.machine_type

  can_ip_forward     = true
  deletion_protection = false
  allow_stopping_for_update = true
  boot_disk {
    initialize_params {
      image = "projects/ubuntu-os-cloud/global/images/ubuntu-2204-jammy-v20231030"
      size          = 50
      type          = "pd-balanced"
    }
  }

  network_interface {
    subnetwork    = "projects/${var.gcp_project}/regions/us-east1/subnetworks/default"
    access_config {}
  }

  metadata = { enable-oslogin = "true" }
  hostname = "kube-worker1.vcc"

  tags = [
    "kube",
    "lb-health-check",
  ]
}

# -----------------------------------------------------------------------------
# 3. Worker 2
# -----------------------------------------------------------------------------
resource "google_compute_instance" "worker2" {
  name               = "kube-worker2"
  zone               = var.gcp_zone_worker2
  machine_type       = var.machine_type

  can_ip_forward     = true
  deletion_protection = false
  allow_stopping_for_update = true
  boot_disk {
    initialize_params {
      image = "projects/ubuntu-os-cloud/global/images/ubuntu-2204-jammy-v20231030"
      size          = 50
      type          = "pd-balanced"
    }
  }

  network_interface {
    subnetwork    = "projects/${var.gcp_project}/regions/australia-southeast1/subnetworks/default"
    access_config {}
  }

  metadata = { enable-oslogin = "true" }
  hostname = "kube-worker2.vcc"

  tags = [
    "kube",
    "lb-health-check",
  ]
}
