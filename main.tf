provider "libvirt" {
  uri = "qemu:///system"
}

data "template_file" "user_data" {
  template = "${file("${path.module}/templates/cloud_init.cfg")}"
  vars = {
    ssh_key = "${var.ssh_public_key}"
  }
}

data "template_file" "network_config" {
  template = "${file("${path.module}/templates/network_config.cfg")}"
}

resource "libvirt_volume" "centos7-vol" {
  name = "centos7-vol"
  pool = "default"
  source = "https://cloud.centos.org/centos/7/images/CentOS-7-x86_64-GenericCloud.qcow2"
  format = "qcow2"
}


resource "libvirt_volume" "k8smaster-vol" {
  name = "k8smaster-vol"
  base_volume_id = "${libvirt_volume.centos7-vol.id}"
}

resource "libvirt_volume" "k8snode-vol" {
  name = "k8snode${count.index}-vol"
  base_volume_id = "${libvirt_volume.centos7-vol.id}"
  count = "${var.k8s_num_nodes}"
}

resource "libvirt_cloudinit_disk" "commoninit" {
  name = "commoninit.iso"
  user_data = "${data.template_file.user_data.rendered}"
  network_config = "${data.template_file.network_config.rendered}"
}

resource "libvirt_network" "k8snet" {
  name = "k8snet"
  mode = "nat"
  domain = "k8s.local"
  addresses = ["10.1.1.0/24"]
  dns = {
      enabled = true
      local_only = true
  }
}

resource "libvirt_domain" "k8smaster-dom" {
  name   = "k8smaster-dom"
  memory = "2048"
  vcpu   = 2

  network_interface {
    network_id = "${libvirt_network.k8snet.id}"
    wait_for_lease = true
    hostname = "k8smaster"
  }

  disk {
    volume_id = "${libvirt_volume.k8smaster-vol.id}"
  }

  cloudinit = "${libvirt_cloudinit_disk.commoninit.id}"

  console {
    type = "pty"
    target_type = "serial"
    target_port = "0"
  }

  graphics {
    type = "spice"
    listen_type = "address"
    autoport = true
  }

  # provisioner "local-exec" {
  #     command = "echo \"[master]\nk8smaster ansible_host=${join("\n",self.network_interface.0.addresses)}\" >> ./hosts.ini" 
  # }

}

resource "libvirt_domain" "k8snode-dom" {
  name   = "k8snode${count.index}-dom"
  memory = "2048"
  vcpu   = 2
  count = "${var.k8s_num_nodes}"

  network_interface {
    network_id = "${libvirt_network.k8snet.id}"
    wait_for_lease = true
    hostname = "k8snode${count.index + 1}"
  }

  disk {
    volume_id = "${element(libvirt_volume.k8snode-vol.*.id, count.index)}"
  }

  cloudinit = "${libvirt_cloudinit_disk.commoninit.id}"

  console {
    type = "pty"
    target_type = "serial"
    target_port = "0"
  }

  graphics {
    type = "spice"
    listen_type = "address"
    autoport = true
  }

  # provisioner "local-exec" {
  #     command = "echo \"k8snode${count.index + 1} ansible_host=${join("\n",self.network_interface.0.addresses)}\""
  # }

}

