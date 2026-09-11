# llm-stack

## 1.1.0

### Minor Changes

- 7cbea02: Added the ai-loop-guard plugin for early detection of upstream LLMs getting stuck in a request.
  The plugin terminates such generation streams early and informs the client using `finish_reason=ai-loop-guard`
  in the final chunk.

## 1.0.2

### Patch Changes

- 7950530: Made the digest header for the apisix config update variable so that config updates are accepted by apisix

## 1.0.1

### Patch Changes

- cf0687f: change consumer usage limits key to camel case, increase default limit
- a2c4c95: llm-stack: /v1/models endpoint
