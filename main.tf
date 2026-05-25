terraform {
  backend "gcs" {
    prefix = "terraform/state/vllm-gke"
  }
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 7.33.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 3.1.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.3.0"
    }
    time = {
      source  = "hashicorp/time"
      version = "0.14.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}
