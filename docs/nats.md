# NATS

In Kubernetes, a pod can be allowed to make requests to the Kubernetes API server by creating a `ServiceAccount` with a defined RBAC policy and binding it to the pod. This will then mount a secret JWT token that can be used by the pod to make requests to the Kubernetes API Server.

NATS authorization is [integrated with Kubernetes ServiceAccounts](https://github.com/nats-io/nats-operator/blob/master/docs/usage/svc-account-bound-tokens-integration.md) by using the kubernetes `TokenRequestAPI` that allows issuing a token bound to a `ServiceAccount` usable for accessing audiences other than the Kubernetes API server.  

This means a new token bound to a `ServiceAccount` can be used for accessing a NATS cluster by NATS client pods using the token stored in a secret.

## Deploy NATS using operator

```sh
# Deploy the operator
kubectl apply -f https://github.com/nats-io/nats-operator/releases/latest/download/00-prereqs.yaml
kubectl apply -f https://github.com/nats-io/nats-operator/releases/latest/download/10-deployment.yaml

# Deploy the NATS cluster
kubectl apply -f provisioning/cluster/nats/nats-cluster.yaml
```

## Test NATS connection

```sh

# Deploy a NATS Golang client pod
kubectl apply -f provisioning/cluster/nats/nats-client.yaml

# Exec into the client pod.
kubectl exec -it nats-client -- sh

# Test connection to the cluster by starting a subscriber listening on subject hello.world
nats-sub -s nats://nats-user:`cat /var/run/secrets/nats.io/token`@nats-cluster:4222 hello.world

# Test that a publisher can send message on subject 'hello.world'
nats-pub -s nats://nats-user:`cat /var/run/secrets/nats.io/token`@nats-cluster:4222 hello.world hi
```

