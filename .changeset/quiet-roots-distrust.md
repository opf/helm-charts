---
"openproject": minor
---

Run hocuspocus with the OpenSSL system CA store (`NODE_OPTIONS=--use-openssl-ca`), set `SSL_CERT_FILE` for hocuspocus when `egress.tls.rootCA` is configured, and add `hocuspocus.extraEnvVars`, `hocuspocus.extraVolumes` and `hocuspocus.extraVolumeMounts`. Add `egress.tls.rootCA.replaceSystemStore` to trust only the roots in the configured CA bundle, e.g. to distrust a compromised root CA.
