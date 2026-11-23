
#!/usr/bin/env bash

# ============================================================
# GCP ACE - Module 03
# Lab 03.1 - VPC Networks
# Project: ace-hands-on-labs-2026
# ============================================================

# 1. Configure project
gcloud config set project ace-hands-on-labs-2026

# 2. Enable Compute Engine API
gcloud services enable compute.googleapis.com

# 3. Create Custom VPC
gcloud compute networks create ace-vpc-custom \
  --subnet-mode=custom

# 4. Create subnet in us-central1
gcloud compute networks subnets create ace-subnet-us-central1 \
  --network=ace-vpc-custom \
  --region=us-central1 \
  --range=10.10.0.0/24

# 5. Create subnet in southamerica-east1
gcloud compute networks subnets create ace-subnet-southamerica \
  --network=ace-vpc-custom \
  --region=southamerica-east1 \
  --range=10.20.0.0/24

# 6. List Custom VPC subnets
gcloud compute networks subnets list \
  --network=ace-vpc-custom

# 7. Create Auto VPC
gcloud compute networks create ace-vpc-auto \
  --subnet-mode=auto

# 8. List automatically created subnets
gcloud compute networks subnets list \
  --network=ace-vpc-auto

# 9. List all VPC networks
gcloud compute networks list

# 10. Convert Auto VPC to Custom
gcloud compute networks update ace-vpc-auto \
  --switch-to-custom-subnet-mode

# 11. Validate final VPC configuration
gcloud compute networks list

# 12. Validate preserved subnets
gcloud compute networks subnets list \
  --network=ace-vpc-auto
