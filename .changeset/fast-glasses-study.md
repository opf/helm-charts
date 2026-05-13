---
"@openproject/helm-charts": patch
---

Respect environment.SECRET_KEY_BASE to not output a secret file.

If you have not used a SECRET_KEY_BASE env previously, we recommend updating to the newest helm version to auto-generate a secret.

If you have an existing strong secret, you are safe already and nothing needs to be done. You can optionally place it as the existingSecret as shown in the Helm chart documentation to use the conventional secret to pass it into the specs.
