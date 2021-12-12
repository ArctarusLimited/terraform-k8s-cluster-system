locals {
    metallb_pools = var.cluster_subnet_v6 != null ? [{
        "name" = "private-v6"
        "protocol" = "bgp"
        "addresses" = [var.cluster_subnet_v6]
        "avoid-buggy-ips" = true
    }] : []
}

resource "kubernetes_namespace" "metallb_system" {
    metadata {
        name = "metallb-system"
    }
}

data "kustomization_build" "metallb" {
    path = "${path.module}/manifests/metallb"
}

resource "kustomization_resource" "default" {
    for_each = data.kustomization_build.metallb.ids
    manifest = data.kustomization_build.metallb.manifests[each.value]
    depends_on = [kubernetes_namespace.metallb_system]
}

resource "kubernetes_config_map" "metallb" {
    metadata {
        name = "config"
        namespace = "metallb-system"
    }

    data = {
        config = yamlencode({
            "address-pools" = concat(local.metallb_pools, [
                {
                    # the first /27 is reserved for static addresses
                    "name" = "private-v4-static"
                    "protocol" = "bgp"
                    "addresses" = ["${cidrhost(var.cluster_subnet_v4, 0)}-${cidrhost(var.cluster_subnet_v4, 31)}"]
                    "auto-assign" = false
                    "avoid-buggy-ips" = true
                },
                {
                    "name" = "private-v4"
                    "protocol" = "bgp"
                    "addresses" = ["${cidrhost(var.cluster_subnet_v4, 32)}-${cidrhost(var.cluster_subnet_v4, 255)}"]
                    "avoid-buggy-ips" = true
                }
            ])
            "peers" = var.metallb_bgp_peers
        })
    }

    depends_on = [kubernetes_namespace.metallb_system]
}
