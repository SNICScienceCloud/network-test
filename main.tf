variable cluster_prefix {
  description = "Cluster prefix"
}

variable ssh_key {
  description = "Local path to SSH key"
}

variable ssh_key_pub {
  description = "Local path to public SSH key"
}

variable node_count {
  description = "Number of nodes to deploy"
}

variable command {
  description = "Command to run on the nodes"
}

resource "openstack_compute_keypair_v2" "keypair" {
  name       = "${var.cluster_prefix}-keypair"
  public_key = "${file(var.ssh_key_pub)}"
}

module "secgroup" {
  source              = "mcapuccini/rke/openstack//modules/secgroup"
  name_prefix         = "${var.cluster_prefix}"
  allowed_ingress_tcp = [22]
}

module "network" {
  source              = "mcapuccini/rke/openstack//modules/network"
  name_prefix         = "${var.cluster_prefix}"
  external_network_id = "af006ff3-d68a-4722-a056-0f631c5a0039"
}

resource "openstack_compute_instance_v2" "instance" {
  count       = "${var.node_count}"
  name        = "${var.cluster_prefix}-${format("%03d", count.index)}"
  image_name  = "Ubuntu 16.04 LTS (Xenial Xerus) - latest"
  flavor_name = "ssc.xlarge"
  key_pair    = "${openstack_compute_keypair_v2.keypair.name}"

  network {
    name = "${module.network.network_name}"
  }

  security_groups = ["${module.secgroup.secgroup_name}"]
}

resource "openstack_compute_floatingip_v2" "floating_ip" {
  count = 1
  pool  = "Public External IPv4 network"
}

resource "openstack_compute_floatingip_associate_v2" "associate_floating_ip" {
  count       = 1
  floating_ip = "${element(openstack_compute_floatingip_v2.floating_ip.*.address, 0)}"
  instance_id = "${element(openstack_compute_instance_v2.instance.*.id, 0)}"
}

resource null_resource "prepare_nodes" {
  count = "${var.node_count}"

  triggers {
    instance_id = "${element(openstack_compute_instance_v2.instance.*.id, count.index)}-${timestamp()}"
  }

  provisioner "remote-exec" {
    connection {
      bastion_host     = "${openstack_compute_floatingip_v2.floating_ip.address}"
      bastion_host_key = "${file(var.ssh_key)}"
      host        = "${element(openstack_compute_instance_v2.instance.*.network.0.fixed_ip_v4, count.index)}"
      user        = "ubuntu"
      private_key = "${file(var.ssh_key)}"
    }

    inline = [
      "${var.command}"
    ]
  }
}
