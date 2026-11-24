import subprocess
import random
import os
import time

ENV_USER_KEYS = ["abc", "abc", "sk-client-v1-abcdef123456"]
TEXTS = ["Hey there, how are you doing?", "It's a nice morning, isn't it?"]
FEATURES = ["ai-text-actions", "ai-text-actions", "plugins", "agents", "agents", "agents", "agents", "agents"]
PORT = 8080
SCRIPTS = ["./test-request-embed.sh", "./test-request-llm-gen.sh", "./test-request-llm-gen.sh"]

if __name__ == "__main__":
    os.chdir(os.path.dirname(__file__))
    while True:
        script = random.choice(SCRIPTS)
        text = str(random.randint(0, 500)) + " " + random.choice(TEXTS)
        feature = random.choice(FEATURES)
        user = random.choice(ENV_USER_KEYS)
        os.environ["LLM_STACK_PORT"] = str(PORT)
        os.environ["LLM_STACK_KEY"] = user
        os.environ["LLM_STACK_MESSAGE"] = text
        os.environ["LLM_STACK_EMBEDDING_DOCS"] = f'["{text}"]'
        os.environ["LLM_STACK_FEATURE"] = feature
        subprocess.call(["bash", script])
        print("ding")
        time.sleep(1)