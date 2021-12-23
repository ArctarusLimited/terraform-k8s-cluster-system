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
            "address-pools" = concat([
                {
                    "name" = "private-static"
                    "protocol" = "bgp"
                    "addresses" = ["${cidrhost(var.cluster_subnet_v4, 0)}-${cidrhost(var.cluster_subnet_v4, 31)}"]
                    "auto-assign" = false
                    "avoid-buggy-ips" = true
                },
                {
                    "name" = "private"
                    "protocol" = "bgp"
                    "addresses" = concat(var.cluster_subnet_v6 != null ? [var.cluster_subnet_v6] : [], [
                        # the first /27 of the v4 pool is reserved for static addresses
                        "${cidrhost(var.cluster_subnet_v4, 32)}-${cidrhost(var.cluster_subnet_v4, 255)}"
                    ])
                    "avoid-buggy-ips" = true
                }
            ], var.metallb_extra_pools)
            "peers" = var.metallb_bgp_peers
        })
    }

    depends_on = [kubernetes_namespace.metallb_system]
}
