---
"@openproject/helm-charts": major
---

Improve secret management.

Add support for `existingSecret` for `postgresql` authentication.
Move `s3.accessKeyId` and `s3.secretAccessKey` to `s3.auth.` and add an `existingSecret` option for S3.
