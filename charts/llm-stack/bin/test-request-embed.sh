LLM_STACK_PORT=${LLM_STACK_PORT:-80}
LLM_STACK_HOST=${LLM_STACK_HOST:-llm-stack.localhost}
LLM_STACK_KEY=${LLM_STACK_KEY:-sk-client-v1-abcdef123456}
LLM_STACK_EMBEDDING_MODEL=${LLM_STACK_EMBEDDING_MODEL:-bge-multilingual-gemma2}
LLM_STACK_EMBEDDING_DOCS=${LLM_STACK_EMBEDDING_DOCS:-'["Hello, how are you?"]'}

curl -v http://$LLM_STACK_HOST:$LLM_STACK_PORT/v1/embeddings \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${LLM_STACK_KEY}" \
  -d '{
      "model": "'"${LLM_STACK_EMBEDDING_MODEL}"'",
      "input": '"${LLM_STACK_EMBEDDING_DOCS}"'
    }'
