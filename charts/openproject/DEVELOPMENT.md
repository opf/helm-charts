# Development

## Quick start

To install or update from this directory (`charts/openproject`), start your
Kubernetes cluster and run the following command:

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

In this document we give some advice on how to develop the [helm chart](./) locally.

For that you need to install a local kubernetes cluster and install the [chart](./Chart.yaml) on it.

## Prerequisites

No matter which kubernetes cluster you use, you will need the following tools:

* docker
* kubectl
* helm

## Development kubernetes clusters

As for kubernetes, there are multiple choices such as:

* [minikube](https://minikube.sigs.k8s.io/)
* [k3d](https://k3d.io/) (recommended)
* [kind](https://kind.sigs.k8s.io/)
* etc.

### k3d

Follow the instructions on [k3d.io](https://k3d.io/stable/#installation) to install `k3d`.
Once done, create the cluster as follows:

```bash
k3d cluster create -p "80:80@loadbalancer" default
```

This will create the cluster `k3d-default` and also add it to your `~/.kube/config`.
`k3d` automatically creates a loadbalancer container (separate from Kubernetes nodes) that handles ingress traffic.
The `-p` option maps port 80 on your local machine (first number) to port 80 on the loadbalancer container (second number).

Any ingress created on the cluster will be reachable this way directly,
as long as you point the chosen host name to localhost.

> *.openproject-dev.com points to localhost already, so you could simply use any subdomain of that for development.
> For instance: helm.openproject-dev.com

Note that *.openproject-dev.com works only if you're online.


You can change the port (the first `80:`) to something else if `localhost:80` is already used.

## Installing the chart

Under [bin/install-dev] is a script you can use and build on to test the OpenProject chart locally.

Use it as follows:

```bash
bin/install-dev
```

This will install the chart with `--set develop=true` which is recommended
on local clusters.

This will also set `OPENPROJECT_HTTPS` to false so no TLS certificate is required
to access it. It will also disable TLS in other places where needed.

Assuming your kubernetes cluster is set up and exposed on port 80, you can now access OpenProject under
[http://helm.openproject-dev.com](http://helm.openproject-dev.com).

Default login/password is admin/admin.

You can create your own file adding to and overriding values and pass that with
an additional `-f` option in the command above. For instance `bin/install-dev -f my-values.yaml`.

### TLS

If you want to use TLS you can use [`bin/install-local-with-tls`](./bin/install-local-with-tls).
This will generate a self-signed certificate the root CA of which you will have to import into your browser.

## Backups

The chart's [backups](./README.md#backups) can be tried out and tested on the same local k3d cluster.
For `bin/backup list`, `mount` and `restore` you also need a local [kopia](https://kopia.io/docs/installation/)
(plus FUSE for `mount`); everything else only needs `kubectl` and `helm`.

### Trying out backups locally

[`bin/install-local-with-backups`](./bin/install-local-with-backups) installs OpenProject like `bin/install-dev`,
with backups and backup replication enabled ([`examples/local-with-backups-values.yaml`](./examples/local-with-backups-values.yaml)).
The backups go to two separate S3 services (single-node RustFS), each in its own namespace with its own credentials:

| Namespace           | Service              | Bucket                       | Access key / secret key               |
|---------------------|----------------------|------------------------------|---------------------------------------|
| `openproject`       | OpenProject          |                              |                                       |
| `backup-s3`         | `rustfs` (9000/9001) | `openproject-backup`         | `backup-access` / `backup-secret-key` |
| `backup-replica-s3` | `rustfs` (9000/9001) | `openproject-backup-replica` | `replica-access` / `replica-secret-key` |

```bash
bin/install-local-with-backups
```

The backup runs every 5 minutes in this setup; use `bin/backup` to run it right away. The replication keeps its
default schedule (daily). Additional options are passed on to helm, e.g. `--set backup.replica.schedule='*/30 * * * *'`.

#### Running the jobs

```bash
bin/backup -n openproject create-snapshot   # backup
bin/backup -n openproject sync-replica      # replication to the replica bucket
bin/backup -n openproject verify            # verification of all snapshots
```

Each of these creates a job from the respective CronJob, waits for it and prints its logs.

#### Browsing snapshots

Without a local kopia, use the kopia web UI. It runs in a temporary pod in the cluster, so it doesn't need access
to the S3 services from your machine:

```bash
bin/backup -n openproject ui              # primary repository
bin/backup -n openproject --replica ui    # replica
```

With a local kopia, you can list, mount and restore snapshots directly. The S3 services are only reachable inside
the cluster, so `bin/backup` forwards them to a local port for the duration of each command:

```bash
bin/backup -n openproject list
bin/backup -n openproject mount                    # all snapshots, by date
bin/backup -n openproject restore latest ./restore
bin/backup -n openproject --replica list
```

To look at what actually ends up in the buckets (encrypted kopia blobs), open the RustFS console:
`kubectl -n backup-s3 port-forward svc/rustfs 9001:9001`, then <http://localhost:9001/rustfs/console/>, logging
in with the credentials from the table above.

#### Restoring the database

A restored snapshot contains `openproject.sql`, `attachment/` and `custom_style/`. To check that the database dump
is complete, you can load it into a scratch database next to the real one:

```bash
cd restore
PGPASSWORD=$(kubectl -n openproject get secret openproject-postgresql -o jsonpath='{.data.postgres-password}' | base64 -d)
DB_DUMP_IMAGE=$(kubectl -n openproject get cronjob openproject-backup \
  -o jsonpath='{.spec.jobTemplate.spec.template.spec.initContainers[?(@.name=="db-dump")].image}')
psql() {
  kubectl -n openproject run "psql-$RANDOM" --rm -i --quiet --restart=Never --image="$DB_DUMP_IMAGE" \
    --env=PGPASSWORD="$PGPASSWORD" --command -- psql -h openproject-postgresql -U postgres "$@"
}

psql -c 'CREATE DATABASE restore_test'
psql -d restore_test -q < openproject.sql > /dev/null
psql -d restore_test -c 'SELECT count(*) FROM work_packages'
psql -c 'DROP DATABASE restore_test'
```

This uses `psql` from the same image the backup's `pg_dump` runs in (`backup.dbDump.image`, which follows the
bundled PostgreSQL's major version), as `psql` from older patch releases (like the one in the bundled PostgreSQL
15.4 image) fails on the `\restrict` lines that current `pg_dump` versions write.

### Integration tests

The integration specs in [`spec/charts/openproject/integration`](../../spec/charts/openproject/integration) test
the backups end to end. For each scenario they install OpenProject with backups and replication into a fresh
namespace, together with two S3 services, write marker data, run two backups, the replication and the
verification, and restore the latest snapshot from both repositories:

| Scenario (`ATTACHMENTS=`) | Attachments                                                   | Namespace enforces |
|---------------------------|---------------------------------------------------------------|--------------------|
| `local`                   | on the assets volume                                          | `restricted`       |
| `s3`                      | in S3, mounted by the backup via FUSE (privileged)            | —                  |
| `s3-csi`                  | in S3, provided as a volume by the k8s-csi-s3 driver          | `restricted`       |

The `s3` scenario also checks that installing FUSE-based backups into a `restricted` namespace fails.

They use the current kube context and install the k8s-csi-s3 driver into `kube-system`, so use a separate,
disposable cluster. No load balancer is needed:

```bash
k3d cluster create backup-test --no-lb
helm dependency build                      # in charts/openproject, if not done yet
cd ../.. && bundle install

bin/rspec --tag integration                # all scenarios, takes about 15 minutes
ATTACHMENTS=s3-csi bin/rspec --tag integration spec/charts/openproject/integration/backup_spec.rb
```

The namespaces are named `backup-test-<scenario>` and deleted afterwards. With `KEEP_NAMESPACE=1` they are kept
for debugging, and you can also use `bin/backup` on them (the release is called `openproject`):

```bash
KEEP_NAMESPACE=1 ATTACHMENTS=local bin/rspec --tag integration

cd charts/openproject
bin/backup -n backup-test-local ui
bin/backup -n backup-test-local list
```

Delete kept namespaces with `kubectl delete namespace backup-test-<scenario>` (for `s3-csi` also
`kubectl delete pv backup-test-s3-csi-attachments`), or the whole cluster with `k3d cluster delete backup-test`.
