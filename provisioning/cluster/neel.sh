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
    az aks get-credentials -g $res_group -n $cluster_name --overwrite-existing
}

k8_await_lb_assginment() {
    service=$1; namespace=${2:-default}; external_ip="";
    while [ -z $external_ip ]; do
        external_ip=$(kubectl get svc $service --template="{{range .status.loadBalancer.ingress}}{{.ip}}{{end}}" -n $namespace)
        ((maxAttempts++)) && ((maxAttempts==6)) && break
        echo "Waiting for load balancer IP... attempt $maxAttempts"
        [ -z "$external_ip" ] && sleep 10
    done

    set -e # handle result in a subshell to ensure execution halts on failure 
    if [ -z "$external_ip" ]; then
        echo 'Failed to get load balancer IP, exceeded the max number of tries';
        return 1
    else
        echo 'Load balancer IP ready:' && echo $external_ip
    fi
}

# az_login
aks_get_credentials $AKS_RESOURCE_GROUP $AKS_CLUSTER_NAME

echo "Deploying nginx ingress controller..."
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-0.32.0/deploy/static/provider/cloud/deploy.yaml

k8_await_lb_assginment 'ingress-nginx-controller' 'ingress-nginx'