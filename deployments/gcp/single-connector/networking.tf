/*
 * Copyright (c) 2019 Teradici Corporation
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

data "http" "myip" {
  url = "https://ipinfo.io/ip"
}

resource "google_compute_network" "vpc" {
  name                    = "${local.prefix}${var.teradici_network}"
  auto_create_subnetworks = "false"
}

resource "google_dns_managed_zone" "private_zone" {
  provider    = "google-beta"

  name        = replace("${local.prefix}${var.domain_name}-zone", ".", "-")
  dns_name    = "${var.domain_name}."
  description = "Private forwarding zone for ${var.domain_name}"

  visibility  = "private"

  private_visibility_config {
    networks {
      network_url = google_compute_network.vpc.self_link
    }
  }

  forwarding_config {
    target_name_servers {
      ipv4_address = var.dc_private_ip
    }
  }
}

resource "google_dns_managed_zone" "private_zone_workstations" {
  provider    = "google-beta"

  name        = replace("${local.prefix}${var.domain_name}-zone-${var.workstations_network}", ".", "-")
  dns_name    = "${var.domain_name}."
  description = "Private peering zone for ${var.domain_name} workstations"

  visibility  = "private"

  private_visibility_config {
    networks {
      network_url = google_compute_network.workstations.self_link
    }
  }

  peering_config {
    target_network {
      network_url = google_compute_network.vpc.self_link
    }
  }
}

resource "google_compute_firewall" "allow-internal" {
  name    = "${local.prefix}fw-allow-internal"
  network = google_compute_network.vpc.self_link

  allow {
    protocol = "icmp"
  }
  allow {
    protocol = "tcp"
    ports    = ["1-65535"]
  }
  allow {
    protocol = "udp"
    ports    = ["1-65535"]
  }

  source_ranges = [var.dc_subnet_cidr, var.cac_subnet_cidr, var.ws_subnet_cidr]
}

resource "google_compute_firewall" "allow-ssh" {
  name    = "${local.prefix}fw-allow-ssh"
  network = google_compute_network.vpc.self_link

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  target_tags   = ["${local.prefix}tag-ssh"]
  source_ranges = concat([chomp(data.http.myip.body)], var.allowed_cidr)
}

resource "google_compute_firewall" "allow-http" {
  name    = "${local.prefix}fw-allow-http"
  network = google_compute_network.vpc.self_link

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }

  target_tags   = ["${local.prefix}tag-http"]
  source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_firewall" "allow-https" {
  name    = "${local.prefix}fw-allow-https"
  network = google_compute_network.vpc.self_link

  allow {
    protocol = "tcp"
    ports    = ["443"]
  }

  target_tags   = ["${local.prefix}tag-https"]
  source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_firewall" "allow-rdp" {
  name    = "${local.prefix}fw-allow-rdp"
  network = google_compute_network.vpc.self_link

  allow {
    protocol = "tcp"
    ports    = ["3389"]
  }
  allow {
    protocol = "udp"
    ports    = ["3389"]
  }

  target_tags   = ["${local.prefix}tag-rdp"]
  source_ranges = concat([chomp(data.http.myip.body)], var.allowed_cidr)
}

resource "google_compute_firewall" "allow-winrm" {
  name    = "${local.prefix}fw-allow-winrm"
  network = google_compute_network.vpc.self_link

  allow {
    protocol = "tcp"
    ports    = ["5985-5986"]
  }

  target_tags   = ["${local.prefix}tag-winrm"]
  source_ranges = concat([chomp(data.http.myip.body)], var.allowed_cidr)
}

resource "google_compute_firewall" "allow-icmp" {
  name    = "${local.prefix}fw-allow-icmp"
  network = google_compute_network.vpc.self_link

  allow {
    protocol = "icmp"
  }

  target_tags   = ["${local.prefix}tag-icmp"]
  source_ranges = concat([chomp(data.http.myip.body)], var.allowed_cidr)
}

resource "google_compute_firewall" "allow-pcoip" {
  name    = "${local.prefix}fw-allow-pcoip"
  network = google_compute_network.vpc.self_link

  allow {
    protocol = "tcp"
    ports    = ["4172"]
  }
  allow {
    protocol = "udp"
    ports    = ["4172"]
  }

  target_tags   = ["${local.prefix}tag-pcoip"]
  source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_firewall" "allow-dns" {
  name    = "${local.prefix}fw-allow-dns"
  network = google_compute_network.vpc.self_link

  allow {
    protocol = "tcp"
    ports    = ["53"]
  }
  allow {
    protocol = "udp"
    ports    = ["53"]
  }

  target_tags   = ["${local.prefix}tag-dns"]
  source_ranges = ["35.199.192.0/19"]
}

resource "google_compute_subnetwork" "dc-subnet" {
  name          = "${local.prefix}controller"
  ip_cidr_range = var.dc_subnet_cidr
  network       = google_compute_network.vpc.self_link
}

resource "google_compute_subnetwork" "cac-subnet" {
  name          = "${local.prefix}connector"
  ip_cidr_range = var.cac_subnet_cidr
  network       = google_compute_network.vpc.self_link
}

resource "google_compute_network" "workstations" {
  name                    = "${local.prefix}${var.workstations_network}"
  auto_create_subnetworks = "false"
}

resource "google_compute_subnetwork" "ws-subnet" {
  name          = "${local.prefix}${var.workstations_network}"
  ip_cidr_range = var.ws_subnet_cidr
  network       = google_compute_network.workstations.self_link
}

resource "google_compute_firewall" "ws-allow-internal" {
  name    = "${local.prefix}${var.workstations_network}-allow-internal"
  network = google_compute_network.workstations.self_link

  allow {
    protocol = "icmp"
  }
  allow {
    protocol = "tcp"
    ports    = ["1-65535"]
  }
  allow {
    protocol = "udp"
    ports    = ["1-65535"]
  }

  source_ranges = [var.dc_subnet_cidr, var.cac_subnet_cidr, var.ws_subnet_cidr]
}

resource "google_compute_network_peering" "teradici-workstations" {
  name = "${local.prefix}${var.teradici_network}-${var.gcp_project_id}-${local.prefix}${var.workstations_network}"
  network = "${google_compute_network.vpc.self_link}"
  peer_network = "${google_compute_network.workstations.self_link}"
}

resource "google_compute_network_peering" "workstations-teradici" {
  name = "${local.prefix}${var.workstations_network}-${var.gcp_project_id}-${local.prefix}${var.teradici_network}"
  network = "${google_compute_network.workstations.self_link}"
  peer_network = "${google_compute_network.vpc.self_link}"
}

resource "google_compute_address" "dc-internal-ip" {
  name         = "${local.prefix}static-ip-internal-dc"
  subnetwork   = google_compute_subnetwork.dc-subnet.self_link
  address_type = "INTERNAL"
  address      = var.dc_private_ip
}

resource "google_compute_router" "router" {
  name    = "${local.prefix}router"
  region  = var.gcp_region
  network = google_compute_network.workstations.self_link

  bgp {
    asn = 65000
  }
}

resource "google_compute_router_nat" "nat" {
  name                               = "${local.prefix}nat"
  router                             = google_compute_router.router.name
  region                             = var.gcp_region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"
  min_ports_per_vm                   = 2048

  subnetwork {
    name                    = google_compute_subnetwork.ws-subnet.self_link
    source_ip_ranges_to_nat = ["PRIMARY_IP_RANGE"]
  }
}
