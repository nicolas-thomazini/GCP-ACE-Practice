
#!/usr/bin/env bash

# ============================================================
# GCP ACE - Module 03
# Lab 03.2 - Subnets
# Project: ace-hands-on-labs-2026
# ============================================================

# 1. Configure project
gcloud config set project ace-hands-on-labs-2026

# 2. Inspect existing subnet
gcloud compute networks subnets describe ace-subnet-us-central1 \
  --region=us-central1

# 3. Expand primary IP range from /24 to /23
gcloud compute networks subnets expand-ip-range ace-subnet-us-central1 \
  --region=us-central1 \
  --prefix-length=23

# 4. Validate subnet expansion
gcloud compute networks subnets describe ace-subnet-us-central1 \
  --region=us-central1

# 5. Add secondary IP ranges
gcloud compute networks subnets update ace-subnet-us-central1 \
  --region=us-central1 \
  --add-secondary-ranges pods-range=10.30.0.0/20,services-range=10.40.0.0/24

# 6. Inspect primary and secondary IP ranges
gcloud compute networks subnets describe ace-subnet-us-central1 \
  --region=us-central1 \
  --format="yaml(name,ipCidrRange,secondaryIpRanges)"

# 7. List subnets associated with Custom VPC
gcloud compute networks subnets list \
  --network=ace-vpc-custom

# 8. Enable Private Google Access
gcloud compute networks subnets update ace-subnet-us-central1 \
  --region=us-central1 \
  --enable-private-ip-google-access

# 9. Validate final subnet configuration
gcloud compute networks subnets describe ace-subnet-us-central1 \
  --region=us-central1 \
  --format="yaml(name,ipCidrRange,privateIpGoogleAccess,secondaryIpRanges)"
