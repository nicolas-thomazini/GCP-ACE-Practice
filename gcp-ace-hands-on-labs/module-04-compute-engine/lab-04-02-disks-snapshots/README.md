# Lab 04.2 — Disks & Snapshots

## Objetivo

Praticar o ciclo de vida de Persistent Disks no Google Compute Engine: provisionar discos com Terraform, criar snapshots, restaurar um disco, anexar discos a uma VM Linux, formatar e montar os dispositivos e configurar montagem automática com `/etc/fstab`.

## Ambiente

| Item | Valor |
|---|---|
| Projeto GCP | `ace-hands-on-labs-2026` |
| Região | `us-central1` |
| Zona | `us-central1-a` |
| Provider Terraform | `hashicorp/google` `~> 6.0` |
| VM temporária | `ace-disk-lab-vm` |
| Tipo de máquina | `e2-micro` |
| Sistema operacional | Debian 12 |
| Tipo dos discos de dados | `pd-balanced` |
| Tamanho dos discos | 10 GB |

## Estrutura do laboratório

```text
lab-04-02-disks-snapshots/
├── main.tf
├── variables.tf
├── terraform.tfvars
├── outputs.tf
├── README.md
└── commands.sh
```

## Arquitetura criada

Durante o laboratório, o Terraform provisionou:

1. `ace-data-disk`: Persistent Disk zonal de 10 GB (`pd-balanced`).
2. `ace-data-disk-snapshot`: snapshot global criado a partir do disco original.
3. `ace-restored-disk`: novo Persistent Disk de 10 GB criado a partir do snapshot.
4. `ace-disk-lab-vm`: VM Debian 12 `e2-micro`, sem IP externo, com os dois discos de dados anexados.
5. `ace-disk-lab-allow-iap-ssh`: regra de firewall permitindo TCP/22 a partir da faixa do IAP `35.235.240.0/20`, direcionada à tag `ace-disk-lab`.

A VM recebeu os discos com os nomes de dispositivo `ace-data-disk` e `ace-restored-disk`. No Linux, eles foram identificados inicialmente como `/dev/sdb` e `/dev/sdc`; a ordem dos dispositivos pode mudar após um reboot.

## Conceitos e atividades

### 1. Persistent Disk

Foi criado um disco independente de uma VM usando `google_compute_disk`.

Propriedades praticadas:

- Nome: `ace-data-disk`
- Zona: `us-central1-a`
- Tipo: `pd-balanced`
- Tamanho: 10 GB

Um Persistent Disk é um recurso de armazenamento persistente que pode existir independentemente de uma instância. Para utilizá-lo dentro do sistema operacional, é necessário anexá-lo a uma VM e disponibilizar seu filesystem.

### 2. Snapshot

Foi criado `ace-data-disk-snapshot` com `google_compute_snapshot`, usando o disco original como origem.

O snapshot representa o estado do disco no momento em que foi criado. Ele não é uma sincronização contínua: alterações feitas no disco depois da criação do snapshot não são incluídas retroativamente nele.

O snapshot foi listado e inspecionado com `gcloud compute snapshots`.

### 3. Restaurar um disco

Foi criado `ace-restored-disk` usando o snapshot como origem.

A inspeção do disco confirmou o campo `sourceSnapshot`, demonstrando a origem da restauração.

Como o snapshot foi criado quando o disco original ainda estava vazio, o disco restaurado também começou vazio.

### 4. Anexar discos a uma VM

Foi criada a VM `ace-disk-lab-vm` com:

- Debian 12;
- máquina `e2-micro`;
- disco de boot de 10 GB;
- sem endereço IP externo;
- acesso SSH via IAP;
- os discos `ace-data-disk` e `ace-restored-disk` anexados.

A regra de firewall liberou TCP/22 apenas para a faixa de origem do IAP `35.235.240.0/20` e para a tag de destino `ace-disk-lab`.

### 5. Identificar os dispositivos no Linux

Comandos utilizados:

```bash
lsblk
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS
ls -l /dev/disk/by-id/google-*
sudo blkid
df -h
```

Os nomes persistentes do Google Cloud permitiram identificar os discos sem depender de `/dev/sdb` ou `/dev/sdc`:

```text
/dev/disk/by-id/google-ace-data-disk
/dev/disk/by-id/google-ace-restored-disk
```

### 6. Criar filesystem e montar

Os dois discos estavam vazios e foram formatados com `ext4`:

```bash
sudo mkfs.ext4 /dev/disk/by-id/google-ace-data-disk
sudo mkfs.ext4 /dev/disk/by-id/google-ace-restored-disk
```

Pontos de montagem:

```bash
sudo mkdir -p /mnt/data
sudo mkdir -p /mnt/restored
```

Montagem:

```bash
sudo mount /dev/disk/by-id/google-ace-data-disk /mnt/data
sudo mount /dev/disk/by-id/google-ace-restored-disk /mnt/restored
```

> **Atenção:** nunca execute `mkfs` no disco de boot. Neste laboratório, a formatação foi feita somente nos dois discos de dados, que estavam vazios.

### 7. Testar leitura e escrita

Foram criados arquivos independentes:

```bash
echo "Arquivo original do Persistent Disk" | sudo tee /mnt/data/arquivo-original.txt
echo "Arquivo no disco restaurado pelo snapshot" | sudo tee /mnt/restored/arquivo-restaurado.txt
```

Os arquivos foram listados e lidos com `ls -lah` e `cat`.

Como o snapshot foi criado antes da gravação desses arquivos, `arquivo-original.txt` não existia no disco restaurado. Isso demonstrou que o snapshot representa um ponto no tempo.

### 8. Persistência após reboot

Após reiniciar a VM, os discos continuaram anexados e os filesystems continuaram presentes, mas os pontos de montagem não foram restaurados automaticamente.

Também foi observado que os nomes `/dev/sdX` podem mudar após a inicialização. Os UUIDs dos filesystems permaneceram estáveis.

### 9. Montagem automática com `/etc/fstab`

Foi feito backup do arquivo antes da alteração:

```bash
sudo cp /etc/fstab /etc/fstab.backup
```

Entradas adicionadas:

```fstab
UUID=3efb8a36-4f88-4687-9515-c2b3de5c8337 /mnt/data ext4 defaults,nofail 0 2
UUID=6a24429e-9851-420b-9eef-51220e577d43 /mnt/restored ext4 defaults,nofail 0 2
```

Validação:

```bash
sudo findmnt --verify
sudo mount -a
```

Depois de reiniciar a VM, os dois discos foram montados automaticamente nos respectivos diretórios. A validação com `lsblk -f` e `df -h` confirmou o resultado.

## Terraform

Recursos principais utilizados:

| Recurso Terraform | Finalidade |
|---|---|
| `google_compute_disk` | Criar Persistent Disks |
| `google_compute_snapshot` | Criar snapshot |
| `google_compute_instance` | Criar VM e anexar discos |
| `google_compute_firewall` | Permitir SSH via IAP |

Fluxo de trabalho:

```bash
terraform init
terraform fmt
terraform validate
terraform plan
terraform apply
```

Para inspecionar recursos no Google Cloud, também foram utilizados comandos `gcloud compute disks`, `gcloud compute snapshots` e `gcloud compute instances`.

## Principais aprendizados para a ACE

- Persistent Disks são recursos de armazenamento persistente e podem ser anexados a VMs.
- Discos zonais pertencem a uma zona específica.
- Snapshots são recursos globais e permitem criar novos discos a partir de um estado anterior.
- Um snapshot não sincroniza alterações futuras do disco de origem.
- Um disco restaurado é um novo disco, independente do disco original.
- Anexar um disco ao Compute Engine não significa que ele já esteja pronto para uso no Linux: pode ser necessário criar filesystem e montar.
- UUID é mais confiável que nomes `/dev/sdX` para identificar filesystems em `/etc/fstab`.
- `/etc/fstab` permite configurar montagem automática durante o boot.
- Acesso SSH via IAP utiliza a faixa de origem `35.235.240.0/20`; a regra de firewall também precisa selecionar a VM correta.

## Limpeza dos recursos

Os recursos deste laboratório foram gerenciados pelo Terraform. Antes de destruir, confira o plano:

```bash
terraform plan -destroy
```

O plano esperado para a limpeza completa deste laboratório foi:

```text
Plan: 0 to add, 0 to change, 5 to destroy.
```

Os cinco recursos eram:

- VM `ace-disk-lab-vm`;
- firewall `ace-disk-lab-allow-iap-ssh`;
- disco `ace-data-disk`;
- disco `ace-restored-disk`;
- snapshot `ace-data-disk-snapshot`.

Se o plano corresponder somente aos recursos deste laboratório, execute:

```bash
terraform destroy
```

Confirme com `yes`. A destruição da VM e dos discos elimina os arquivos de teste e o snapshot provisionado neste exercício.

Validação posterior:

```bash
gcloud compute instances list --project=ace-hands-on-labs-2026
gcloud compute disks list --project=ace-hands-on-labs-2026
gcloud compute snapshots list --project=ace-hands-on-labs-2026
```

> Verifique os resultados considerando que o projeto pode conter recursos de outros laboratórios. Não exclua recursos que não pertençam a este laboratório.

## Checklist

- [x] Criar Persistent Disk com Terraform.
- [x] Criar snapshot com Terraform.
- [x] Restaurar disco a partir de snapshot.
- [x] Criar VM temporária e anexar os discos.
- [x] Acessar VM via IAP.
- [x] Identificar, formatar e montar discos no Linux.
- [x] Testar leitura e escrita.
- [x] Validar persistência após reboot.
- [x] Configurar e validar montagem automática via `/etc/fstab`.
- [ ] Executar `terraform destroy` e validar a limpeza.
- [ ] Commitar e fazer merge da branch do laboratório.