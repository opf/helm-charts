# OpenProject

This is a helm chart for OpenProject. It is nowhere near production ready.
Right now it is just used locally to be developed on.

**Install**

```
helm install -n openproject openproject .
```

**Access**

> Note: If using minikube run `minikube tunnel` first

You can access OpenProject under http://demo.openproject-dev.com.

**Uninstall**

```
helm uninstall -n openproject openproject
```

## Things to do

* TLS
* auto scaling
* and many other things
