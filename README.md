# OpenProject

This is a helm chart for OpenProject. It is nowhere near production ready.
Right now it is just used locally to be developed on.

**Install**

```
helm dependency build # run once to fetch dependencies
kubectl create namespace openproject # we recommend working in a separate namespace

helm install -n openproject openproject .
```

**Access**

> Note: If using minikube run `minikube tunnel` first

You can access OpenProject under http://demo.openproject-dev.com.

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
