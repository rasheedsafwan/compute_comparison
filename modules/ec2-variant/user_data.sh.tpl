#!/bin/bash
# Runs once at instance boot. Installs Docker, pulls the same image built in Phase 4,
# and runs it — this keeps the EC2 variant's app byte-for-byte identical to Fargate's.
yum install -y docker
systemctl start docker
systemctl enable docker

aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin $(echo "${image_uri}" | cut -d'/' -f1)

docker run -d \
  --name coffee-api \
  -p 3000:3000 \
  -e TABLE_NAME="${table_name}" \
  --restart always \
  ${image_uri}