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
sudo apt-get install -y google-cloud-sdk 
gcloud auth configure-docker --quiet

SERVICE_FILE="/etc/systemd/system/product-frontend.service"
cat <<EOF | sudo tee "$${SERVICE_FILE}"
[Unit]
Description=Product Frontend Docker Container
After=docker.service
Requires=docker.service

[Service]
Restart=always
RestartSec=10

ExecStartPre=-/usr/bin/docker stop product-frontend
ExecStartPre=-/usr/bin/docker rm product-frontend
ExecStartPre=/usr/bin/docker pull ${docker_image_name}

ExecStart=/usr/bin/docker run --name product-frontend -p 80:80 -e GKE_BACKEND_IP=${gke_backend_ip} ${docker_image_name}

ExecStop=/usr/bin/docker stop product-frontend
ExecStopPost=/usr/bin/docker rm product-frontend

[Install]
WantedBy=multi-user.target # Ensures the service starts when the system reaches multi-user runlevel
EOF

sudo systemctl daemon-reload
sudo systemctl enable product-frontend.service
sudo systemctl start product-frontend.service
