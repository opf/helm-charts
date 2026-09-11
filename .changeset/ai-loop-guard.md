---
"llm-stack": minor
---

Added the ai-loop-guard plugin for early detection of upstream LLMs getting stuck in a request. 
The plugin terminates such generation streams early and informs the client using `finish_reason=ai-loop-guard` 
in the final chunk.  