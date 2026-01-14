---
"@openproject/helm-charts": minor
---

Fix: Deployment selectors now exclude `commonLabels` to prevent immutable selector errors when upgrading from 11.5.0 to 11.6.0 or 11.7.0. This makes deployment selectors consistent with service selectors.

This change effectively reverts parts https://github.com/opf/helm-charts/commit/236dd59117072f1f7f11864878ce061a86c471af

### Upgrading from version 11.6.0/11.7.0

If you're upgrading from chart version **11.6.x** or **11.7.x** to this release, you may encounter errors about immutable Deployment selectors **if you have `commonLabels` configured**. This is because 11.6.0/11.7.0 included `commonLabels` in Deployment selectors, and this release removes them again. Kubernetes does not allow changing Deployment selectors after creation. This does NOT apply if you're still on 11.5.x.

**Why this happens**: Your existing Deployments created by 11.6.x/11.7.x may have selectors like:

- `app.kubernetes.io/name`, `app.kubernetes.io/instance` (from the Bitnami common chart)
- `openproject/process`, `app.kubernetes.io/component`
- plus any non-empty `commonLabels` you configured

When upgrading to this release, the `commonLabels` part is intentionally removed from the selector to make selectors stable and consistent with Services. That means Kubernetes would need to change `spec.selector`, which it refuses because it’s immutable.

If you see errors like:
```
cannot patch "openproject-web" with kind Deployment: Deployment.apps "openproject-web" is invalid: spec.selector: Invalid value: ... field is immutable
```

You need to delete the existing Deployments and let Helm recreate them with the new selector format. **This will cause a brief downtime** as the pods are recreated.

> **Note**: This is a one-time migration for installations that ran 11.6.x/11.7.x with non-empty `commonLabels`. After recreating the Deployments once, future upgrades (and future `commonLabels` changes) won't hit immutable selector errors.

**Option 1: Set labels manually**

You can still use the `common.labels.matchLabels` value to set any values that you have had set previously, or those that were introduced in 11.6.0, these are at least:

**web deployment**
`- app.kubernetes.io/component=web`

**worker-default deployment**
`- app.kubernetes.io/component=worker-default`

**hocuspocus deployment**
`- app.kubernetes.io/component=hocuspocus`

**cron deployment**
`- app.kubernetes.io/component=cron`

and then the matchLabels should remain as they were. If this doesn't work, you can try the following options.

**Option 2: Use Helm's `--force` flag**

Helm's `--force` flag can sometimes handle immutable fields by deleting and recreating resources automatically:

```bash
helm upgrade --force --namespace $NAMESPACE $RELEASE_NAME openproject/openproject
```

> **Note**: The `--force` flag may not always work for immutable selectors. If it fails, use one of the manual options below.

**Option 3: Delete deployments manually (CAUTION: This deleted your deployment and causes downtime)**

If `--force` doesn't work, manually delete the deployments before upgrading:

```bash
# Set your namespace and release name
NAMESPACE=openproject
RELEASE_NAME=openproject

# Delete all OpenProject deployments
kubectl delete deployment -n $NAMESPACE \
  ${RELEASE_NAME}-web \
  ${RELEASE_NAME}-cron \
  ${RELEASE_NAME}-hocuspocus \
  ${RELEASE_NAME}-worker-default \
  ${RELEASE_NAME}-worker-bim \
  ${RELEASE_NAME}-worker-multitenancy

# Then run your helm upgrade
helm upgrade --namespace $NAMESPACE $RELEASE_NAME openproject/openproject
```

**Option 4: Use kubectl to delete all deployments matching the release**

```bash
# Set your namespace and release name
NAMESPACE=openproject
RELEASE_NAME=openproject

# Delete all deployments for this release
kubectl delete deployment -n $NAMESPACE -l app.kubernetes.io/instance=$RELEASE_NAME

# Then run your helm upgrade
helm upgrade --namespace $NAMESPACE $RELEASE_NAME openproject/openproject
```

**Option 5: Minimize downtime with scaling (for zero-downtime upgrades)**

If you have multiple replicas, you can minimize downtime by scaling down workers first:

```bash
# Set your namespace and release name
NAMESPACE=openproject
RELEASE_NAME=openproject

# Scale down workers (they can tolerate brief downtime)
kubectl scale deployment -n $NAMESPACE \
  ${RELEASE_NAME}-worker-default \
  ${RELEASE_NAME}-worker-bim \
  ${RELEASE_NAME}-worker-multitenancy \
  --replicas=0

# Delete all deployments
kubectl delete deployment -n $NAMESPACE -l app.kubernetes.io/instance=$RELEASE_NAME

# Run helm upgrade (this will recreate everything)
helm upgrade --namespace $NAMESPACE $RELEASE_NAME openproject/openproject

# The web deployment will be recreated first, then workers will scale back up
```

> **Note**: The deployments will be automatically recreated by Helm during the upgrade. Make sure you have proper backup and recovery procedures in place before performing this operation.
