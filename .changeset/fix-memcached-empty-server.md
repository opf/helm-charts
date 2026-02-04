---
"@openproject/helm-charts": patch
---

fix: prevent invalid ":" value in memcached secret when external server not configured

When `memcached.bundled: false` is set without providing external connection values,
the secret now correctly sets an empty string instead of ":" which caused YAML parse errors.
