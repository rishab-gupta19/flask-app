#! /bin/bash

sudo apt-get update -y
sudo apt-get install -y ca-certificates curl gnupg
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
  "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update -y
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

sudo apt-get install -y google-cloud-sdk # Installs gcloud CLI
gcloud auth configure-docker --quiet
# --- Pull and Run Docker Image ---
# Pull the specified Docker image from Google Container Registry
# The image name is passed as a template variable from Terraform.
docker pull ${docker_image_name}

# Run the Docker container
# -d: Run in detached mode (in the background)
# --name: Assign a name to the container
# -p 80:80: Map port 80 on the VM host to port 80 inside the container
# -e GKE_BACKEND_IP: Pass the GKE backend IP as an environment variable to the container.
#   This variable is crucial for the Nginx configuration templating inside the container.
docker run -d \
  --name product-frontend \
  -p 80:80 \
  -e GKE_BACKEND_IP="${gke_backend_ip}" \
  ${docker_image_name}
