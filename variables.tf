variable "ssh_public_key" {
   type = "string"
   default = ""
}

variable "k8s_cluster_name" {
  type = "string"
  default = "k8slab"
}

variable "k8s_num_nodes" {
  type = "string"
  default = "3"
}
