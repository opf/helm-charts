---
"llm-stack": minor
---

* updated apisix (for it to report additional relevant LLM metrics)
* added extra metric labels to prometheus metrics (so data can be sliced along feature and endpoint)
* added protocol (http/https) to test scripts as vars (as I was commonly changing it in the file for dev/prod tests),
* increased gateway timeout for non-reasoning requests (failed often during recent prompt optimization)
* added traffic simulation script (to test basic charting)
* stripping headers like username and feature id upstream using a plugin (so they can be read inside apisix but 3rd party upstream providers don't see them)
