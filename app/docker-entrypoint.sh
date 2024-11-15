
USERNAME=$(whoami)
USER_HOME=$HOME

if [ ! -f ~/.bashrc ]; then
    sudo cp /root/.bashrc $USER_HOME/.bashrc
    sudo chown $USERNAME:$USERNAME $USER_HOME/.bashrc

    # bash 支持常用别名
    sed -i 's/# export LS_OPTIONS/export LS_OPTIONS/g' ~/.bashrc
    sed -i 's/# eval/eval/g' ~/.bashrc
    sed -i 's/# *alias /alias /g' ~/.bashrc

    # bash 支持中文（修改后需要退出后重新进）
    echo 'export LANG=C.UTF-8' >> ~/.bashrc

    # git 支持中文显示
    git config --global core.fileMode false
    git config --global core.quotepath off
    git config --global core.pager more
fi

sudo service ssh start \
&& /usr/bin/code-server --bind-addr=0.0.0.0:8080 /app/backend/
