# Ingress controller

The kubernetes Service API provides ingress routes to your applications, but it uses limited layer 4 routing. In order to route external traffic to your application running within the AKS cluster and expose multiple services under the same IP address we use an ingress controller for layer 7 routing.

## Deploy haproxy ingress controller

Deploy haproxy controller using kubernetes manifests as specified [here](https://github.com/jcmoraisjr/haproxy-ingress/tree/master/examples/deployment)

```sh
# Deploy ingress controller
kubectl apply -f ingress-controller/haproxy-ingress-controller.yaml

# Test the ingress
LOADBALANCERIP=$(kubectl get service haproxy-ingress -o jsonpath='{ .status.loadBalancer.ingress[].ip }' -n ingress-haproxy)
HOSTNAME=lolcat.azure.com
curl -v -k https://$HOSTNAME --resolve $HOSTNAME:443:$LOADBALANCERIP
```

## Deploy nginx ingress controller

Nginx controller can be configured to set up [client certificate authentication](https://kubernetes.github.io/ingress-nginx/examples/auth/client-certs/) with your own certificates by using the [auth-tls annotations](https://kubernetes.github.io/ingress-nginx/user-guide/nginx-configuration/annotations/#client-certificate-authentication)

There are [multiple ways](https://docs.nginx.com/nginx-ingress-controller/overview/) of deploying nginx ingress controllers, but we look at 2 below:

### Deploy with kubernetes manifests

`kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-0.32.0/deploy/static/provider/cloud/deploy.yaml`

To fulfill ingress to your application, the nginx ingress controller deployment provisions a load balancer in Azure and assigns it a public IP. Before deploying an application to the aks cluster, you have to [wait until an external IP is assigned to the load balancer](https://stackoverflow.com/questions/35179410/how-to-wait-until-kubernetes-assigned-an-external-ip-to-a-loadbalancer-service) in order for your application to be made accessible externally.

### Deploy with nginx ingress operator

Deploy the latest ingress operator by following the instructions [here](https://github.com/nginxinc/nginx-ingress-operator/blob/master/docs/manual-installation.md). The current nginx ingress operator version is v0.0.6:

```sh
export OPERATOR_GITHUB_URL=https://raw.githubusercontent.com/nginxinc/nginx-ingress-operator/v0.0.6

# Add the CRD
kubectl apply -f ${OPERATOR_GITHUB_URL}/deploy/crds/k8s.nginx.org_nginxingresscontrollers_crd.yaml

# Deploy the operator
kubectl apply -f ${OPERATOR_GITHUB_URL}/deploy/service_account.yaml

kubectl apply -f ${OPERATOR_GITHUB_URL}/deploy/role.yaml

kubectl apply -f ${OPERATOR_GITHUB_URL}/deploy/role_binding.yaml

kubectl apply -f ${OPERATOR_GITHUB_URL}/deploy/operator.yaml

# Deploy the ingress controller
kubectl apply -f ingress-controller/nginx-ingress-controller.yaml
```

### Troubleshooting ingress controller

You can monitor the incoming requests to your applications and changes in ingress configuration by looking at the ingress controller logs:

https://github.com/kubernetes/ingress-nginx/blob/master/docs/troubleshooting.md
