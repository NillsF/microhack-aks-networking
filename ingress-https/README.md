# Ingress and HTTPS
In this challenge, you will build an AKS cluster and integrate it with the Application Gateway Ingress Controller. 

## Prerequisites
You will need a cluster to start with this challenge. Run the setup-cluster.sh to create that cluster. 

```bash
chmod +x setup-cluster.sh
./setup-cluster.sh
```

## Step 1: Setting up networking
In the previous step, you created an AKS cluster without specifying a VNET. This means the ```az aks create``` command created a VNET for you.

To create an application gateway, you will need a new network. 

Create a new VNET, and peer it with the AKS vnet:
```bash
az network vnet create -n agic-vnet -g ingress-https \
  --address-prefix 192.168.0.0/24 --subnet-name agic-subnet \
  --subnet-prefix 192.168.0.0/24
```

Once this VNET has been created, peer it with the AKS VNET.

_Note: the command az network vnet list might be delayed in showing the VNET in the AKS resource group. If you run into issues with the commands below, be patient and try again after a minute._

```bash
nodeResourceGroup=$(az aks show -n ingress-https \
  -g ingress-https -o tsv --query "nodeResourceGroup")
aksVnetName=$(az network vnet list \
  -g $nodeResourceGroup -o tsv --query "[0].name")

aksVnetId=$(az network vnet show -n $aksVnetName \
  -g $nodeResourceGroup -o tsv --query "id")

az network vnet peering create \
  -n AppGWtoAKSVnetPeering -g ingress-https \
  --vnet-name agic-vnet --remote-vnet $aksVnetId \
  --allow-vnet-access

appGWVnetId=$(az network vnet show -n agic-vnet \
  -g ingress-https -o tsv --query "id")

az network vnet peering create \
  -n AKStoAppGWVnetPeering -g $nodeResourceGroup \
  --vnet-name $aksVnetName --remote-vnet $appGWVnetId --allow-vnet-access
```

## Step 2: Creating an application gateway
Now that the networking has been setup, you can create your application gateway. You can create the app gateway using the following command (**make sure to provide a DNS prefix**):

```bash
az network public-ip create -n agic-pip \
   -g ingress-https --allocation-method Static --sku Standard \
   --dns-name "<your unique DNS name>"

az network application-gateway create -n agic -l westus2 \
  -g ingress-https --sku Standard_v2 --public-ip-address agic-pip \
  --vnet-name agic-vnet --subnet agic-subnet

```

This will take a couple minutes to complete. 

## Step 3: Setting up the Application Gateway ingress controller

You are now ready to enable the application gateway ingress controller:

```bash
appgwId=$(az network application-gateway \
  show -n agic -g ingress-https -o tsv --query "id") 
az aks enable-addons -n ingress-https \
  -g ingress-https -a ingress-appgw \
  --appgw-id $appgwId
```

This will take about a minute to complete. 

## Step 4: Creating an ingress, without HTTPS
You will need an application to expose. As an application, you'll use the guestbook demo application. Deploy this application using:

```bash
kubectl create -f guestbook-all-in-one.yaml
```

Once the application is created, you can create an ingress in Kubernetes. This is provided in the file ```simple-frontend-ingress.yaml```.

The ingress object looks like this:
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: simple-frontend-ingress
  annotations:
    kubernetes.io/ingress.class: azure/application-gateway
spec:
  rules:
  - http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: frontend
            port: 
              number: 80
```

As you can see, this is an Ingress object, with ingress.class az azure/application-gateway. It's sending all traffic to the frontend service.

To create this, run:
```bash
kubectl create -f simple-frontend-ingress.yaml
```

It will take a couple of minutes for the end-to-end configuration to flow through to the application gateway. After a couple of minutes, you should be able to connect to the public IP of your application gateway and see your application. 

To get the public IP of the app gateway, either use the Azure portal, or use the following command:

```bash
az network public-ip show -n agic-pip \
   -g ingress-https 
```

Once you were able to create this Ingress, please delete it before moving on to the next step:
```bash
kubectl delete -f simple-frontend-ingress.yaml
```



## Step 5: Creating an Ingress using HTTPS
Next up, you'll add HTTPS to your ingress. To do this, you'll need to:
1. Install the cert-manager add-on in AKS
2. Create a certificate issuer, pointing to let's encrypt in this example
3. Create a new ingress, configuring HTTPS

Let's do this:
To install cert-manager, please run the following command:
```bash
kubectl apply -f https://github.com/jetstack/cert-manager/releases/download/v1.1.0/cert-manager.yaml  
```

Next, you'll configure a certificate issuer. 

You will need to change the e-mail address in this file. To do so, use the following command:
```bash
code certificate-issuer.yaml
```
And add your own e-mail address.
Please, also notice int he issuer how this is pointing the let's encrypt staging. We're using staging to avoid hitting production let's encrypt throttles.

Then, create the issuer:
```bash
kubectl create -f certificate-issuer.yaml
```

And now, you're ready to deploy an Ingress using HTTPS.

First, you'll need to add your own DNS prefix to the ingress definition. To do this, use the following command:
```bash
code ingress-with-tls.yaml
```

Once that is saved, you can create that ingress using:
```bash
kubectl create -f ingress-with-tls.yaml
```

To follow the creation of the certificate, you can use the following command:
```bash
kubectl get certificate -w
```
This should show you the certificate was issued after about 1 minute.
For more details, you can use different kubectl commands, such as ```kubectl describe certificate``` and ```kubectl describe certificaterequest```

Now, browse to your unique DNS name. Please add HTTPS in front of the URL. You should get an invalid certificate warning (because you're using a staging server), but the website will be served over HTTPS.

## Step 6: cleanup

To clean up all the resources that were created, use the following command:
```bash
az group delete -n ingress-https --yes
```