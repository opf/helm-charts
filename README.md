# OpenProject Helm Chart

OpenProject is a web-based project management system for location-independent team collaboration.

## TL;DR

```bash
helm repo add openproject https://charts.openproject.org
helm upgrade --install my-openproject openproject/openproject
```

## Introduction

This chart bootstraps an OpenProject instance and optional with PostgreSQL database and instance and Memcached.

## Prerequisites
- Kubernetes 1.16+
- Helm 3.0.0+
- PV provisioner support in the underlying infrastructure

## Installing the Chart

You can install the chart with the release name `my-openproject` in its own namespace like this:

```bash
helm upgrade --create-namespace --namespace openproject --install my-openproject openproject/openproject
```

The namespace is optional, but using it does make it easier to manage the resources
created for OpenProject.

## Uninstalling the Chart

To install the release with name my-openproject:

```bash
helm uninstall --namespace openproject my-openproject
```

> **Note**: This will not remove the persistent volumes created while installing.
> The easiest way to ensure all PVCs are deleted as well is to delete the openproject namespace
> (`kubectl delete namespace openproject`). If you installed OpenProject into the default
> namespace, you can delete the volumes manually one by one.
