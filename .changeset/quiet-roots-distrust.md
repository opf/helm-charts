---
"openproject": minor
---

Run hocuspocus with the OpenSSL system CA store (`NODE_OPTIONS=--use-openssl-ca`) and add `hocuspocus.extraEnvVars`, `hocuspocus.extraVolumes` and `hocuspocus.extraVolumeMounts`. Document how to replace the CA bundle to distrust a root CA.
