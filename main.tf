variable "projectid" {
    type = "string"
}

variable "region" {
    type = "string"
    default = "us-east1"
}

variable "zone" {
    type = "string"
    default = "us-east1-d"
}

variable "prefix" {
    type = "string"
    default = "test"
}

variable "service_account_email" {
    type = "string"
    default = ""
}

provider "google" {
    project = "${var.projectid}"
    region = "${var.region}"
}

resource "google_compute_network" "network" {
  name       = "${var.prefix}-concourse"
}

resource "google_compute_subnetwork" "concourse-public-subnet-1" {
  name          = "${var.prefix}-concourse-public-${var.region}-1"
  ip_cidr_range = "10.150.0.0/16"
  network       = "${google_compute_network.network.self_link}"
}

resource "google_compute_subnetwork" "concourse-public-subnet-2" {
  name          = "${var.prefix}-concourse-public-${var.region}-2"
  ip_cidr_range = "10.160.0.0/16"
  network       = "${google_compute_network.network.self_link}"
}

resource "google_compute_firewall" "concourse-public" {
  name    = "${var.prefix}-concourse-public"
  network = "${google_compute_network.network.name}"

  allow {
    protocol = "tcp"
    ports    = ["80", "8080", "443", "4443", "22", "6868"]
  }
  source_ranges = ["0.0.0.0/0"]

  target_tags = ["concourse-public"]
}

resource "google_compute_firewall" "concourse-internal" {
  name    = "${var.prefix}-concourse-internal"
  network = "${google_compute_network.network.name}"

  allow {
    protocol = "icmp"
  }

  allow {
    protocol = "tcp"
  }

  allow {
    protocol = "udp"
  }

  target_tags = ["concourse-internal"]
  source_tags = ["concourse-internal"]
}

resource "google_compute_address" "concourse" {
	name = "${var.prefix}-concourse"
}
