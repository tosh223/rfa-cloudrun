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
resource "google_service_account" "sa_rfa_run" {
  account_id   = "sa-rfa-run"
  display_name = "sa-rfa-run"
}

resource "google_service_account" "sa_rfa_scheduler" {
  account_id   = "sa-rfa-scheduler"
  display_name = "sa-rfa-scheduler"
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
      service_account_name = google_service_account.sa_rfa_run.email
    }
  }
  traffic {
    percent         = 100
    latest_revision = true
  }
}

resource "google_project_iam_binding" "rfa_bq_user" {
  project = var.project
  role    = "roles/bigquery.user"
  members = ["serviceAccount:${google_service_account.sa_rfa_run.email}"]
}

resource "google_project_iam_binding" "rfa_secretAccessor" {
  project = var.project
  role    = "roles/secretmanager.secretAccessor"
  members = ["serviceAccount:${google_service_account.sa_rfa_run.email}"]
}

##############################################
# Cloud Scheduler
##############################################
resource "google_cloud_scheduler_job" "rfa_crawler" {
  project  = google_cloud_run_service.rfa.project
  region   = "asia-northeast1"
  name     = "rfa-crawler"
  schedule = "0 * * * *"
  http_target {
    uri         = google_cloud_run_service.rfa.status[0].url
    http_method = "POST"
    body        = base64encode("{\"project_id\":\"${var.project}\", \"location\":\"${var.region}\", \"twitter_id\":\"${var.twitter_id}\", \"size\":\"${var.twitter_search_size}\"}")
    oidc_token {
      service_account_email = google_service_account.sa_rfa_scheduler.email
    }
  }
}

resource "google_cloud_run_service_iam_binding" "rfa_invoker" {
  project  = var.project
  service  = google_cloud_run_service.rfa.name
  location = google_cloud_run_service.rfa.location
  role     = "roles/run.invoker"
  members  = ["serviceAccount:${google_service_account.sa_rfa_scheduler.email}"]
}

##############################################
# Output
##############################################
output "cloud_run_rfa_url" {
  value = google_cloud_run_service.rfa.status[0].url
}
