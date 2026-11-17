---
"openproject": minor
---

Add a Caddy sidecar to each web pod, enabling Zstandard and gzip compression for eligible responses. The existing HTTP Service now routes through Caddy; ingress TLS and Hocuspocus routing stay unchanged. Configure `proxy.trustedProxies` for your ingress or load balancer, or clear it for direct public access. Set `proxy.enabled: false` when an existing proxy already handles this work.
