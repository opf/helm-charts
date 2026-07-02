# OpenProject Helm Chart

OpenProject is a web-based project management system for location-independent team collaboration.

## TL;DR

```bash
helm repo add openproject https://charts.openproject.org
helm upgrade --create-namespace --namespace openproject --install my-openproject openproject/openproject
```

## Documentation

For more details please refer to our [documentation](https://www.openproject.org/docs/installation-and-operations/installation/helm-chart/).

## Other helm charts

Next to the OpenProject chart, this repository also contains the following helm charts
that may be used together with OpenProject.

### llm-stack

```
helm repo add openproject https://charts.openproject.org
helm upgrade --create-namespace --namespace llm-stack --install my-llm-stack openproject/llm-stack -f my-values.yaml
```

Please refer to the [README.md](https://github.com/opf/helm-charts/blob/main/charts/llm-stack/README.md) for informaion
including which values are required.
