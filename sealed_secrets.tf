resource "helm_release" "sealed_secrets" {
    namespace = "kube-system"
    name = "sealed-secrets-controller"

    version = "1.16.1"
    chart = "sealed-secrets"
    repository = "https://bitnami-labs.github.io/sealed-secrets"
}
