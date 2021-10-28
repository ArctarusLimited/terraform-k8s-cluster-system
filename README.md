# Terraform K8S Bootstrap

## Features

Bootstraps a bare metal Kubernetes cluster with just the necessary core components to deploy FluxCD.

These components will be deployed sequentially:
- CNI (Cilium)
- LB (MetalLB)
- DNS (CoreDNS)

## Usage example

```hcl
module "cluster" {
    source = "github.com/ArctarusLimited/terraform-k8s-bootstrap"

    cluster_type = "cic"
    cluster_dns = "cic.stir1.arctarus.net"
    cluster_vip = "10.8.2.30"

    //cluster_subnet_public = ""
    cluster_subnet_private = "10.8.5.0/24"

    metallb_bgp_peers = [
        {
            "peer-address": "10.8.2.1",
            "peer-asn": 210072,
            "my-asn": 64512
        },
        {
            "peer-address": "2a10:4a80:7::1",
            "peer-asn": 210072,
            "my-asn": 64512
        }
    ]
}
```

## License

MIT Licensed. See [LICENSE](LICENSE) for full details.
