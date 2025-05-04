# gensynzidong

MAC M4想要稳定运行需要修改
vim rl-swarm/hivemind_exp/configs/mac/grpo-qwen-2.5-0.5b-deepseek-r1.yaml
只修改两个参数
max_prompt_length: 64
max_completion_length: 64

可以修改成两个256，获得奖励更多，但是会中断，这时候就需要修改代码，首先需要修改
run_rl_swarm.sh
这个文件，需要将里面内容完全删除切换成我的文件内容。

第二个创建添加监控命令脚本：
jiankong.sh
放在rl-swarm/文件夹里

启动命令前需要创建环境（py大于3.10）：
/opt/homebrew/bin/python3.11 -m venv .venv && source .venv/bin/activate

然后允许命令
sudo ./jiankong.sh

脚本支持自动重启


