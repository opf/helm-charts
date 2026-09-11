LLM_STACK_PORT=${LLM_STACK_PORT:-80}
LLM_STACK_HOST=${LLM_STACK_HOST:-llm-stack.localhost}
LLM_STACK_KEY=${LLM_STACK_KEY:-sk-client-v1-abcdef123456}

curl http://${LLM_STACK_HOST}:${LLM_STACK_PORT}/v1/models -H "Authorization: Bearer ${LLM_STACK_KEY}"
