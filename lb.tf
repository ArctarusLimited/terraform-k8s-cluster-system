locals {
    metallb_pools = var.cluster_subnet_public != null ? [{
        "name" = "public-v4"
        "protocol" = "bgp"
        "addresses" = [var.cluster_subnet_public]
        "auto-assign" = false
        "avoid-buggy-ips" = true
    }] : []
}

resource "helm_release" "metallb" {
    namespace = "kube-system"
    name = "metallb"

    chart = "metallb"
    repository = "https://metallb.github.io/metallb"

    values = [yamlencode({
        "configInline" = {
            "peers" = var.metallb_bgp_peers
            "address-pools" = concat(local.metallb_pools, [
                {
                    # the first /27 is reserved for static addresses
                    "name" = "private-v4-static"
                    "protocol" = "bgp"
                    "addresses" = ["${cidrhost(var.cluster_subnet_private, 0)}-${cidrhost(var.cluster_subnet_private, 31)}"]
                    "auto-assign" = false
                    "avoid-buggy-ips" = true
                },
                {
                    "name" = "private-v4"
                    "protocol" = "bgp"
                    "addresses" = ["${cidrhost(var.cluster_subnet_private, 32)}-${cidrhost(var.cluster_subnet_private, 255)}"]
                    "avoid-buggy-ips" = true
                }
            ])
        }
    })]
}
