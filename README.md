# OpenProject Helm Chart

OpenProject is a web-based project management system for location-independent team collaboration.

## TL;DR

```bash
helm repo add openproject https://opf.github.io/helm-charts
helm upgrade --install my-openproject openproject/openproject
```

## Introduction

This chart bootstraps an OpenProject instance and optional with PostgreSQL database and instance and Memcached.

## Prerequisites
- Kubernetes 1.16+
- Helm 3.0.0+
- PV provisioner support in the underlying infrastructure

## Installing the Chart

To install the chart with the release name my-openproject:

```bash
helm upgrade --install my-openproject openproject/openproject
```

## Uninstalling the Chart

To install the release with name my-openproject:

```bash
helm uninstall my-openproject
```
