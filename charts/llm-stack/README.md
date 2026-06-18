# LLM Stack
A helm chart for a self-hosted llm stack featuring:

* Apisix as the AI gateway
  * running in api-based standalone mode (allowing only full config updates via api)
  * having a config seeder job that pushes the route and consumer configs initially using a headless service for pod discovery
* An optional VLLM deployment for hosting an LLM in the cluster
* Optional prometheus and grafana components for local development
* values.yaml files and basic request scripts for local development in `examples/` and `bin/`


## Local Development

### Creating the cluster

```bash
k3d cluster create llm-stack-dev --port "8080:80@loadbalancer"
```

### Editing host file for ingress

Add the following lines to your `/etc/hosts` file to map the `llm-stack.local` and `grafana.local` domain to your local machine. 

```
127.0.0.1 llm-stack.local
127.0.0.1 grafana.local
```

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

Log into grafana at http://grafana.local:8080 using the default credentials (username: admin, password: admin)

##### Useful queries:

Successful requests for apisix grouped by consumer at 1 min interval:
```promql
sum(increase(apisix_http_status{code=~"[2].."}[1m])) by (consumer)
```

Failing requests for apisix grouped by consumer at 1 min interval:
```promql
sum(increase(apisix_http_status{code=~"[45].."}[1m])) by (consumer)
```
