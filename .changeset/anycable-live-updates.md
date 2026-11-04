---
"openproject": minor
---

Add an optional AnyCable server (`anycable.enabled`) and the OpenProject configuration for live updates (`openproject.live_updates`), which can also connect to an external AnyCable server. Both require OpenProject 18.0 or newer and are disabled by default. With the included AnyCable server, the ingress routes `/cable` and `/events` to it and keeps OpenProject's `/_anycable` RPC endpoint off the public ingress.
