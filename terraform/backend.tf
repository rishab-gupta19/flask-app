terraform {
  backend "gcs" {
    bucket = "frontend-bucket-rishab"
    prefix = "terraform/org/flask-app/state/"
  }
}