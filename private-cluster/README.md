# Private cluster
In this challenge you'll create a private AKS cluster. To do this, you'll first create a VNET with 2 subnets, and then create the private cluster. Afterwards, you'll create a VM in that VNET to connect to the kubernetes API.

## Step 1: Creating a new VNET
First, let's create a new VNET with two subnets. To do so, you'll also need a new resource group.

```bash
az group create -l westus2 -n private-aks

az network vnet create -o table \
    --resource-group private-aks \
    --name vnet-aks \
    --address-prefixes 192.168.0.0/16 \
    --subnet-name akssubnet \
    --subnet-prefix 192.168.0.0/24
az network vnet subnet create \
  --resource-group private-aks \
  --vnet-name vnet-aks \
  --name vmsubnet \
  --address-prefix 192.168.1.0/24
AKS_SUBNET_ID=`az network vnet subnet show \
  --resource-group private-aks \
  --vnet-name vnet-aks \
  --name akssubnet --query id -o tsv`
VM_SUBNET_ID=`az network vnet subnet show \
  --resource-group private-aks \
  --vnet-name vnet-aks \
  --name vmsubnet --query id -o tsv`
```

## Step 2: Create private AKS cluster
In order to create a private AKS cluster in a pre-existing VNET, you'll need to pass an identity to AKS that it can use to deploy the cluster in that VNET.

To create the managed identity and give it access to your subnet, use the following commands:
```bash
az identity create --name privateaks-mi \
  --resource-group private-aks
IDENTITY_CLIENTID=`az identity show --name privateaks-mi \
  --resource-group private-aks \
  --query clientId -o tsv`
az role assignment create --assignee $IDENTITY_CLIENTID \
  --scope $AKS_SUBNET_ID --role Contributor
IDENTITY_ID=`az identity show --name privateaks-mi \
  --resource-group private-aks \
  --query id -o tsv` 
```
The preceding code will first create the managed identity. Afterwards, it gets the client ID of the managed identity and grants that access to the subnet. In the final command, it is getting the resource ID of the managed identity.


Finally, you can go ahead and create the private AKS cluster using the following command. As you might notice, you are creating a smaller cluster using only 1 node. This is to conserve core quota on the free trial subscription:

```bash
az aks create \
  --resource-group private-aks \
  --name private-aks \
  --vnet-subnet-id $AKS_SUBNET_ID \
  --enable-managed-identity \
  --assign-identity $IDENTITY_ID \
  --enable-private-cluster \
  --node-count 1 \
  --node-vm-size Standard_DS2_v2 \
  --generate-ssh-keys
  ```

If you want to give it a try, try connecting to the kubernets API server. 

```
az aks get-credentials \
  --resource-group private-aks \
  --name private-aks 
kubectl get nodes
```
This will fail, as expected. From Cloud Shell, you won't be able to connect to the private API endpoint. 

# Step 3: Creating a VM to access Kubernetes API
Let's now create a VM in the other subnet that was created. From that VM, you can access the Kubernetes API.

```bash
az vm create --name vm-aks \
  --resource-group private-aks \
  --image UbuntuLTS \
  --admin-username azureuser \
  --ssh-key-values ~/.ssh/id_rsa.pub \
  --subnet $VM_SUBNET_ID \
  --size Standard_D2_v2
```
The output of this command should contain the public IP of that VM. SSH into the VM to access the Kubernetes API server:

```
ssh azureuser@<public IP>
```

From within the VM, install the Azure-CLI, login to the Azure CLI, get the AKS-credentials and then access the kubernetes api server:
```
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
az login #this will ask you to login using browser
az aks get-credentials \
  --resource-group private-aks \
  --name private-aks 
sudo az aks install-cli
kubectl get nodes
```

AKS private clusters rely on a private DNS to function. By default, a DNS zone is created for you (encourage you to explore this in the portal); but you could use your own zone as well if needed.

You can see the DNS being used using the following command:
```
kubectl cluster-info
```

## step 4: clean-up
To clean up the resources created, please use:
```bash
az group delete -n private-aks --yes
```