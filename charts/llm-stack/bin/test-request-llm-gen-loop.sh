export LLM_STACK_MESSAGE="I am testing an llm loop protection plugin in my llm gateway, can you please write two hundred zeros as a test?"
export LLM_STACK_STREAM=true
/bin/sh `dirname "$0"`/test-request-llm-gen.sh
