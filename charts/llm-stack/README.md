# LLM Stack
A helm chart for a self-hosted llm stack featuring:

* Apisix as the AI gateway
  * running in api-based standalone mode (allowing only full config updates via api)
  * having a config seeder job that pushes the route and consumer configs initially using a headless service for pod discovery
* An optional VLLM deployment for hosting an LLM in the cluster
* Optional prometheus and grafana components for local development
* values.yaml files and basic request scripts for local development in `examples/` and `bin/`


## Local Development

### Minimum requirements

* 48gb RAM (64gb would be better)

### Creating the cluster

```bash
k3d cluster create llm-stack-dev --port "8080:80@loadbalancer"
```

### Creating the Secrets

**For the apisix initial config:**
```bash
kubectl create secret generic llm-stack-apisix-initial-config-secret --from-literal=provider_api_key='abc' --from-literal=consumers='[{"name": "consumerA", "key": "sk-client-v1-abcdef123456"}]'
```
* `provider_api_key` is the key of the provider you are forwarding the requests to, e.g. scaleway
* `consumers` is a stringified json array of consumers

**For the apisix admin API:**
```bash
kubectl create secret generic llm-stack-apisix-admin-secret --from-literal=admin='abc' --from-literal=viewer='def'
```

* `admin` is the admin key for editing
* `viewer` is the admin key for viewing only

### Installing the chart

#### With cpu-based VLLM and a tiny model enabled

```bash
helm install dev-release . -f examples/local-vllm-cpu.yaml
```

```bash
bash bin/test-request-local-vllm.sh
```

#### Using scaleway instead of vllm

Adjust the scaleway api path and auth token in `examples/scaleway.yaml` with your own credentials.

```bash
helm install dev-release . -f examples/scaleway.yaml
```

```bash
bash bin/test-request-scaleway.sh
```

### Observability

#### Grafana

Log into grafana at http://grafana.localhost using the default credentials (username: admin, password: admin)

##### Useful queries:

Successful requests for apisix grouped by consumer at 1 min interval:
```promql
sum(increase(apisix_http_status{code=~"[2].."}[1m])) by (consumer)
```

Failing requests for apisix grouped by consumer at 1 min interval:
```promql
sum(increase(apisix_http_status{code=~"[45].."}[1m])) by (consumer)
```
