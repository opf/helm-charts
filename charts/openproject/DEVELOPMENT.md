# Development

## Quick start

To install or update from this directory (charts/openproject) run the following command.

```bash
bin/install-dev
```

This will make OpenProject accessible under [http://helm.openproject-dev.com](http://helm.openproject-dev.com])
if your kubernetes cluster is exposed on localhost.

> You can set other options just like when installing via `--set`
> (e.g. `bin/install-dev --set persistence.enabled=false`).

### Debugging

Changes to the chart can be debugged using the following.

```bash
bin/debug
```

This will try to render the templates and show any errors.
You can set values just like when installing via `--set`
(e.g. `bin/debug --set persistence.enabled=false`).

## Local development

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
* kind

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

Under [bin/install-dev] is a script you can use and build on to test the OpenProject chart locally.

Use it as follows.

```bash
bin/install-dev
```

This will install the chart with `--set develop=true` which is recommended
on local clusters.

This will also set `OPENPROJECT_HTTPS` to false so no TLS certificate is required
to access it. It will also disable TLS in other places where needed.

Assuming you have your kubernetes cluster set up and exposed on port 80, you can now access OpenProject under
[http://helm.openproject-dev.com](http://helm.openproject-dev.com).

You can create your own file adding to and overriding values and pass that with
an additional `-f` option in the command above. For instance `bin/install-dev -f my-values.yaml`.
