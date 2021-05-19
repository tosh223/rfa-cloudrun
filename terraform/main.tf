provider "google" {
  version = "3.60.0"
  project = var.project
  region  = var.region
  zone    = var.zone
}

terraform {
  backend "gcs" {
  }
}

##############################################
# Service Account
##############################################
resource "google_service_account" "sa_cloudrun_rfa" {
  account_id   = "sa-cloudrun-rfa"
  display_name = "sa-cloudrun-rfa"
}

##############################################
# Cloud Run
##############################################
resource "google_cloud_run_service" "rfa" {
  name     = "rfa"
  location = var.region
  template {
    spec {
      containers {
        image = "gcr.io/${var.project}/rfa"
      }
    }
  }
  traffic {
    percent         = 100
    latest_revision = true
  }
}

resource "google_cloud_run_service_iam_binding" "rfa_invoker" {
  project        = var.project
  region         = google_cloud_run_service.rfa.region
  cloud_function = google_cloud_run_service.rfa.name
  role           = "roles/cloudrun.invoker"
  members        = ["serviceAccount:${google_service_account.sa_cloudrun_rfa.email}"]
}

resource "google_cloud_run_service_iam_binding" "rfa_secretAccessor" {
  project        = var.project
  region         = google_cloud_run_service.rfa.region
  cloud_function = google_cloud_run_service.rfa.name
  role           = "roles/secretmanager.secretAccessor"
  members        = ["serviceAccount:${google_service_account.sa_cloudrun_rfa.email}"]
}

##############################################
# Cloud Scheduler
##############################################
resource "google_cloud_scheduler_job" "rfa_crawler" {
  project  = google_cloud_run_service.rfa.project
  region   = google_cloud_run_service.rfa.region
  name     = "rfa-crawler"
  schedule = "30 * * * *"
  http_target {
    uri         = google_cloud_run_service.rfa.https_trigger_url
    http_method = "POST"
    body        = base64encode("{\"project_id\":\"${var.project}\", \"location\":\"${var.region}\", \"twitter_id\":\"${var.twitter_id}\", \"size\":\"${twitter_search_size}\"}")
    oidc_token {
      service_account_email = google_service_account.sa_cloudrun_rfa.email
    }
  }
}

##############################################
# Output
##############################################
output "cloud_run_rfa_url" {
  value = google_cloud_run_service.rfa.https_trigger_url
}
