# 安装zsh、wget
sudo apt-get instal zsh wget

# 查看Ubuntu安装了哪些shell
cat /etc/shells

# 查看当前正在运行的是哪个版本的shell
echo $SHELL/bin/bash

# 获取并安装oh-my-zsh
wget --no-check-certificate https://raw.githubusercontent.com/sadjason/OpenStack/master/install-oh-my-zsh.sh -O -| sh

# 替换bash为zsh
chsh -s /bin/zsh

# 重启系统
##########################################

# 重启后，配置zsh
source ~/.zshrc
