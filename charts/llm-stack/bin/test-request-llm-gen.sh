LLM_STACK_PORT=${LLM_STACK_PORT:-80}
LLM_STACK_HOST=${LLM_STACK_HOST:-llm-stack.localhost}
LLM_STACK_KEY=${LLM_STACK_KEY:-sk-client-v1-abcdef123456}
LLM_STACK_MODEL=${LLM_STACK_MODEL:-qwen3.6-35b-a3b}
LLM_STACK_MESSAGE=${LLM_STACK_MESSAGE:-"Hello, how are you"?}
LLM_STACK_STREAM=${LLM_STACK_STREAM:-false}

curl http://$LLM_STACK_HOST:$LLM_STACK_PORT/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${LLM_STACK_KEY}" \
  -d '{
    "messages": [
      {
        "role": "user",
        "content": "'?"${LLM_STACK_MESSAGE}"'"
      }
    ],
    "model": "'"${LLM_STACK_MODEL}"'",
    "stream": '${LLM_STACK_STREAM}'
  }'
