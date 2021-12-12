locals {
    # CIC clusters use their own DNS servers; otherwise, the host's DNS is used.
    primary_upstream = var.cluster_type == "cic" ? cidrhost(var.cluster_subnet_v4, 5) : "/etc/resolv.conf"
}

resource "helm_release" "coredns" {
    namespace = "kube-system"

    name = "coredns"
    chart = "${path.module}/charts/coredns-1.16.3-custom.tgz"

    values = [yamlencode({
        "nameOverride" = "kube-dns"

        "service" = {
            "name" = "kube-dns"

            # see v1alpha1_clusterconfig.go in talos
            "clusterIP" = "172.31.0.10"

            # only set for non-CIC, takes the 5th IP in the reserved range
            "loadBalancerIP" = var.cluster_type == "cic" ? "" : cidrhost(var.cluster_subnet_v4, 5)
        }

        # CIC is forwarded via the site DNS instance; all others go through a load balancer
        "serviceType" = var.cluster_type == "cic" ? "ClusterIP" : "LoadBalancer"

        "servers" = [{
            "zones" = [{
                "zone" = "."
            }]
            "port" = 53
            "plugins" = [
                {
                    "name" = "errors"
                },
                {
                    # Serves a /health endpoint on :8080, required for livenessProbe
                    "name" = "health"
                    "configBlock" = "lameduck 5s"
                },
                {
                    # Serves a /ready endpoint on :8181, required for readinessProbe
                    "name" = "ready"
                },
                {
                    # Makes the API server DNS resolvable
                    "name" = "template"
                    "parameters" = "IN A ANY kube.${var.cluster_dns}"
                    "configBlock" = <<EOT
answer "{{ .Name }} 60 IN A ${var.cluster_vip}"
fallthrough
EOT
                },
                {
                    # Makes the UI server DNS resolvable
                    "name" = "rewrite"
                    "parameters" = "name ui.${var.cluster_dns} ingress-nginx-controller.infra-system.${var.cluster_dns}"
                },
                {
                    # Makes the IDP server DNS resolvable
                    "name" = "rewrite"
                    "parameters" = "name idp.${var.cluster_dns} ingress-nginx-controller.infra-system.${var.cluster_dns}"
                },
                {
                    # Makes the Boundary Worker server DNS resolvable
                    "name" = "rewrite"
                    "parameters" = "name boundary-worker.${var.cluster_dns} boundary-worker.infra-system.${var.cluster_dns}"
                },
                {
                    # Required to query kubernetes API for data
                    "name" = "kubernetes"
                    "parameters" = "cluster.local in-addr.arpa ip6.arpa"
                    "configBlock" = <<EOT
pods insecure
fallthrough in-addr.arpa ip6.arpa
ttl 30
EOT
                },
                {
                    "name" = "k8s_external"
                    "parameters" = var.cluster_dns
                },
                {
                    # Serves a /metrics endpoint on :9153, required for serviceMonitor
                    "name" = "prometheus"
                    "parameters" = "0.0.0.0:9153"
                },
                {
                    "name" = "forward"

                    # fall back on the host's DNS if the primary upstream fails
                    # (or for CIC site controllers, isn't bootstrapped yet)
                    "parameters" = ". ${local.primary_upstream} /etc/resolv.conf"
                    "configBlock" = <<EOT
policy sequential
EOT
                },
                {
                    "name" = "cache"
                    "parameters" = 30
                },
                {
                    "name" = "reload"
                },
                {
                    "name" = "loadbalance"
                }
            ]
        }]
    })]
}
