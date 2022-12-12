# OpenProject

This is a helm chart for OpenProject. It is nowhere near production ready.
Right now it is just used locally to be developed on.

**Install**

First, clone this repository

```
git clone https://github.com/opf/openproject-helm-chart
cd openproject-helm-chart
```

If not already done, you need to add the dependency repos:

```
helm repo add bitnami https://charts.bitnami.com/bitnami
```

Update dependencies

```
helm dependency build
```

Optional, but recommended: Work in a separate namespace

```
kubectl create namespace openproject
```

Finally, install the application:

```
helm install -n openproject openproject .
```

**Access with minikube**

If you're using minikube, you can try running `minikube tunnel` first.

You can access OpenProject under http://demo.openproject-dev.com.

If you already have services bound locally, try mapping the port explicitly like so:

```
kubectl port-forward -n openproject service/openproject 8080:80
```

**Uninstall**

```
helm uninstall -n openproject openproject
```

Simply uninstalling will not remove any created volume mounts (e.g. for the database and attachments).
If you want to reset those then the easiest way to achieve that is to re-create the namespace:

```
kubectl delete namespace openproject
kubectl create namespace openproject
```

## Things to do

* TLS
* auto scaling
* and many other things
