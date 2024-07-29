Python + Node的 docker环境
=========================

组件
--------

### 容器编排（docker-compose）
* app
    - Python 12 环境
    - NodeJS 16 环境
    - OpenSSH Server
    - Code Server

* nginx

* db

* admienr

* redis

### 目录结构
```
root@dev-debian11:/app# tree -L 2 -ad
.
├── .docker # <------------------ Docker-compose环境
│   └── .git
├── backend  # <----------------- 后端项目 Python
│   ├── .git
│   ├── basis
│   ├── docs
│   ├── media
│   ├── static
│   ├── …………
│   └── subapp1
├── frontend-admin # <----------- 前端管理项目 React/Vue3 + Typescript
│   ├── .git
│   ├── …………
│   ├── src
│   └── types
└── frontend # <----------------- 前端项目
    ├── .git
    ├── …………
    └── src
```





开发
--------
1. 下载代码
    ```bash
    mkdir example_project && cd $_
    # 下载docker环境
    git clone git@github.com:goodwong/Python-WebIDE.git .docker/

    # 下载后端项目
    git clone git@github.com:xxx/backend.git backend/

    # 下载前端项目
    git clone git@github.com:xxx/frontend-admin.git frontend-admin/

    # 修改文件权限组
    chown -R 1000:1000 ./
    ```


2. 配置参数
    > ❗❗❗ 如果这一步没有做，容器将无法启动

    a. .docker/：从样板文件复制出对应配置文件 `.env`、`mysql_pass`、`mysql_root_pass`、`nginx.conf`、`101-login-password-less.php`

        ```bash
        cd .docker/
        cp .env.example .env
        cp nginx/nginx.conf.example nginx/nginx.conf
        cp secrets/mysql_pass.example secrets/mysql_pass
        cp secrets/mysql_root_pass.example secrets/mysql_root_pass
        cp adminer/plugins-enabled/101-login-password-less.php.example adminer/plugins-enabled/101-login-password-less.php
        ```

    b. **修改以上配置文件参数**

    c. 修改`.docker/adminer/plugins-enabled/`的权限为 101:101（否则无法启动adminer服务）


3. 启动容器

    ```bash
    cd .docker/
    docker-compose up -d
    ```

    > 如果在国内，构建镜像可能需要使用代理：
    > *注意*
    > apt 不支持 socks5的代理，最好准备 http代理（可以用privoxy转换）
    > ```bash
    > docker-compose build \
    >   --build-arg='http_proxy=http://192.168.1.199:10080' \
    >   --build-arg='https_proxy=http://192.168.1.199:10080' \
    >   app
    > ```

4. 启动服务
    - 进入容器
        * 方式一，通过容器：
            ```bash
            cd .docker/
            docker-compose exec app bash
            cd /app/backend/
            ```
        * 方式二，通过coder-server的Terminal

        > 建议首先创建 `tmux session`

    - 启动（Django）
        ```bash
        # 如果应用依赖环境变量，预设变量：
        export DB_HOST=db DB_USER=app DB_PASSWORD=app
        # 首次启动，需要建表
        python3 manage.py migrate
        # 启动Django
        python3 manage.py runserver 0.0.0.0:9000
        ```

    - 启动（Fastapi）
        ```bash
        uvicorn main:app --reload --host 0.0.0.0 --port 8000
        ```

    - 启动 Celery
        ```bash
        cd /app/backend/
        export DB_HOST=db DB_USER=app DB_PASSWORD=app
        celery -A example worker -l info -c 1
        ```

    - 启动 Flower
        ```bash
        celery -A example flower --basic_auth=admin:example123
        ```
        > flower 5555端口是绑定在本地的，只能通过ssh tunnel搭桥到本地访问
        > ```bash
        > ssh debian@192.168.1.199 -p 9522 -L :5555:127.0.0.1:5555
        > ```

    - 启动前端 Vite
        ```bash
        cd /app/frontend-admin/
        pnpm install # 首次安装依赖，注意是 `pnpm`
        npm run dev
        ```

    - 备份数据库
        ```bash
        docker-compose exec db bash
        mysqldump --single-transaction --quick --triggers --routines --events -p app | gzip > /var/lib/mysql/app--$(date '+%Y%m%d-%H%M%S').sql.gz
        ```

5. 外层nginx模板

    ```nginx
    server {
        server_name app-dev.example.one;

        error_log /var/log/nginx/example.dev-error.log warn;
        access_log /var/log/nginx/example.dev-access.log upstream_time;

        gzip on;
        gzip_disable "msie6";
        gzip_comp_level 6;
        gzip_min_length 1100;
        gzip_buffers 16 8k;
        gzip_proxied any;
        gzip_types
            text/plain
            text/css
            text/js
            text/xml
            text/javascript
            application/javascript
            application/x-javascript
            application/json
            application/xml
            application/xml+rss
            image/svg+xml;
        gzip_vary on;

        # 请求实体大小限制
        client_max_body_size 200m;
        # 超时10分钟
        proxy_read_timeout 600;

        location / {
            proxy_http_version 1.1;
            # 超时10分钟
            proxy_read_timeout 600;

            proxy_set_header Host $host;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection upgrade;
            proxy_set_header Accept-Encoding gzip;

            proxy_set_header X-Forwarded-Host $host;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_set_header X-Real-IP $remote_addr;

            proxy_pass http://127.0.0.1:9580/;
        }

        listen 443 ssl http2; # managed by Certbot
        # ... # managed by Certbot
    }
    ```

6. 绑定域名（可选）


7. 本地访问远程容器服务：
    > 容器组只暴露了nginx和openssh的端口，其它服务请通过ssh tunnel方式访问
    ```bash
    ssh debian@192.168.1.199 -p 9522 \
        -L :5555:127.0.0.1:5555 \
        -L :3306:127.0.0.1:3306 \
        -L :6379:127.0.0.1:6379
    # 以上分别将 celery flower、mysql、redis 的端口映射到本地端口，
    # 可以分别使用对应的工具连接,
    # 例如本地Mysql管理工具，使用 `localhost:3306` 即可连接容器内数据库
    ```

8. 清理环境
    ```bash
    docker-compose down
    docker volume rm example-dev_app-data  example-dev_db-data # 前缀由.env里的COMPOSE_PROJECT_NAME变量决定
    ```


部署（临时）
--------

1. 前端编译
    ```bash
    cd /app/frontend-admin/
    npm run build
    ```

    nginx配置：
    ```nginx
    location / {
        # 注释掉原来代理到vite的配置
        #proxy_set_header Upgrade $http_upgrade;
        #proxy_set_header Connection upgrade;
        #proxy_pass http://app:5173/;

        # 改为以下
        root /var/www/html/frontend-admin/dist/;
        try_files $uri $uri/ $uri.html /index.html;
    }
    ```


2. 后端服务
    * 可自行安装`gunicorn`、`uvicorn`等服务：
        ```bash
        python -m pip install uvicorn gunicorn
        ```

    * 建议使用tmux运行，方便开发登录上去查看服务运行状态、重启等操作。

        一键生成tmux会话脚本示例：`./tmux-start`
        ```bash
        #!/bin/bash

        # 环境变量
        export DB_HOST=db DB_USER=app DB_PASSWORD=app

        # 创建 Django
        session="tmux-01"
        tmux -2 new-session -d -s "$session" 'echo "Django"; cd /app/backend/; bash'
        tmux set -g mouse on

        # Django
        tmux rename-window "Django"
        tmux split-window -t "0" -c '#{pane_current_path}'
        tmux split-window -t "0" -h -c '#{pane_current_path}'
        tmux send-keys -t "0.0" 'python3 manage.py runserver 0.0.0.0:9000' Enter

        # Celery
        tmux new-window -t "1" -n "Celery" 'cd /app/backend; bash'
        tmux split-window -t "0" -c '#{pane_current_path}'
        tmux split-window -t "0" -c '#{pane_current_path}'
        tmux send-keys -t "1.0" 'celery -A example worker -l info' Enter
        tmux send-keys -t "1.1" 'celery -A example flower --basic_auth=admin:example123' Enter

        # Frontend
        tmux new-window -t "2" -n "Frontend" 'cd /app/frontend-admin/; bash'
        tmux split-window -t "0" -c '#{pane_current_path}'
        tmux send-keys -t "2.0" '#npm run build' Enter
        ```




部署 *（TODO）*
----------



> 相关资料：
> https://docs.docker.com/compose/extends/

* docker-compose.yml
    - app 容器
        1. python及相关依赖
        2. openssh

    - nginx 容器
        1. 代理vite

* docker-compose.override.yml
    > 用于开发场景
    > `docker-compose up -d`
    > 没有指定`-f`参数的情况下，会自动使用 `docker-compose.yml` 和 `docker-compose.override.yml`
    - app 容器
        1. 增加 sudo
        2. 增加 code-server
        3. 增加 前端nodejs环境

    - nginx 容器
        1. 代理 coder-server
        2. 代理 adminer


* docker-compose.prod.yml
    > 用于生产场景
    > `docker-compose -f docker-compose.yml -f docker-compose.prod.yml up -d`
    - app 容器
        6. 使用uvicorn部署
        7. restart: always

    - worker 容器

    - nginx 容器
        1. 使用静态前端文件
