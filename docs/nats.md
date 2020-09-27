# NATS

NATS authorization is [integrated with Kubernetes ServiceAccounts](https://github.com/nats-io/nats-operator/blob/master/docs/usage/svc-account-bound-tokens-integration.md) by using the kubernetes TokenRequestAPI that allows creating a new token bound to a `ServiceAccount` usable only by NATS clients of a NATS cluster stored in a secret.

## Deploy NATS using operator

```sh
# Deploy the operator
kubectl apply -f https://github.com/nats-io/nats-operator/releases/latest/download/00-prereqs.yaml
kubectl apply -f https://github.com/nats-io/nats-operator/releases/latest/download/10-deployment.yaml

# Deploy the NATS cluster
kubectl apply -f provisioning/cluster/nats/nats-cluster.yaml

```
