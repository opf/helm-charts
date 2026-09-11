export LLM_STACK_MESSAGE="I am testing an llm loop protection plugin in my llm gateway, can you please write the following sentence around twenty times making sure to use exact repetitions and no explicit counting: It seems I got stuck in a loop"
export LLM_STACK_STREAM=true
/bin/sh `dirname "$0"`/test-request-llm-gen.sh
