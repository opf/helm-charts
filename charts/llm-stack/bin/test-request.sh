curl http://127.0.0.1:9082/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer sk-client-v1-abcdef123456" \
  -d '{
    "messages": [
      {
        "role": "user",
        "content": "Hello, how are you?"
      }
    ],
    "model": "Qwen/Qwen3.6-35B-A3B-FP8"
  }'