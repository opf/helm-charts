# Development

In this document we try to give some useful tips on how to develop the [helm chart](./charts/openproject/) locally.

For that you will need to install a local kubernetes cluster and simply install the chart on it.

## Prerequisites

No matter which kubernetes cluster you use, you will need the following tools.

* docker
* kubectl
* helm

## Development kubernetes clusters

As for kubernetes, there are multiple choices such as:

* minikube
* k3d

### k3d

Following the instructions on [k3d.io](https://k3d.io/stable/#installation) to install `k3d`.
Once you have done that, you can simply create the cluster as follows.

```bash
k3d cluster create -p "80:80@loadbalancer" default
```

This will create the cluster `k3d-default` and also add it to your `~/.kube/config`.
The `-p` option here maps your local machines port 80 to the cluster.
Any ingress created on the cluster will be reachable this way directly,
as long as you point the chosen host name to localhost.

> *.openproject-dev.com points to localhost already, so you could simply use any subdomain of that for development.
> For instance: helm.openproject-dev.com

You can of course change the port (the first 80:) to something else if needed.

## Installing the chart

Under [dev/values.yaml] is an example `values.yaml` file you can use and build on to test the OpenProject chart locally.

Install it as follows.

```bash
helm upgrade --install --create-namespace -n openproject openproject -f dev/valuyes.yaml charts/openproject/
```

Assuming you have your kubernetes cluster set up and exposed on port 80, you can now access OpenProject under
[http://helm.openproject-dev.com](http://helm.openproject-dev.com).

You can create your own file adding to and overriding values in the `dev/values.yaml` and pass that with
an additional `-f` option in the command above.
