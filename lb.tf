locals {
    metallb_pools = var.cluster_subnet_v6 != null ? [{
        "name" = "private-v6"
        "protocol" = "bgp"
        "addresses" = [var.cluster_subnet_v6]
        "avoid-buggy-ips" = true
    }] : []
}

resource "helm_release" "metallb" {
    namespace = "kube-system"
    name = "metallb"

    chart = "metallb"
    version = "0.11.0"
    repository = "https://metallb.github.io/metallb"

    values = [yamlencode({
        "configInline" = {
            "peers" = var.metallb_bgp_peers
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
        }
        # temporarily use main
        # because we need urgent ipv6 support
        "controller" = {
            "image" = {
                "tag" = "0.9.6"
                "pullPolicy" = "Always"
                "repository" = "ghcr.io/arctaruslimited/metallb-controller"
            }
        }
        "speaker" = {
            "image" = {
                "tag" = "0.9.6"
                "pullPolicy" = "Always"
                "repository" = "ghcr.io/arctaruslimited/metallb-speaker"
            }
        }
    })]
}
