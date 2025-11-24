terraform {
  backend "gcs" {
    prefix = "terraform/state/vllm-gke"
  }
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 7.12.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.38.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2.4"
    }
    time = {
      source  = "hashicorp/time"
      version = "0.13.1"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}
