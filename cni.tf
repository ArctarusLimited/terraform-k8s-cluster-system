resource "random_id" "cilium_ipsec" {
    byte_length = 20
}

resource "kubernetes_secret" "cilium_ipsec_keys" {
    metadata {
        namespace = "kube-system"
        name = "cilium-ipsec-keys"
    }

    data = {
        "keys" = "3 rfc4106(gcm(aes)) ${random_id.cilium_ipsec.hex} 128"
    }
}

resource "helm_release" "cilium" {
    namespace = "kube-system"
    name = "cilium"

    chart = "cilium"
    repository = "https://helm.cilium.io"

    values = [yamlencode({
        "rollOutCiliumPods" = true

        # Using MetalLB directly because of:
        # https://github.com/cilium/cilium/issues/16967
        # "bgp" = {
        #     "enabled" = true
        #     "announce" = {
        #         "loadbalancerIP" = true
        #     }
        # }

        "containerRuntime" = {
            "integration" = "containerd"
        }

        "encryption" = {
            "enabled" = true

            # currently broken:
            # see https://github.com/cilium/cilium/issues/13663
            "nodeEncryption" = false
        }

        "hubble" = {
            "relay" = {
                "enabled" = true
                "rollOutPods" = true
            }

            "ui" = {
                "enabled" = true
                "rollOutPods" = true
            }
        }

        "ipam" = {
            "mode" = "kubernetes"
        }

        "ipv6" = {
            "enabled" = true
        }

        "localRedirectPolicy" = {
            "enabled" = true
        }

        # BREAKS NGINX INGRESS - DO NOT USE.
        "sockops" = {
            "enabled" = false
        }

        "operator" = {
            "rollOutPods" = true

            # should hold 2 replicas for clusters of more than 1 node
            "replicas" = var.cluster_redundant ? 2 : 1
        }
    })]

    depends_on = [ kubernetes_secret.cilium_ipsec_keys ]
}

# module "multus" {
#     source = "./../../../terraform/utils/multi_apply"
#     manifest = "${path.module}/../../../manifests/multus-daemonset.yaml"
# }

# module "multus_plugins" {
#     source = "./../../../terraform/utils/multi_apply"
#     manifest = "${path.module}/../../../manifests/multus-plugins.yaml"
# }
