# Bundled PostgreSQL and migration from Bitnami

The chart bundles one PostgreSQL 18 instance using `pgvector/pgvector:pg18-bookworm`.
It creates a non-superuser application role and enables `vector` in new databases.
It does not upgrade existing data files or enable extensions in existing databases.
For replication, failover, or managed backups, use an external database.

**Existing Bitnami installations need a dump and restore before upgrading this chart.**
The previous chart defaults to PostgreSQL 15.4. The procedure also applies to PostgreSQL 17.
Changing the image tag or mounting the Bitnami PVC in the new container is not a migration.

## Choices before upgrading

- **Defer migration:** keep your current chart version, values, and exact Bitnami image tag or digest.
  Pin the chart version in Helm or GitOps. Setting the new chart's image to PostgreSQL 17 does not preserve Bitnami compatibility.
- **Use the new bundled database:** follow the maintenance-window procedure below.
- **Use an external database:** restore there, then set `postgresql.bundled: false`, connection details, and credentials.
  The external connection settings have not changed.

For a fresh PostgreSQL 17 database, or a logical restore into a new PostgreSQL 17 PVC, set both:

```yaml
postgresql:
  image:
    tag: pg17-bookworm
  dataDirectory: /var/lib/postgresql/17/docker
```

Never change these values to downgrade PostgreSQL 18 data files.
Both versions mount the PVC at `/var/lib/postgresql` in this chart.
Bitnami used `/bitnami/postgresql` and different ownership; its PVC stays separate.

## Prepare and rehearse

Rehearse on a copy first. Measure dump, restore, and verification time to size the maintenance window.
Keep the OpenProject application image at its current version during the database migration.
Upgrade OpenProject separately after verifying the database cutover.

The commands below use Bash, Helm, and kubectl. Run them from a private backup directory.
Replace the example namespace, release, chart path, database, and role with your installation's values.
`NEW_CHART` is the unpacked new chart, including its dependencies.

```bash
set -euo pipefail
umask 077
NS=openproject
RELEASE=openproject
NEW_CHART=./charts/openproject
OLD_STS=openproject-postgresql
OLD_POD="$OLD_STS-0"
DB=openproject
DB_USER=openproject
OLD_SECRET=openproject-postgresql

old_db() {
  kubectl -n "$NS" exec "$OLD_POD" -- sh -c \
    'export PGPASSWORD="$POSTGRES_POSTGRES_PASSWORD"; exec "$@"' sh "$@"
}

helm history "$RELEASE" -n "$NS" > helm-history.txt
helm get values "$RELEASE" -n "$NS" -o yaml > old-values.yaml
helm get manifest "$RELEASE" -n "$NS" > old-manifest.yaml
kubectl -n "$NS" get secret "$OLD_SECRET" -o json |
  python3 -c 'import json,sys; s=json.load(sys.stdin); s["metadata"]={"name":s["metadata"]["name"]}; print(json.dumps(s))' > old-db-secret.yaml
kubectl -n "$NS" get deployment -l "app.kubernetes.io/instance=$RELEASE" -o yaml > old-deployments.yaml
kubectl -n "$NS" get pvc -o wide > old-pvcs.txt
old_db psql -U postgres -d "$DB" -Atc 'SHOW server_version'
```

Record the old chart revision, exact application/database images, replica counts, and PVC names.
Save the original chart package for rollback. Use the version from `helm-history.txt`:

```bash
OLD_CHART_VERSION=13.17.2 # Replace with your installed chart version.
helm pull --repo https://charts.openproject.org openproject --version "$OLD_CHART_VERSION"
OLD_CHART="./openproject-$OLD_CHART_VERSION.tgz"
```

For a customized chart, save that exact chart with its dependencies instead.
Back up attachments and application secrets too. Keep backups outside the cluster.
Check available space for both databases, the dump, indexes, and restore overhead.
Keep the old PVC and ensure its storage cannot be deleted by automated cleanup.

Review installed extensions and object owners before proceeding:

```bash
old_db psql -U postgres -d "$DB" -c '\dx'
old_db psql -U postgres -d "$DB" -c '\du'
```

The helper reads Bitnami’s administrator password inside the container without printing it.
If you use password files or a different administrator role, adapt the helper before proceeding.
Install any additional required extensions in the destination image before restoring.
Recreate additional owner/grantee roles before restoration; do not blindly restore cluster-wide roles.
The standard installation needs only `postgres` and the application role.

Create `new-values.yaml` by reviewing `old-values.yaml` against the mapping below.
Preserve application configuration, attachments, credentials, and the current application image.
Do not use `--reuse-values`; obsolete Bitnami settings must be removed.
Set `postgresql.auth.username` and `postgresql.auth.database` to their original names.

Copy the original database credentials into a separate Secret for the new database.
This prevents removal of the old chart's Secret from affecting the new database.
Adapt the key names if your installation uses custom keys.

```bash
kubectl -n "$NS" get secret "$OLD_SECRET" -o json |
  python3 -c 'import json,sys; s=json.load(sys.stdin); s["metadata"]={"name":"pg18-credentials"}; print(json.dumps(s))' |
  kubectl -n "$NS" apply -f -
```

Set these values in `new-values.yaml`:

```yaml
postgresql:
  auth:
    existingSecret: pg18-credentials
    username: openproject
    database: openproject
  persistence:
    size: 8Gi # Choose enough space for your restored database.
```

## Stop writers and take the final dump

Enable maintenance at your ingress or load balancer. Pause GitOps reconciliation, autoscaling, and scheduled automation.
Stop every application writer, including external workers and integrations with direct database access.
Wait for the current seeder Job to finish; do not run a Helm upgrade during the dump.

```bash
kubectl -n "$NS" scale deployment -l "app.kubernetes.io/instance=$RELEASE" --replicas=0
kubectl -n "$NS" get pods,jobs -l "app.kubernetes.io/instance=$RELEASE"
```

Verify that application pods have terminated and no application sessions remain:

```bash
old_db psql -U postgres -d "$DB" -c \
  "SELECT usename, application_name, state FROM pg_stat_activity WHERE datname = current_database() AND pid <> pg_backend_pid();"
old_db pg_dump -U postgres -d "$DB" --format=custom > openproject.dump
test -s openproject.dump
```

Investigate remaining writers before accepting the dump. Keep ownership and grants in the archive.
Restore as administrator so application objects retain their original owner without granting the application superuser access.

## Restore into separate storage

Use the new chart's database templates to create a temporary database only.
This uses the same image, permissions, initialization, and storage layout as the final deployment.
It does not start OpenProject or run application migrations.

```bash
helm template pg18-restore "$NEW_CHART" -n "$NS" -f new-values.yaml \
  --set fullnameOverride=pg18-restore \
  --set serviceAccount.create=false --set serviceAccount.name=default \
  --set postgresql.persistence.existingClaim= \
  --show-only templates/postgresql-init.yaml \
  --show-only templates/postgresql-service.yaml \
  --show-only templates/postgresql-statefulset.yaml > restore-database.yaml
kubectl -n "$NS" apply -f restore-database.yaml
kubectl -n "$NS" rollout status statefulset/pg18-restore-database --timeout=10m

kubectl -n "$NS" exec -i pg18-restore-database-0 -- \
  pg_restore -U postgres -d "$DB" --exit-on-error < openproject.dump
kubectl -n "$NS" exec pg18-restore-database-0 -- \
  vacuumdb -U postgres -d "$DB" --analyze-in-stages
```

The destination already contains `vector`. PostgreSQL's dump restores existing extensions with `IF NOT EXISTS`.
If restoration fails, resolve the cause and recreate **only the new staging PVC** before retrying the full restore.
Do not run `--clean` against the original database.

Verify the database version, extension, role permissions, and representative application data:

```bash
kubectl -n "$NS" exec pg18-restore-database-0 -- psql -U postgres -d "$DB" -v ON_ERROR_STOP=1 -c \
  "SELECT version(); SELECT extversion FROM pg_extension WHERE extname='vector'; SELECT '[1,2,3]'::vector <-> '[4,5,6]'::vector;"
kubectl -n "$NS" exec pg18-restore-database-0 -- psql -U postgres -d "$DB" -c \
  "SELECT rolname, rolsuper FROM pg_roles WHERE rolname = '$DB_USER'; SELECT count(*) FROM projects; SELECT count(*) FROM work_packages;"
```

Compare counts and important records with the source. The application role must have `rolsuper = false`.
Test existing vector columns and indexes if your database already uses them.

## Cut over and verify

Record the new PVC and stop the staging database before the final StatefulSet mounts it:

```bash
NEW_PVC=data-pg18-restore-database-0
kubectl -n "$NS" get pvc "$NEW_PVC"
kubectl -n "$NS" delete -f restore-database.yaml --wait=true
kubectl -n "$NS" wait --for=delete pod/pg18-restore-database-0 --timeout=5m
```

Deleting the staging StatefulSet retains its PVC. Wait for its pod to terminate and storage to detach.
Set `postgresql.persistence.existingClaim: data-pg18-restore-database-0` in `new-values.yaml`.
Confirm this is **not** the old Bitnami PVC.

Create `maintenance-values.yaml` to keep background writers stopped during verification:

```yaml
autoscaling:
  enabled: false
backgroundReplicaCount: 0
cron:
  enabled: false
workers:
  default:
    replicaCount: 0
```

Set `replicaCount: 0` for **every** configured worker under `workers`, including custom worker names.
Keep external workers and integrations paused. Public ingress must still show maintenance.
The web pods and seeder will start for verification; only validation-related writes should occur.

```bash
helm upgrade "$RELEASE" "$NEW_CHART" -n "$NS" \
  -f new-values.yaml -f maintenance-values.yaml --wait --wait-for-jobs --timeout=20m
kubectl -n "$NS" get pods,pvc
```

Do not enable automatic Helm rollback for this cutover; inspect any failure before restarting the old application.
The chart rejects a direct Helm upgrade from the old StatefulSet unless an existing destination PVC is selected.
Offline renderers, including GitOps, cannot perform this cluster lookup. Follow this procedure before synchronizing them.

Keep public access in maintenance mode. Confirm worker and cron replicas remain zero.
Verify login, projects, work packages, and attachments without making business changes.
Verify PostgreSQL 18, the vector-distance query, and application-role permissions again in the final database pod.
Recreate that pod and confirm the same application records remain.
Accept the cutover before restarting background writers:

```bash
helm upgrade "$RELEASE" "$NEW_CHART" -n "$NS" \
  -f new-values.yaml --wait --wait-for-jobs --timeout=20m
```

This command restarts workers and cron. After they resume, rolling back can lose new business changes.
Verify background jobs, then restore traffic and GitOps reconciliation with the reviewed new values.

## Rollback

Before accepting cutover, rollback returns to the untouched old database and the previous chart/application version.
Any validation writes in the new database are discarded.
Stop all new application writers first. Preserve the new PVC and collect failure logs.
Deploy the saved old chart and values, using the copied original credentials.
Use `helm upgrade` with the old package: this also avoids Helm rollback failures involving retained, generated Secrets.

```bash
kubectl -n "$NS" scale deployment -l "app.kubernetes.io/instance=$RELEASE" --replicas=0
for job in $(kubectl -n "$NS" get job -l "app.kubernetes.io/instance=$RELEASE,app.kubernetes.io/component=seeder" -o name); do
  kubectl -n "$NS" patch "$job" --type=merge -p '{"spec":{"suspend":true}}'
done
kubectl -n "$NS" wait --for=delete pod \
  -l "app.kubernetes.io/instance=$RELEASE,app.kubernetes.io/name=openproject,openproject/process!=database" \
  --field-selector='status.phase!=Succeeded,status.phase!=Failed' --timeout=5m
helm upgrade "$RELEASE" "$OLD_CHART" -n "$NS" -f old-values.yaml \
  --set postgresql.auth.existingSecret=pg18-credentials --wait --wait-for-jobs --timeout=20m
```

Confirm the old StatefulSet mounts the original Bitnami PVC and uses its original database image.
Restore the recorded replica counts and test the application before reopening access.
Do not delete either database while investigating.

After users or background jobs write to PostgreSQL 18, the original database is stale.
Rolling back to it loses those changes. Stop writers and plan recovery explicitly; PostgreSQL 18 dumps are not a supported downgrade method.
Keep the old PVC and backups through your agreed retention period, then remove them deliberately.

## Values that change

| Previous Bitnami setting | New setting or action |
| --- | --- |
| `postgresql.auth.*` | Retained, including existing Secret and custom password keys. |
| `postgresql.primary.persistence.size`, `storageClass`, `accessModes`, `existingClaim` | `postgresql.persistence.size`, `storageClassName`, `accessModes`, `existingClaim`; select a new/restored PVC. |
| `postgresql.primary.resources`, `resourcesPreset` | `postgresql.resources`, `resourcesPreset`. |
| `postgresql.primary.nodeSelector`, `affinity`, `tolerations` | Corresponding fields directly under `postgresql`. |
| `postgresql.primary.podSecurityContext`, `containerSecurityContext` | Corresponding fields directly under `postgresql`; upstream Bookworm image uses UID/GID 999. |
| `postgresql.primary.service.ports.postgresql` | `postgresql.service.port`. |
| `postgresql.image.digest` | `postgresql.image.sha256`, without the `sha256:` prefix. |
| `postgresql.global.*` | Remove; use top-level `global.imageRegistry` where needed. |
| `postgresql.architecture`, `readReplicas`, replication credentials | Removed. Use an externally managed HA database. |
| `postgresql.volumePermissions`, `metrics`, `primary.initdb`, Bitnami-specific configuration | Removed. Review custom initialization, monitoring, and tuning separately. |

The new PVC uses `fsGroup: 999` and needs a storage driver that supports Kubernetes volume ownership.
There is no root permissions init container. For pre-provisioned storage, arrange compatible permissions before mounting it.
Image, probes, resources, scheduling, extra environment variables, and extra mounts are configurable in `values.yaml`.

Generated credentials are retained across upgrades and uninstall. For GitOps, supply an existing Secret.
Inline passwords only initialize that Secret once. Changing values or a Secret does not change passwords inside an existing database.
Coordinate password changes in PostgreSQL, the Secret, and application restarts.

For an existing compatible database without pgvector, install its matching extension package/image first.
Then connect as a database administrator and run `CREATE EXTENSION IF NOT EXISTS vector;` in the application database.
Application updates do not require this extension.
