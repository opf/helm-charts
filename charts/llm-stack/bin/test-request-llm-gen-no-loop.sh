export LLM_STACK_MESSAGE="Please write a 2 page essay on Popperian falsification."
export LLM_STACK_STREAM=true
/bin/sh `dirname "$0"`/test-request-llm-gen.sh
