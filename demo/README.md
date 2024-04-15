# Demo for OpenProject on Kubernetes

This demo will show you how to install OpenProject on a Kubernetes cluster using Helm. Attachments will be stored on an S3-compatible Object Storage, and a TLS certificate will be automatically generated with Let's Encrypt.

We assume that you have already created a Kubernetes cluster and are able to connect to it using `kubectl`.

## Prerequisites

1. Add OpenProject helm chart repository:

```bash
helm repo add openproject https://charts.openproject.org
helm repo update
```

2. Install ingress-nginx and cert-manager for automatic Let's Encrypt certificate generation:

   Note that you should only do this if you do not yet have another way of generating TLS certificates in your cluster.

```bash
helm upgrade --install ingress-nginx ingress-nginx \
   --repo https://kubernetes.github.io/ingress-nginx \
   --namespace ingress-nginx --create-namespace \
   --set controller.replicaCount=2
```

```bash
helm upgrade cert-manager cert-manager --install \
   --repo https://charts.jetstack.io \
   --namespace cert-manager \
   --create-namespace \
   --set installCRDs=true
```

3. Create the `openproject` namespace:

```bash
kubectl create namespace openproject
```

3. Create the issuer for Let's Encrypt, in the

```bash
cp config/issuer.example.yaml config/issuer.yaml
```

Edit `config/issuer.yaml` with your email address, then apply:

```bash
kubectl apply -f config/issuer.yaml --namespace openproject
```

4. Find your ingress-nginx ingress controller's external IP address:

```
kubectl get service ingress-nginx-controller -n ingress-nginx
```

You can then use the result to configure an A record for your domain in your DNS provider. In this demo I will point `demo-k8s.openproject-edge.eu` at the IP `51.158.59.132`.

```
NAME TYPE CLUSTER-IP EXTERNAL-IP PORT(S) AGE
ingress-nginx-controller LoadBalancer 10.45.50.118 51.158.59.132 80:30341/TCP,443:32421/TCP 62m
```

## Configure your installation

Copy the example values file:

```bash
cp config/values.example.yaml config/values.yaml
```

Edit the file and set:

- The domain name to use.
- Your object storage credentials.

## Install OpenProject

Once the prerequisites and your `config/values.yaml` file are in place, you can now deploy OpenProject:

```bash
helm upgrade \
   --wait \
   --namespace openproject \
   --install openproject \
   --values config/values.yaml \
   openproject/openproject
```

At the end of the installation, your OpenProject URL will be displayed, and you can now connect using the default admin credentials:

- username: `admin`
- password: `admin`

## Uninstall

You can simply remove the entire `openproject` namespace:

```
kubectl delete namespace openproject
```

## Troubleshooting

Output the generated YAML files:

```yaml
helm template --debug --create-namespace --namespace openproject \
--values config/values.yaml \
openproject openproject/openproject
```
