# Network security groups and the internal load balancer in AKS
In this small challenge, you will create a service on an AKS cluster that will configure the NSG for that cluster. Afterwards, you'll configure a new service using the internal load balancer.

## Prerequisites
You will need a cluster to start with this challenge. Run the setup-cluster.sh to create that cluster. If you have an existing cluster, you can skip this step:

```bash
chmod +x setup-cluster.sh
./setup-cluster.sh
```

Now, also deploy the application on top of that cluster.
```bash
kubectl create -f guestbook-without-service.yaml
```
## Step 1: Setting up an NSG through AKS
The way to configure an NSG for traffic control is by setting a special setting on the Kubernetes service. 

First, get your own public IP by browsing to: https://www.what-is-my-ipv4.com/en 

An example is provided in ```front-end-service-secured.yaml```:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: frontend
  labels:
    app: guestbook
    tier: frontend
spec:
  type: LoadBalancer
  ports:
  - port: 80
  selector:
    app: guestbook
    tier: frontend
  loadBalancerSourceRanges:
  - <your public IP address>
```

As you can see, this is a pretty standard service file, with a special configuration in the last 2 lines for the NSG configuration.

Edit this file using the following command:
```
code front-end-service-secured.yaml
```
And add your own public IP address, **with** ```/32``` **appended**.

Deploy this service using:
```bash
kubectl create -f front-end-service-secured.yaml
```
To get the service's IP, run the following command:
```bash
kubectl get svc -w
```
Browse to the front-end service using your browser. This should work. 

Try connecting to the service curl in the cloud shell. This should fail:
```bash
curl <service public IP>
```

Please feel free to explore the NSG in the Azure portal. **You shouldn't make changes to this NSG. This NSG is managed by AKS, and by making manual changes, you risk introducing errors and inconsistencies. **

Once you're done exploring, please delete the service:

```bash
kubectl delete -f front-end-service-secured.yaml
```

## Step 2: Setting up an ILB
By default, if you create a service of type LoadBalancer in Kubernetes, this will create a public Load Balancer. You can optionally also create a service that creates an internal load balancer. 

An example of this is provided in ```front-end-service-internal.yaml```:
```yaml
apiVersion: v1
kind: Service
metadata:
  name: frontend
  annotations:
    service.beta.kubernetes.io/azure-load-balancer-internal: "true"
  labels:
    app: guestbook
    tier: frontend
spec:
  type: LoadBalancer
  ports:
  - port: 80
  selector:
    app: guestbook
    tier: frontend

```
To create this service, use the following command:
```bash
kubectl create -f front-end-service-internal.yaml
```

To get the service's IP, run the following command:
```bash
kubectl get svc -w
```
The first time you run this, this will take a couple minutes to complete, as this will need to spin up a new ILB. But after some time, you should see the service with an internal IP.

Since nothing else is deployed you won't be able to connect to this. If you want to do this, please deploy a VM in a new subnet in the AKS VNET. 

You can explore the ILB in the AKS managed resource group in the Azure portal.

## Step 3: Clean up:
To delete all resources, please use the following command:
```
az group delete -n nsg-ilb-aks --yes

```