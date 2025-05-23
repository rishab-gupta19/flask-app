# Flask-GKE-GCP Deployment basic application (using docker, cloud sql, GKE, MIG)

This project contains a full-stack application deployed on Google Cloud Platform:

* Flask backend on Google Kubernetes Engine (GKE)
* Static frontend hosted on Compute Engine with Nginx
* PostgreSQL database on Cloud SQL
* Docker images stored in Google Container Registry (GCR)

## Prerequisites

* Google Cloud account
* Git and Docker installed
* Google Cloud SDK (gcloud CLI) installed and authenticated

## Folder Structure

```
project-root/
├── backend/
│   ├── app.py
│   ├── Dockerfile
│   ├── requirements.txt
│   ├── backend-deployment.yaml
│   ├── backend-service.yaml
│   └── .gitignore
├── frontend/
│   ├── index.html
│   └── Dockerfile
```

## Step 1: Clone the Repository

```bash
git clone https://github.com/<your-username>/<your-repo>.git
cd <your-repo>
```

## Step 2: Set Up Google Cloud Project

```bash
gcloud auth login
gcloud config set project <your-project-id>
```

## Step 3: Enable Required GCP APIs

```bash
gcloud services enable compute.googleapis.com \
                      container.googleapis.com \
                      sqladmin.googleapis.com \
                      artifactregistry.googleapis.com
```

## Step 4: Set Up Cloud SQL (PostgreSQL 14)

```bash
gcloud sql instances create product-sql \
  --database-version=POSTGRES_14 \
  --tier=db-f1-micro \
  --region=us-central1 \
  --root-password=<your-password>

gcloud sql databases create products_db --instance=product-sql
```

## Step 5: Allow GKE Nodes to Access Cloud SQL (Public IP Setup)

1. Create the GKE cluster first (see below).
2. Run:

```bash
kubectl get nodes -o wide
```

3. Note the EXTERNAL-IPs of your nodes.
4. Go to Cloud SQL → Connections tab → Add those IPs to "Authorized networks".

## Step 6: Build and Push Docker Images to GCR

Make sure your project has the right IAM role:

* The VM or GKE nodes should have `roles/artifactregistry.reader` or `roles/storage.objectViewer` (for GCR access).

### Backend

```bash
cd backend
export PROJECT_ID=$(gcloud config get-value project)
docker build -t gcr.io/$PROJECT_ID/product-backend .
docker push gcr.io/$PROJECT_ID/product-backend
```

### Frontend

```bash
cd ../frontend
docker build -t gcr.io/$PROJECT_ID/product-frontend .
docker push gcr.io/$PROJECT_ID/product-frontend
```

## Step 7: Deploy Backend to GKE

```bash
gcloud container clusters create product-cluster \
  --zone us-central1-a \
  --num-nodes=2

gcloud container clusters get-credentials product-cluster --zone us-central1-a
kubectl apply -f backend/backend-deployment.yaml
kubectl apply -f backend/backend-service.yaml
```

Check external IP:

```bash
kubectl get svc
```

## Step 8: Deploy Frontend to Compute Engine Using Docker

```bash
gcloud compute instances create frontend-vm \
  --zone=us-central1-a \
  --machine-type=e2-micro \
  --image-family=debian-11 \
  --image-project=debian-cloud \
  --tags=http-server \
  --metadata=startup-script='#! /bin/bash
    apt update
    apt install -y docker.io
    systemctl start docker
    systemctl enable docker'
```

Open firewall:

```bash
gcloud compute firewall-rules create allow-http \
  --allow tcp:80 \
  --target-tags=http-server
```

SSH into the VM and run:

```bash
sudo docker pull gcr.io/$PROJECT_ID/product-frontend
sudo docker run -d -p 80:80 gcr.io/$PROJECT_ID/product-frontend
```

Access the app:

* Frontend: http\://<Compute-VM-External-IP>
* Backend API: http\://<GKE-External-IP>

Ensure your frontend app references the backend API IP correctly.

## Security and Access Notes

* Don't commit `.env` files (already in `.gitignore`)
* Always bind Flask to `0.0.0.0` and expose correct port
* Use IAM roles instead of hardcoding credentials
* Use Secrets in Kubernetes for sensitive data

## Optional Enhancements

* Add HTTPS using Nginx + Certbot or Cloud Armor
* Use Cloud SQL Proxy for secure DB connections
* Use GitHub Actions for CI/CD

---

This setup deploys a real-world microservice stack across multiple GCP services. Make sure each part is correctly configured and granted least privilege necessary for your use case.
