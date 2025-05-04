#!/bin/bash

set -euo pipefail

# General arguments
ROOT=$PWD

export PUB_MULTI_ADDRS
export PEER_MULTI_ADDRS
export HOST_MULTI_ADDRS
export IDENTITY_PATH
export CONNECT_TO_TESTNET
export ORG_ID
export HF_HUB_DOWNLOAD_TIMEOUT=120  # 2 minutes

# Check if public multi-address is given else set to default
DEFAULT_PUB_MULTI_ADDRS=""
PUB_MULTI_ADDRS=${PUB_MULTI_ADDRS:-$DEFAULT_PUB_MULTI_ADDRS}

# Check if peer multi-address is given else set to default
DEFAULT_PEER_MULTI_ADDRS="/ip4/38.101.215.13/tcp/30002/p2p/QmQ2gEXoPJg6iMBSUFWGzAabS2VhnzuS782Y637hGjfsRJ"
PEER_MULTI_ADDRS=${PEER_MULTI_ADDRS:-$DEFAULT_PEER_MULTI_ADDRS}

# Check if host multi-address is given else set to default
DEFAULT_HOST_MULTI_ADDRS="/ip4/0.0.0.0/tcp/38331"
HOST_MULTI_ADDRS=${HOST_MULTI_ADDRS:-$DEFAULT_HOST_MULTI_ADDRS}

DEFAULT_IDENTITY_PATH="$ROOT"/swarm.pem
IDENTITY_PATH=${IDENTITY_PATH:-$DEFAULT_IDENTITY_PATH}

SMALL_SWARM_CONTRACT="0x69C6e1D608ec64885E7b185d39b04B491a71768C"
BIG_SWARM_CONTRACT="0x6947c6E196a48B77eFa9331EC1E3e45f3Ee5Fd58"

CPU_ONLY=${CPU_ONLY:-""}
ORG_ID=${ORG_ID:-""}

GREEN_TEXT="\033[32m"
BLUE_TEXT="\033[34m"
RESET_TEXT="\033[0m"

echo_green() {
    echo -e "$GREEN_TEXT$1$RESET_TEXT"
}

echo_blue() {
    echo -e "$BLUE_TEXT$1$RESET_TEXT"
}

ROOT_DIR="$(cd $(dirname ${BASH_SOURCE[0]}) && pwd)"

cleanup() {
    echo_green ">> Shutting down trainer..."
    rm -r $ROOT_DIR/modal-login/temp-data/*.json 2> /dev/null || true
    kill -- -$$ || true
    exit 0
}

trap cleanup EXIT

cat << "EOF"
    ██████  ██            ███████ ██     ██  █████  ██████  ███    ███
    ██   ██ ██            ██      ██     ██ ██   ██ ██   ██ ████  ████
    ██████  ██      █████ ███████ ██  █  ██ ███████ ██████  ██ ████ ██
    ██   ██ ██                 ██ ██ ███ ██ ██   ██ ██   ██ ██  ██  ██
    ██   ██ ███████       ███████  ███ ███  ██   ██ ██   ██ ██      ██

    From Gensyn

EOF

# Use default values without prompting
CONNECT_TO_TESTNET=true
USE_BIG_SWARM=false
PARAM_B=0.5

if [ "$USE_BIG_SWARM" = true ]; then
    SWARM_CONTRACT="$BIG_SWARM_CONTRACT"
else
    SWARM_CONTRACT="$SMALL_SWARM_CONTRACT"
fi

if [ "$CONNECT_TO_TESTNET" = true ]; then
    echo "Please login to create an Ethereum Server Wallet"
    cd modal-login

    if ! command -v node > /dev/null 2>&1; then
        echo "Node.js not found. Installing NVM and latest Node.js..."
        export NVM_DIR="$HOME/.nvm"
        if [ ! -d "$NVM_DIR" ]; then
            curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
        fi
        [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
        [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
        nvm install node
    fi

    if ! command -v yarn > /dev/null 2>&1; then
        if grep -qi "ubuntu" /etc/os-release 2> /dev/null || uname -r | grep -qi "microsoft"; then
            echo "Detected Ubuntu or WSL Ubuntu. Installing Yarn via apt..."
            curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | sudo apt-key add -
            echo "deb https://dl.yarnpkg.com/debian/ stable main" | sudo tee /etc/apt/sources.list.d/yarn.list
            sudo apt update && sudo apt install -y yarn
        else
            npm install -g --silent yarn
        fi
    fi

    yarn install
    yarn dev > /dev/null 2>&1 &

    SERVER_PID=$!
    echo "Started server process: $SERVER_PID"
    sleep 5

    if open http://localhost:3000 2> /dev/null; then
        echo_green ">> Successfully opened http://localhost:3000 in your default browser."
    else
        echo ">> Failed to open http://localhost:3000. Please open it manually."
    fi

    cd ..

    echo_green ">> Waiting for modal userData.json to be created..."
    while [ ! -f "modal-login/temp-data/userData.json" ]; do
        sleep 5
    done

    ORG_ID=$(awk 'BEGIN { FS = "\"" } !/^[ \t]*[{}]/ { print $(NF - 1); exit }' modal-login/temp-data/userData.json)
    echo "Your ORG_ID is set to: $ORG_ID"

    echo "Waiting for API key to become activated..."
    while true; do
        STATUS=$(curl -s "http://localhost:3000/api/get-api-key-status?orgId=$ORG_ID")
        if [[ "$STATUS" == "activated" ]]; then
            echo "API key is activated! Proceeding..."
            break
        else
            sleep 5
        fi
    done

    ENV_FILE="$ROOT"/modal-login/.env
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "3s/.*/SMART_CONTRACT_ADDRESS=$SWARM_CONTRACT/" "$ENV_FILE"
    else
        sed -i "3s/.*/SMART_CONTRACT_ADDRESS=$SWARM_CONTRACT/" "$ENV_FILE"
    fi
fi

echo_green ">> Getting requirements..."

pip install --upgrade pip
if [ -n "$CPU_ONLY" ] || ! command -v nvidia-smi &> /dev/null; then
    pip install -r "$ROOT"/requirements-cpu.txt
    CONFIG_PATH="$ROOT/hivemind_exp/configs/mac/grpo-qwen-2.5-0.5b-deepseek-r1.yaml"
    GAME="gsm8k"
else
    pip install -r "$ROOT"/requirements-gpu.txt
    pip install flash-attn --no-build-isolation
    case "$PARAM_B" in
        32 | 72) CONFIG_PATH="$ROOT/hivemind_exp/configs/gpu/grpo-qwen-2.5-${PARAM_B}b-bnb-4bit-deepseek-r1.yaml" ;;
        0.5 | 1.5 | 7) CONFIG_PATH="$ROOT/hivemind_exp/configs/gpu/grpo-qwen-2.5-${PARAM_B}b-deepseek-r1.yaml" ;;
    esac
    if [ "$USE_BIG_SWARM" = true ]; then
        GAME="dapo"
    else
        GAME="gsm8k"
    fi
fi

HF_TOKEN=${HF_TOKEN:-""}
if [ -n "${HF_TOKEN}" ]; then
    HUGGINGFACE_ACCESS_TOKEN=${HF_TOKEN}
else
    HUGGINGFACE_ACCESS_TOKEN="None"
fi

echo_green ">> Good luck in the swarm!"
echo_blue ">> Post about rl-swarm on X/twitter! --> https://tinyurl.com/swarmtweet"
echo_blue ">> And remember to star the repo on GitHub! --> https://github.com/gensyn-ai/rl-swarm"

if [ -n "$ORG_ID" ]; then
    python -m hivemind_exp.gsm8k.train_single_gpu \
        --hf_token "$HUGGINGFACE_ACCESS_TOKEN" \
        --identity_path "$IDENTITY_PATH" \
        --modal_org_id "$ORG_ID" \
        --contract_address "$SWARM_CONTRACT" \
        --config "$CONFIG_PATH" \
        --game "$GAME"
else
    python -m hivemind_exp.gsm8k.train_single_gpu \
        --hf_token "$HUGGINGFACE_ACCESS_TOKEN" \
        --identity_path "$IDENTITY_PATH" \
        --public_maddr "$PUB_MULTI_ADDRS" \
        --initial_peers "$PEER_MULTI_ADDRS" \
        --host_maddr "$HOST_MULTI_ADDRS" \
        --config "$CONFIG_PATH" \
        --game "$GAME"
fi

wait
