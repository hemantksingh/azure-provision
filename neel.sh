 #!/bin/bash -e

#
# Neel - The Azure CLI Wrapper
#

# -e: exit right away on an error
# $?: get the exit status of the last command, exit status 0 -> success


az_login() {
    if [[ -z "$AZURE_CLIENT_ID" ]] && [[ -z "$AZURE_CLIENT_SECRET"  ]] && [[ -z "$AZURE_TENANT_ID" ]] ; then
        echo "Azure Login using sourced ini creds..."
        # source <(grep = ~/.azure/credentials)
        az login --service-principal -u $client_id -p $secret -t $tenant
    else
        echo "Azure Login using env vars..."
        az login --service-principal -u $AZURE_CLIENT_ID -p $AZURE_CLIENT_SECRET -t $AZURE_TENANT_ID
    fi  
}

aks_get_credentials() {
    res_group=$1; cluster_name=$2
    echo "Getting AKS credentials..."
    az aks get-credentials -g $AKS_RESOURCE_GROUP -n $AKS_CLUSTER_NAME --overwrite-existing
}

aks_await_lb_assginment() {
    service=$1; namespace=${2:-default};
    echo $namespace $service
    external_ip=""
    while [ -z $external_ip ]; do
        echo "Waiting for end point..."
        external_ip=$(kubectl get svc $service --template="{{range .status.loadBalancer.ingress}}{{.ip}}{{end}}" -n $namespace)
        ((maxTries++)) && ((maxTries==6)) && break
        [ -z "$external_ip" ] && sleep 10
    done

    if [ -z "$external_ip" ]; then
        echo 'Failed to get load balancer IP, exceeded the max number of tries';
        return 1
    else
        echo 'End point ready:' && echo $external_ip
    fi
}

az_login
aks_get_credentials

echo "Deploying nginx ingress controller..."
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-0.32.0/deploy/static/provider/cloud/deploy.yaml

aks_await_lb_assginment 'ingress-nginx-controller' 'ingress-nginx'