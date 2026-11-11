---
"openproject": patch
---

use 120 seconds as a default for initialDelaySeconds across all probes
giving especially good_job workers enough time to boot before being restarted
due to failing liveness probes
