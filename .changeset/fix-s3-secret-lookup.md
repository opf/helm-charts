---
"@openproject/helm-charts": patch
---

Fix S3 secret lookup

There were two problems:

1. The namespace was hardcoded
2. The whitespace trimming was breaking the yaml

Now the lookup will be based on the namespace where the
release is being deployed, and the whitespace trimming
has been fixed.