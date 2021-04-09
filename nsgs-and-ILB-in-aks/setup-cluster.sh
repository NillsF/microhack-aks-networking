RGNAME=nsg-ilb-aks
AKSNAME=nsg-ilb-aks

az group create -l westus2 -n $RGNAME
az aks create -n $AKSNAME -g $RGNAME --kubernetes-version 1.19.7

az aks get-credentials -n $AKSNAME -g $RGNAME