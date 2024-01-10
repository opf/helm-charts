# Helm chart for OpenProject

This is the chart for OpenProject itself. It bootstraps an OpenProject instance, optionally with a PostgreSQL database and Memcached.

## Prerequisites

- Kubernetes 1.16+
- Helm 3.0.0+
- PV provisioner support in the underlying infrastructure


## Helm chart Provenance and Integrity

We sign our chart using the [Helm Provenance and Integrity](https://helm.sh/docs/topics/provenance/) functionality. You can find the used public key here

- https://github.com/opf/helm-charts/blob/main/signing.key
- https://keys.openpgp.org/vks/v1/by-fingerprint/CB1CA0488A75B7471EA1B087CF56DD6A0AE260E5

We recommend using the [Helm GnuPG plugin](https://github.com/technosophos/helm-gpg). With it you can manually verify the signature like this:

```bash
helm repo add openproject https://charts.openproject.org
helm fetch --prov openproject/openproject
helm gpg verify openproject-*.tgz
```

## Installation

### Quick start

```shell
helm repo add openproject https://charts.openproject.org
helm upgrade --create-namespace --namespace openproject --install my-openproject openproject/openproject
```

You can also install the chart with the release name `my-openproject` in its own namespace like this:

```shell
helm upgrade --create-namespace --namespace openproject --install my-openproject openproject/openproject
```

The namespace is optional, but we recommend it as it does make it easier to manage the resources created for OpenProject.

## Configuration

Configuration of the chart takes place through defined values, and a catch-all entry `environment` to provide all possible variables through ENV that OpenProject supports. To get more information about the possible values, please see [our guide on environment variables](https://www.openproject.org/docs/installation-and-operations/configuration/environment/).



### Available OpenProject specific helm values

We try to map the most common options to chart values directly for ease of use. The most common ones are listed here, feel free to extend available values [through a pull request](https://github.com/opf/helm-charts/).



**OpenProject image and version**

By default, the helm chart will target the latest stable major release. You can define a custom [supported docker tag](https://hub.docker.com/r/openproject/community/) using `image.tag`. Override container registry and repository using `image.registry` and `image.repository`, respectively.



**HTTPS mode**

Regardless of the TLS mode of ingress, OpenProject needs to be told whether it's expected to run and return HTTPS responses (or generate correct links in mails, background jobs, etc.). If you're not running https, then set `openproject.https=false`.



**Seed locale** (13.0+)

By default, demo data and global names for types, statuses, etc. will be in English. If you wish to set a custom locale, set `openproject.seed_locale=XX`, where XX can be a two-character ISO code. For currently supported values, see the `OPENPROJECT_AVAILABLE__LANGUAGES` default value in the [environment guide](https://www.openproject.org/docs/installation-and-operations/configuration/environment/).



**Admin user** (13.0+)

By default, OpenProject generates an admin user with password `admin` which is required to change after first interactive login.
If you're operating an automated deployment with fresh databases for testing, this default approach might not be desirable.

You can customize the password as well as name, email, and whether a password change is enforced on first login with these variables:

```ruby
openproject.admin_user.password="my-secure-password"
openproject.admin_user.password_reset="false"
openproject.admin_user.name="Firstname Lastname"
openproject.admin_user.mail="admin@example.com"
```



### ReadWriteMany volumes

By default and when using filesystem-based attachments, OpenProject requires the Kubernetes cluster to support `ReadWriteMany` (rwx) volumes. This is due to the fact that multiple container instances need access to write to the attachment storage.

To avoid using ReadWriteMany, you will need to configure an S3 compatible object storage instead which is shown in the [advanced configuration guide](https://www.openproject.org/docs/installation-and-operations/configuration/#attachments-storage).

```
persistence:
  enabled: false

s3:
  enabled: true
  accessKeyId:
  # etc.
```





### Updating the configuration

The OpenProject configuration can be changed through environment variables.
You can use `helm upgrade` to set individual values.

For instance:

```shell
helm upgrade --reuse-values --namespace openproject my-openproject --set environment.OPENPROJECT_IMPRESSUM__LINK=https://www.openproject.org/legal/imprint/ --set environment.OPENPROJECT_APP__TITLE='My OpenProject'
```

Find out more about the [configuration through environment variables](https://www.openproject.org/docs/installation-and-operations/configuration/environment/) section.



## Uninstalling the Chart

To uninstall the release with the name my-openproject do the following:

```shell
helm uninstall --namespace openproject my-openproject
```



> **Note**: This will not remove the persistent volumes created while installing.
> The easiest way to ensure all PVCs are deleted as well is to delete the openproject namespace
> (`kubectl delete namespace openproject`). If you installed OpenProject into the default
> namespace, you can delete the volumes manually one by one.



## Troubleshooting

### Web deployment stuck in `CrashLoopBackoff`

Describing the pod may yield an error like the following:

```
65s)  kubelet            Error: failed to start container "openproject": Error response from daemon: failed to create shim task: OCI runtime create failed: runc create failed: unable to start container process: error during container init: error setting cgroup config for procHooks process: failed to write "400000": write /sys/fs/cgroup/cpu,cpuacct/kubepods/burstable/pod990fa25e-dbf0-4fb7-9b31-9d7106473813/openproject/cpu.cfs_quota_us: invalid argument: unknown
```

This can happen when using **minikube**. By default, it initialises the cluster with 2 CPUs only.

Either increase the cluster's resources to have at least 4 CPUs or install the OpenProject helm chart with a reduced CPU limit by adding the following option to the install command:

```shell
--set resources.limits.cpu=2
```

## Development

To install or update from this directory run the following command.

```bash
bin/install-dev
```

This will install the chart with `--set develop=true` which is recommended
on local clusters such as **minikube** or **kind**.

This will also set `OPENPROJECT_HTTPS` to false so no TLS certificate is required
to access it.

You can set other options just like when installing via `--set`
(e.g. `bin/install-dev --set persistence.enabled=false`).

### Debugging

Changes to the chart can be debugged using the following.

```bash
bin/debug
```

This will try to render the templates and show any errors.
You can set values just like when installing via `--set`
(e.g. `bin/debug --set persistence.enabled=false`).

## TLS

Create a TLS certificate, e.g. using [mkcert](https://github.com/FiloSottile/mkcert).

```
mkcert helm-example.openproject-dev.com
```

Create the tls secret in kubernetes.

```
kubectl -n openproject create secret tls openproject-tls \
  --key="helm-example.openproject-dev.com-key.pem" \
  --cert="helm-example.openproject-dev.com.pem"
```

Set the tls secret value during installation or an upgrade by adding the following.

```
--set ingress.tls.enabled=true --set tls.secretName=openproject-tls
```

### Root CA

If you want to add your own root CA for outgoing TLS connection, do the following.

1. Put the certificate into a config map.

```
kubectl -n openproject-dev create configmap ca-pemstore --from-file=/path/to/rootCA.pem
```

To make OpenProject use this CA for outgoing TLS connection, set the following options.

```
  --set egress.tls.rootCA.configMap=ca-pemstore \
  --set egress.tls.rootCA.fileName=rootCA.pem
```

## OpenShift

For OpenProject to work in OpenShift without further adjustments,
you need to use the following pod security context.

```
podSecurityContext:
  supplementalGroups: [1000]
  fsGroup: null
```

By default OpenProject requests `fsGroup: 1000` in the pod security context.
This is not allowed by default. You have to allow it using
a custom SCC (Security Context Constraint) in the cluster.

The use of `supplementalGroups` is not necessary if you request the correct UID in the security context.

```
securityContext:
  runAsUser: 1000
  runAsGroup: 1000
```

But this will not be allowed by default either. So the easiest way is the use of the `podSecurityContext` shown above.

Due to the default restrictions in OpenShift there may also be issues running
PostgreSQL and memcached. Again, you may have to create an SCC to fix this
or adjust the policies in the subcharts accordingly.

Assuming no further options for both, simply disabling the security context values to use the default works as well.

```
postgresql:
  primary:
    containerSecurityContext:
      enabled: false
    podSecurityContext:
      enabled: false

memcached:
  containerSecurityContext:
    enabled: false
  podSecurityContext:
    enabled: false
```
