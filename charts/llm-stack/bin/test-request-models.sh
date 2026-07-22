PORT=${PORT:-80}
HOST=${HOST:-llm-stack.localhost}

curl http://$HOST:$PORT/v1/models -H "Authorization: Bearer sk-client-v1-abcdef123456"
