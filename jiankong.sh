#!/bin/bash

LOG_FILE="./00000chognqi.txt"

# 确保日志文件存在并赋予权限
if [ ! -f "$LOG_FILE" ]; then
    touch "$LOG_FILE"
    chmod 666 "$LOG_FILE"
fi

while true; do
    echo "$(date): Starting the script" >> "$LOG_FILE"

    ###############################
    # 清理 next-server 进程
    NEXT_SERVER_PIDS=$(ps aux | grep '[n]ext-server' | awk '{print $2}')
    if [ -z "$NEXT_SERVER_PIDS" ]; then
        echo "$(date): No next-server process found." >> "$LOG_FILE"
    else
        for PID in $NEXT_SERVER_PIDS; do
            echo "$(date): Found next-server with PID $PID. Attempting to kill..." >> "$LOG_FILE"
            sudo kill -9 "$PID"
            sleep 1
            if ps -p "$PID" > /dev/null 2>&1; then
                echo "$(date): ❌ Failed to kill PID $PID" >> "$LOG_FILE"
            else
                echo "$(date): ✅ Successfully killed PID $PID" >> "$LOG_FILE"
            fi
        done
    fi

    ###############################
    # 清理监听端口 3000 的进程
    PORT_3000_PIDS=$(lsof -ti :3000)
    if [ -z "$PORT_3000_PIDS" ]; then
        echo "$(date): No process found listening on port 3000." >> "$LOG_FILE"
    else
        for PID in $PORT_3000_PIDS; do
            echo "$(date): Found process on port 3000 with PID $PID. Attempting to kill..." >> "$LOG_FILE"
            sudo kill -9 "$PID"
            sleep 1
            if ps -p "$PID" > /dev/null 2>&1; then
                echo "$(date): ❌ Failed to kill port 3000 PID $PID" >> "$LOG_FILE"
            else
                echo "$(date): ✅ Successfully killed port 3000 PID $PID" >> "$LOG_FILE"
            fi
        done
    fi

    ###############################
    # 启动主程序
    export PYTORCH_MPS_HIGH_WATERMARK_RATIO=0.0 && ./run_rl_swarm.sh

    ###############################
    # 检查是否意外退出
    if [ $? -ne 0 ]; then
        echo "$(date): run_rl_swarm.sh exited unexpectedly" >> "$LOG_FILE"
        sleep 20

        # 再次清理 next-server
        NEXT_SERVER_PIDS=$(ps aux | grep '[n]ext-server' | awk '{print $2}')
        if [ -z "$NEXT_SERVER_PIDS" ]; then
            echo "$(date): No next-server process found." >> "$LOG_FILE"
        else
            for PID in $NEXT_SERVER_PIDS; do
                echo "$(date): Found next-server with PID $PID. Attempting to kill..." >> "$LOG_FILE"
                sudo kill -9 "$PID"
                sleep 1
                if ps -p "$PID" > /dev/null 2>&1; then
                    echo "$(date): ❌ Failed to kill PID $PID" >> "$LOG_FILE"
                else
                    echo "$(date): ✅ Successfully killed PID $PID" >> "$LOG_FILE"
                fi
            done
        fi

        # 再次清理端口 3000
        PORT_3000_PIDS=$(lsof -ti :3000)
        if [ -z "$PORT_3000_PIDS" ]; then
            echo "$(date): No process found listening on port 3000." >> "$LOG_FILE"
        else
            for PID in $PORT_3000_PIDS; do
                echo "$(date): Found process on port 3000 with PID $PID. Attempting to kill..." >> "$LOG_FILE"
                sudo kill -9 "$PID"
                sleep 1
                if ps -p "$PID" > /dev/null 2>&1; then
                    echo "$(date): ❌ Failed to kill port 3000 PID $PID" >> "$LOG_FILE"
                else
                    echo "$(date): ✅ Successfully killed port 3000 PID $PID" >> "$LOG_FILE"
                fi
            done
        fi

        sleep 20
        echo "$(date): Restarting run_rl_swarm.sh" >> "$LOG_FILE"
    fi

    sleep 60
done
