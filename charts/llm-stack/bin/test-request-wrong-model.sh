PORT=${PORT:-80}
HOST=${HOST:-llm-stack.localhost}

curl http://$HOST:$PORT/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer sk-client-v1-abcdef123456" \
  -d '{
    "messages": [
      {
        "role": "user",
        "content": "Hello, how are you?"
      }
    ],
    "model": "qwen3.6-35b-a3b-fp8"
  }'
