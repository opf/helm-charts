---
"@openproject/helm-charts": minor
---

Allow setting options for the deployment strategy:

You can now provide custom options to the strategy, for example:

**values.yaml**: 

```yaml
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxSurge: 30%
    maxUnavailable: 30%
```
