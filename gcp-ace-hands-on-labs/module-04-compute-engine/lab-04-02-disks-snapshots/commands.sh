#!/usr/bin/env bash
#
# Lab 04.2 — Disks & Snapshots
# Referência dos comandos utilizados durante o laboratório.
#
# IMPORTANTE:
# - Este arquivo é um roteiro de referência, não um script para executar inteiro.
# - Execute os comandos por etapa e confira os recursos antes de aplicar ou destruir.
# - Os comandos Linux devem ser executados dentro da VM.
# - Os comandos Terraform/gcloud devem ser executados no WSL, na pasta do laboratório.
# - Não execute mkfs no disco de boot.
#

# ---------------------------------------------------------------------------
# 1. Contexto GCP e Terraform (WSL)
# ---------------------------------------------------------------------------

gcloud config set project ace-hands-on-labs-2026
gcloud config set compute/region us-central1
gcloud config set compute/zone us-central1-a

gcloud config list

terraform init
terraform fmt
terraform validate
terraform plan
terraform apply

# ---------------------------------------------------------------------------
# 2. Inspecionar o Persistent Disk original (WSL)
# ---------------------------------------------------------------------------

gcloud compute disks list \
  --project=ace-hands-on-labs-2026

gcloud compute disks describe ace-data-disk \
  --zone=us-central1-a \
  --project=ace-hands-on-labs-2026

# ---------------------------------------------------------------------------
# 3. Snapshot e restauração (WSL)
# ---------------------------------------------------------------------------

terraform fmt
terraform validate
terraform plan
terraform apply

gcloud compute snapshots list \
  --project=ace-hands-on-labs-2026

gcloud compute snapshots describe ace-data-disk-snapshot \
  --project=ace-hands-on-labs-2026

terraform fmt
terraform validate
terraform plan
terraform apply

gcloud compute disks describe ace-restored-disk \
  --zone=us-central1-a \
  --project=ace-hands-on-labs-2026

# ---------------------------------------------------------------------------
# 4. VM temporária, firewall e discos anexados (WSL)
# ---------------------------------------------------------------------------

terraform fmt
terraform validate
terraform plan
terraform apply

gcloud compute instances list \
  --project=ace-hands-on-labs-2026

gcloud compute instances describe ace-disk-lab-vm \
  --zone=us-central1-a \
  --project=ace-hands-on-labs-2026

gcloud compute disks list \
  --project=ace-hands-on-labs-2026

# SSH via IAP
gcloud compute ssh ace-disk-lab-vm \
  --zone=us-central1-a \
  --project=ace-hands-on-labs-2026 \
  --tunnel-through-iap

# ---------------------------------------------------------------------------
# 5. Identificar discos (dentro da VM Debian)
# ---------------------------------------------------------------------------

lsblk
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS
ls -l /dev/disk/by-id/google-*
sudo blkid
df -h

# Identificadores observados durante este laboratório:
# /dev/disk/by-id/google-ace-data-disk
# /dev/disk/by-id/google-ace-restored-disk
#
# Não presuma que os discos serão sempre /dev/sdb e /dev/sdc.
# Nunca formate o disco de boot.

# ---------------------------------------------------------------------------
# 6. Criar filesystem ext4 e montar (dentro da VM)
# ---------------------------------------------------------------------------

sudo mkfs.ext4 /dev/disk/by-id/google-ace-data-disk
sudo mkfs.ext4 /dev/disk/by-id/google-ace-restored-disk

sudo mkdir -p /mnt/data
sudo mkdir -p /mnt/restored

sudo mount /dev/disk/by-id/google-ace-data-disk /mnt/data
sudo mount /dev/disk/by-id/google-ace-restored-disk /mnt/restored

lsblk -f
df -h

# ---------------------------------------------------------------------------
# 7. Testar leitura e escrita (dentro da VM)
# ---------------------------------------------------------------------------

echo "Arquivo original do Persistent Disk" | sudo tee /mnt/data/arquivo-original.txt
echo "Arquivo no disco restaurado pelo snapshot" | sudo tee /mnt/restored/arquivo-restaurado.txt

ls -lah /mnt/data
ls -lah /mnt/restored

cat /mnt/data/arquivo-original.txt
cat /mnt/restored/arquivo-restaurado.txt

# ---------------------------------------------------------------------------
# 8. Testar persistência após reboot (dentro da VM)
# ---------------------------------------------------------------------------

sudo reboot

# Reconectar pelo WSL:
# gcloud compute ssh ace-disk-lab-vm \
#   --zone=us-central1-a \
#   --project=ace-hands-on-labs-2026 \
#   --tunnel-through-iap
#
# Após reconectar, verificar:
lsblk -f
df -h

# Os discos permanecem anexados e os filesystems preservados.
# Sem /etc/fstab, os pontos de montagem precisam ser montados novamente.

# ---------------------------------------------------------------------------
# 9. Montagem manual usando UUID (dentro da VM)
# ---------------------------------------------------------------------------

sudo mount UUID=3efb8a36-4f88-4687-9515-c2b3de5c8337 /mnt/data
sudo mount UUID=6a24429e-9851-420b-9eef-51220e577d43 /mnt/restored

lsblk -f
df -h

cat /mnt/data/arquivo-original.txt
cat /mnt/restored/arquivo-restaurado.txt

# ---------------------------------------------------------------------------
# 10. Configurar montagem automática via /etc/fstab (dentro da VM)
# ---------------------------------------------------------------------------

sudo cp /etc/fstab /etc/fstab.backup

echo 'UUID=3efb8a36-4f88-4687-9515-c2b3de5c8337 /mnt/data ext4 defaults,nofail 0 2' | sudo tee -a /etc/fstab

echo 'UUID=6a24429e-9851-420b-9eef-51220e577d43 /mnt/restored ext4 defaults,nofail 0 2' | sudo tee -a /etc/fstab

cat /etc/fstab
sudo findmnt --verify
sudo mount -a

# Reiniciar para testar montagem automática:
sudo reboot

# Reconectar via WSL e validar:
# gcloud compute ssh ace-disk-lab-vm \
#   --zone=us-central1-a \
#   --project=ace-hands-on-labs-2026 \
#   --tunnel-through-iap
#
# Dentro da VM:
lsblk -f
df -h
cat /mnt/data/arquivo-original.txt
cat /mnt/restored/arquivo-restaurado.txt

# ---------------------------------------------------------------------------
# 11. Limpeza (WSL, na pasta do laboratório)
# ---------------------------------------------------------------------------

terraform plan -destroy

# Confira se o plano remove somente os cinco recursos deste laboratório:
# - ace-disk-lab-vm
# - ace-disk-lab-allow-iap-ssh
# - ace-data-disk
# - ace-restored-disk
# - ace-data-disk-snapshot
#
# O plano observado foi:
# Plan: 0 to add, 0 to change, 5 to destroy.
#
# Execute somente após revisar o plano:
terraform destroy

# Validação posterior (considere que podem existir recursos de outros labs):
gcloud compute instances list --project=ace-hands-on-labs-2026
gcloud compute disks list --project=ace-hands-on-labs-2026
gcloud compute snapshots list --project=ace-hands-on-labs-2026

# ---------------------------------------------------------------------------
# 12. Git (WSL, a partir da raiz do repositório)
# ---------------------------------------------------------------------------

# git status
# git add gcp-ace-hands-on-labs/module-04-compute-engine/lab-04-02-disks-snapshots/
# git commit -m "docs: complete lab 04.2 disks and snapshots"
# git push -u origin feature/module-04-02-disks-snapshots
#
# Depois, abrir/mesclar o PR conforme o fluxo do repositório.