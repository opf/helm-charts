
## Local Development

### Creating the cluster

```bash
k3d cluster create llm-stack-dev --port "8080:80@loadbalancer"
```

### Editing host file for ingress

Add the following line to your `/etc/hosts` file to map the `llm-stack.local` domain to your local machine. 

```
127.0.0.1 llm-stack.local
```

### Installing the chart

#### With cpu-based VLLM and a tiny model enabled

```bash
helm install dev-release . -f examples/local-vllm-cpu.yaml
```

```bash
bash bin/test-request-local-vllm.sh
```

#### Using a third party provider instead of vllm

Adjust the scaleway api path and auth token in `examples/scaleway-qwen-36.yaml` with your own credentials.

```bash
helm install dev-release . -f examples/scaleway-qwen-36.yaml
```

```bash
bash bin/test-request-scaleway.sh
```