RGNAME=ingress-https
AKSNAME=ingress-https

az group create -l westus2 -n $RGNAME
az aks create -n $AKSNAME -g $RGNAME --kubernetes-version 1.19.7