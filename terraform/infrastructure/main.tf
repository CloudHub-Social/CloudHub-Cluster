terraform {
  cloud {
    organization = "jaxcb7e5133"

    workspaces {
      name = "vms"
    }
  }

  required_providers {
    sops = {
      source  = "carlpett/sops"
      version = "1.1.1"
    }
    proxmox = {
      source  = "telmate/proxmox"
      version = "2.9.14"
    }
  }
}

data "sops_file" "proxmox_secrets" {
  source_file = "secret.sops.yaml"
}

provider "proxmox" {
  # url is the hostname (FQDN if you have one) for the proxmox host you'd like to connect to to issue the commands. my proxmox host is 'prox-1u'. Add /api2/json at the end for the API
  pm_api_url = data.sops_file.proxmox_secrets.data["pm_api_url"]
  # api token id is in the form of: <username>@pam!<tokenId>
  #pm_api_token_id = "terraform-prov@pve!terraform-prov"
  # this is the full secret wrapped in quotes. don't worry, I've already deleted this from my proxmox cluster by the time you read this post
  #pm_api_token_secret = "9ec8e608-d834-4ce5-91d2-15dd59f9a8c1"
  # leave tls_insecure set to true unless you have your proxmox SSL certificate situation fully sorted out (if you do, you will know)
  pm_tls_insecure = true
  pm_user         = data.sops_file.proxmox_secrets.data["pm_user"]
  pm_password     = data.sops_file.proxmox_secrets.data["pm_password"]
}

# resource is formatted to be "[type]" "[entity_name]" so in this case
# we are looking to create a proxmox_vm_qemu entity named test_server
resource "proxmox_vm_qemu" "talos-control-plane" {
  count = 3                                  # just want 1 for now, set to 0 and apply to destroy VM
  name  = "talos-control-${count.index + 1}" #count.index starts at 0, so + 1 means this VM will be named test-vm-1 in proxmox
  # this now reaches out to the vars file. I could've also used this var above in the pm_api_url setting but wanted to spell it out up there. target_node is different than api_url. target_node is which node hosts the template and thus also which node will host the new VM. it can be different than the host you use to communicate with the API. the variable contains the contents "prox-1u"
  target_node = data.sops_file.proxmox_secrets.data["pm_host"]
  # another variable with contents "ubuntu-2004-cloudinit-template"
  iso = "local:iso/metal-amd64.iso"
  # basic VM settings here. agent refers to guest agent
  agent   = 1
  cores   = 8
  sockets = 2
  cpu     = "host"
  memory  = 12288
  scsihw  = "virtio-scsi-pci"
  qemu_os = "other"
  #bootdisk = "scsi0"
  onboot = true
  disk {
    slot = 0
    # set disk size here. leave it small for testing because expanding the disk takes time.
    size    = "50G"
    type    = "scsi"
    storage = "local-lvm"
    discard = "on"
    ssd     = 1
  }

  disk {
    slot    = 1
    size    = "25G"
    type    = "scsi"
    storage = "local-lvm"
    discard = "on"
    ssd     = 1
  }

  # if you want two NICs, just copy this whole network section and duplicate it
  network {
    model   = "virtio"
    bridge  = "vmbr6"
    macaddr = "de:fe:c8:00:00:0${count.index + 1}"
  }
  # not sure exactly what this is for. presumably something about MAC addresses and ignore network changes during the life of the VM
  lifecycle {
    ignore_changes = [
      network,
    ]
  }

  vmid                   = "50${count.index + 1}"
  define_connection_info = false

  timeouts {
    create = "2m"
    delete = "2m"
  }

}

resource "proxmox_vm_qemu" "talos-worker" {
  count = 3                                 # just want 1 for now, set to 0 and apply to destroy VM
  name  = "talos-worker-${count.index + 1}" #count.index starts at 0, so + 1 means this VM will be named test-vm-1 in proxmox
  # this now reaches out to the vars file. I could've also used this var above in the pm_api_url setting but wanted to spell it out up there. target_node is different than api_url. target_node is which node hosts the template and thus also which node will host the new VM. it can be different than the host you use to communicate with the API. the variable contains the contents "prox-1u"
  target_node = data.sops_file.proxmox_secrets.data["pm_host"]
  # another variable with contents "ubuntu-2004-cloudinit-template"
  iso = "local:iso/metal-amd64.iso"
  # basic VM settings here. agent refers to guest agent
  agent   = 1
  cores   = 8
  sockets = 2
  cpu     = "host"
  memory  = 12288
  scsihw  = "virtio-scsi-pci"
  qemu_os = "other"
  #bootdisk = "scsi0"
  onboot = true
  disk {
    slot = 0
    # set disk size here. leave it small for testing because expanding the disk takes time.
    size    = "50G"
    type    = "scsi"
    storage = "local-lvm"
    discard = "on"
  }

  disk {
    slot    = 1
    size    = "25G"
    type    = "scsi"
    storage = "local-lvm"
    discard = "on"
    ssd     = 1
  }

  # if you want two NICs, just copy this whole network section and duplicate it
  network {
    model   = "virtio"
    bridge  = "vmbr6"
    macaddr = "de:fe:c8:00:01:0${count.index + 1}"
  }
  # not sure exactly what this is for. presumably something about MAC addresses and ignore network changes during the life of the VM
  lifecycle {
    ignore_changes = [
      network,
    ]
  }

  vmid                   = "51${count.index + 1}"
  define_connection_info = false

  timeouts {
    create = "2m"
    delete = "2m"
  }

}
