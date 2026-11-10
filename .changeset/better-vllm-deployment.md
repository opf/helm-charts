---
"llm-stack": major
---

Improved the vllm deployment configs by
* adding strategy options for limited compute resources (i.e. preventing deadlocks on limited gpus and memory for vllm)
* adding a proper startupProbe
* simplifying shared mem
* adding node-local options for persistence
