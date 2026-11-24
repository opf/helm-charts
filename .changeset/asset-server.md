---
"openproject": minor
---

Serve the frontend assets from a Caddy Deployment instead of Puma when `ingress.enabled` is true. The Ingress gets a new `<railsRelativeUrlRoot>/assets` path for it. Caddy sends the precompressed `.br` and `.gz` files from the OpenProject image and forwards missing files to the web Service. Set `assetServer.enabled: false` to keep serving assets from Puma.
