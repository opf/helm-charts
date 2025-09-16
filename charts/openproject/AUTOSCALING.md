# OpenProject KEDA Autoscaling

This guide explains how to set up autoscaling for OpenProject using KEDA (Kubernetes Event Driven Autoscaler).

## Overview

KEDA provides event-driven autoscaling for Kubernetes workloads, allowing OpenProject to scale based on:
- **CPU/Memory metrics** (built-in, no external dependencies)
- **Prometheus metrics** (requests in flight, queue depth, custom metrics)
- **External systems** (Redis queues, RabbitMQ, databases)
- **Scheduled scaling** (cron-based scaling for predictable load patterns)

## Prerequisites

### 1. Install KEDA

```bash
# Add KEDA Helm repository
helm repo add kedacore https://kedacore.github.io/charts
helm repo update

# Install KEDA in its own namespace
helm install keda kedacore/keda \
  --namespace keda \
  --create-namespace \
  --version 2.17.2
```

Verify KEDA installation:
```bash
kubectl get pods -n keda
kubectl get crd | grep keda
```

### 2. Install Prometheus (For Custom Metrics)

**Option A: Minimal Prometheus (Recommended for testing)**
```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts

# Install lightweight Prometheus
helm install prometheus prometheus-community/prometheus \
  --namespace monitoring \
  --create-namespace \
  --set alertmanager.enabled=false \
  --set prometheus-node-exporter.enabled=false \
  --set prometheus-pushgateway.enabled=false \
  --set kube-state-metrics.enabled=false \
  --set server.persistentVolume.enabled=false
```

**Option B: Full Prometheus Stack (Production)**
```bash
# Install complete monitoring stack
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace
```

**Option C: Use Existing Prometheus**
If you already have Prometheus, just note its service URL for configuration.

### 3. Configure Prometheus to Scrape OpenProject

Ensure your Prometheus configuration includes OpenProject pod scraping:
```yaml
# For pod annotations-based discovery (automatic with default configs)
scrape_configs:
- job_name: 'kubernetes-pods'
  kubernetes_sd_configs:
  - role: pod
  relabel_configs:
  - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
    action: keep
    regex: true
```

## Configuration

### Basic CPU/Memory Scaling

Enable basic autoscaling using CPU and memory metrics:

```yaml
# values.yaml
keda:
  enabled: true
  minReplicaCount: 1
  maxReplicaCount: 10
  triggers:
    - type: cpu
      metadata:
        type: Utilization
        value: "70"
    - type: memory  
      metadata:
        type: Utilization
        value: "80"

# Enable metrics collection
metrics:
  enabled: true
```

### Advanced Prometheus-based Scaling

Scale based on OpenProject-specific metrics:

```yaml
# values.yaml
keda:
  enabled: true
  pollingInterval: 30
  cooldownPeriod: 300
  minReplicaCount: 2
  maxReplicaCount: 20
  
  triggers:
    # Scale based on requests in flight
    - type: prometheus
      metadata:
        serverAddress: http://prometheus-server.monitoring.svc.cluster.local:80
        metricName: openproject_requests_in_flight
        query: |
          avg(
            sum by (pod) (
              openproject_requests_in_flight{pod=~".*openproject.*web.*"}
            )
          )
        threshold: "30"  # Target 30 avg requests per pod
    
    # Scale based on background job queue depth
    - type: prometheus
      metadata:
        serverAddress: http://prometheus-server.monitoring.svc.cluster.local:80
        metricName: openproject_queue_depth
        query: sum(openproject_background_jobs_queue_size)
        threshold: "50"  # Scale up when queue > 50 jobs
        
    # Fallback to CPU if custom metrics fail
    - type: cpu
      metadata:
        type: Utilization
        value: "70"

metrics:
  enabled: true
  path: "/api/metrics"
  port: 8080
  serviceMonitor:
    enabled: true  # For Prometheus Operator
```

### Scheduled Scaling

Scale up during business hours to handle expected load:

```yaml
keda:
  enabled: true
  triggers:
    # Business hours scaling (UTC)
    - type: cron
      metadata:
        timezone: UTC
        start: "0 8 * * 1-5"     # 8 AM weekdays
        end: "0 18 * * 1-5"      # 6 PM weekdays  
        desiredReplicas: "5"
    
    # Weekend minimal scaling
    - type: cron
      metadata:
        timezone: UTC
        start: "0 9 * * 6-0"     # 9 AM weekends
        end: "0 17 * * 6-0"      # 5 PM weekends
        desiredReplicas: "2"
        
    # Night time minimal scaling
    - type: cron
      metadata:
        timezone: UTC
        start: "0 22 * * *"      # 10 PM daily
        end: "0 6 * * *"         # 6 AM daily
        desiredReplicas: "1"
```

## Deployment

### 1. Update your values.yaml

Choose your configuration approach and update values:

```bash
# Copy example configuration
cp values.yaml my-values.yaml

# Edit configuration
vim my-values.yaml
```

### 2. Deploy OpenProject with KEDA

```bash
# Deploy with KEDA autoscaling enabled
helm upgrade --install openproject . \
  --namespace openproject \
  --create-namespace \
  --values my-values.yaml
```

### 3. Verify KEDA Configuration

```bash
# Check ScaledObject status
kubectl get scaledobject -n openproject
kubectl describe scaledobject openproject-web-scaler -n openproject

# Check HPA created by KEDA
kubectl get hpa -n openproject
kubectl describe hpa keda-hpa-openproject-web-scaler -n openproject

# Monitor scaling events
kubectl get events -n openproject --sort-by=.firstTimestamp
```

## Monitoring and Troubleshooting

### Check KEDA Metrics

```bash
# View KEDA operator logs
kubectl logs -n keda deployment/keda-operator

# Check metrics server logs  
kubectl logs -n keda deployment/keda-metrics-apiserver

# View ScaledObject status
kubectl get scaledobject openproject-web-scaler -n openproject -o yaml
```

### Common Prometheus Queries

Test your queries directly in Prometheus UI:

```promql
# Average requests in flight per pod
avg(
  sum by (pod) (
    openproject_requests_in_flight{pod=~".*openproject.*web.*"}
  )
)

# Total background job queue size
sum(openproject_background_jobs_queue_size)

# Request rate per second
sum(rate(openproject_http_requests_total[1m]))

# 95th percentile response time
histogram_quantile(0.95, 
  rate(openproject_http_request_duration_seconds_bucket[5m])
)
```

### Debugging Steps

1. **ScaledObject not working:**
   ```bash
   kubectl describe scaledobject -n openproject
   kubectl logs -n keda deployment/keda-operator
   ```

2. **Prometheus connection issues:**
   ```bash
   # Test Prometheus connectivity from KEDA namespace
   kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- \
     curl http://prometheus-server.monitoring.svc.cluster.local:80/api/v1/query?query=up
   ```

3. **Metrics not available:**
   ```bash
   # Check if OpenProject exposes metrics
   kubectl port-forward -n openproject deployment/openproject-web 8080:8080
   curl http://localhost:8080/api/metrics
   
   # Check Prometheus targets
   kubectl port-forward -n monitoring svc/prometheus-server 9090:80
   # Visit http://localhost:9090/targets
   ```

4. **Scaling not responsive:**
   - Check if trigger thresholds are appropriate for your workload
   - Verify `pollingInterval` is suitable (lower = more responsive, higher = less overhead)
   - Check `cooldownPeriod` isn't too long for your scaling needs

## Advanced Configuration

### Authentication for Prometheus

If your Prometheus requires authentication:

```yaml
# Create secret with credentials
apiVersion: v1
kind: Secret
metadata:
  name: prometheus-auth
type: Opaque
stringData:
  username: "prometheus-user"
  password: "prometheus-password"
---
# Reference in ScaledObject trigger
keda:
  triggers:
    - type: prometheus
      metadata:
        serverAddress: https://prometheus.example.com
        # ... other config
      authenticationRef:
        name: prometheus-auth
        kind: SecretAuth
```

### Custom Scaling Behavior

Fine-tune scaling behavior:

```yaml
keda:
  advanced:
    horizontalPodAutoscalerConfig:
      behavior:
        scaleDown:
          stabilizationWindowSeconds: 300
          policies:
          - type: Pods
            value: 1
            periodSeconds: 60
          - type: Percent  
            value: 10
            periodSeconds: 60
          selectPolicy: Min
        scaleUp:
          stabilizationWindowSeconds: 60
          policies:
          - type: Pods
            value: 2
            periodSeconds: 60
          - type: Percent
            value: 50 
            periodSeconds: 60
          selectPolicy: Max
```

### Fallback Configuration

Handle metric server outages:

```yaml
keda:
  fallback:
    failureThreshold: 3
    replicas: 3  # Fallback to 3 replicas if metrics unavailable
```

## Production Considerations

1. **Resource Limits**: Set appropriate CPU/memory limits on KEDA components
2. **Monitoring**: Monitor KEDA operator health and scaling events
3. **Testing**: Test autoscaling behavior under load before production
4. **Backup Strategy**: Consider fallback replicas for metric server outages
5. **Security**: Use authentication for Prometheus in production environments
6. **Networking**: Ensure KEDA can reach Prometheus across namespaces

## Migration from HPA

If migrating from standard HPA:

1. **Backup existing HPA configuration**
2. **Disable existing HPA**: `kubectl delete hpa <name>`
3. **Enable KEDA**: Set `keda.enabled: true`
4. **Test thoroughly** before production deployment

KEDA creates its own HPA internally, so you cannot run both simultaneously on the same deployment.

## Troubleshooting Guide

| Issue | Cause | Solution |
|-------|--------|----------|
| ScaledObject exists but no scaling | No triggers active | Check trigger thresholds and metrics |
| Scaling too aggressive | Short cooldown/polling | Increase `cooldownPeriod` and `pollingInterval` |
| Metrics unavailable | Prometheus not reachable | Verify `serverAddress` and network connectivity |
| Not scaling down to minimum | Active triggers above threshold | Check trigger conditions and thresholds |
| Authentication errors | Wrong credentials | Verify `authenticationRef` secret |
| Memory issues in KEDA | High metric cardinality | Optimize Prometheus queries, add query limits |

For more information, see the [official KEDA documentation](https://keda.sh/docs/).