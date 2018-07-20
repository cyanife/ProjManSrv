# 通过Docker搭建开发项目管理服务器

## 目标

实现Django开发的项目管理支持Server。

支持Server计划提供如下服务：

- PostgreSQL (DB)
- Redmine (PM)
- Gitlab (SCM)
- Jenkins (CI)

为增加复用性与降低运维难度，采用Docker搭建。

## 环境

Ubuntu Server 18.04 @ VMware (DEV ENV)

## 准备

按照Docker官方[文档](https://docs.docker.com/install/linux/docker-ce/ubuntu/)安装Docker CE版。

```bash
docker -v
> Docker version 18.03.1-ce, build 9ee9f40
```

根据Docker的实现机理，容器的生命周期与主进程一致，即在同一容器内，应只有一个单一的主进程执行，故多服务的场景应通过多个容器协同实现。

采用Docker官方项目Compose实现多容器关联。

同样，根据Docker Compose的官方[文档](https://docs.docker.com/compose/install/)安装Compose。

```bash

sudo curl -L https://github.com/docker/compose/releases/download/1.22.0-rc2/docker-compose-`uname -s`-`uname -m` -o /usr/local/bin/docker-compose
# Apply executable permissions
sudo chmod +x /usr/local/bin/docker-compose
# Install command completion
sudo curl -L https://raw.githubusercontent.com/docker/compose/1.21.2/contrib/completion/bash/docker-compose -o /etc/bash_completion.d/docker-compose
# Test
docker-compose --version
> docker-compose version 1.22.0-rc2, build 6817b533
```

## 配置

整体文件结构如下所示：

```bash
ProjManSrv
├── docker-compose.yml
├── gitea-ssh.sh
├── nginx
│   ├── html
│   │   └── index.html
│   └── nginx.conf
└── README.md
```

容器的外部卷放置在`/srv/ProjManSrv`目录下。

配置的核心内容为Compose模板文件。compose通过读取该模板配置各容器协同，文件格式为YAML。

要点：Compose1.0以后的版本中，所有容器被自动配置于同一network下，均可互相访问，故新版compose不推荐采用`links`，尽量改用`depends_on`
但与`links`不同，`depends_on`不会向目标容器注入环境变量，而注入环境变量也已经不被compose文档推荐，故应手动配置数据库名称一类的环境变量。

```yaml
version: "3"
services:

    redmine-postgresql:
        restart: unless-stopped # always for production
        image: postgres:latest
        environment:
            - POSTGRES_USER=redmine
            - POSTGRES_PASSWORD=password # change PW here
            - POSTGRES_DB=redmine_production
        volumes:
            - ./data/redmine/postgresql:/var/lib/postgresql/data

    redmine:
        restart: unless-stopped # always for production
        image: sameersbn/redmine:latest
        depends_on:
            - redmine-postgresql
        environment:

            - REDMINE_RELATIVE_URL_ROOT=/redmine
            - DB_ADAPTER=postgresql
            - DB_HOST=redmine-postgresql
            - DB_USER=redmine
            - DB_PASS=password # change PW here
            - DB_NAME=redmine_production

            - SMTP_ENABLED=false
            - SMTP_USER=mailer@example.com
            - SMTP_PASS=password

        volumes:
            - ./data/redmine/redmine:/home/redmine/data

    db: # gitea database hostname should be "db"
        restart: unless-stopped # always for production
        image: postgres:latest
        environment:
            - POSTGRES_USER=gitea
            - POSTGRES_PASSWORD=password # change PW here
            - POSTGRES_DB=gitea
        volumes:
            - ./data/gitea/postgresql:/var/lib/postgresql/data

    gitea:
        restart: 'unless-stopped'
        image: 'gitea/gitea:latest'
        depends_on:
            - db
        ports:
            - '127.0.0.1:10022:22'
        volumes:
            - ./data/gitea/gitea:/data
            - /home/git/.ssh:/data/git/.ssh
        environment:
            - USER_UID=${GIT_UID}
            - USER_GID=${GIT_GID}
            - DB_TYPE=postgres
            - DB_HOST=db
            - DB_NAME=gitea
            - DB_USER=gitea
            - DB_PASSWORD=password
            - ROOT_URL=/gitea/

    nginx:
        restart: unless-stopped
        image: nginx
        volumes:
            - ./nginx/html:/usr/share/nginx/html
            - ./nginx/nginx.conf:/etc/nginx/conf.d/default.conf
        ports:
            - "80:80"
```

配置nginx反向代理，将各服务绑定至子域名。

注意，nginx同样运行在容器中，此时nginx中的localhost/127.0.0.1为容器的回环地址，而不是其他容器端口绑定的宿主机！

在compose中所有容器具有独立网络栈（默认bridge配置下）并处于同一虚拟network中，可互相访问（TCP），故反向代理地址应为其他容器主机名:端口形式。

```nginx
    server {
        listen 80;

        # static-html
        location / {
            index index.html;
            root /usr/share/nginx/html;
        }

        location /redmine {
            proxy_pass         http://redmine;
            proxy_redirect     off;
            proxy_set_header   Host $host;
            proxy_set_header   X-Real-IP $remote_addr;
            proxy_set_header   X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header   X-Forwarded-Host $server_name;
            proxy_set_header   X-NginX-Proxy true;

        }

        location /gitea {
            rewrite ^ /gitea/ last;
        }

        location /gitea/ { #remind trailing slash here!
            proxy_pass         http://gitea:3000/;
            proxy_redirect     off;
            proxy_set_header   Host $host;
            proxy_set_header   X-Real-IP $remote_addr;
            proxy_set_header   X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header   X-Forwarded-Host $server_name;
            proxy_set_header   X-NginX-Proxy true;

        }
    }
```

TODO gitea-ssh.sh

部署
在项目路径下执行如下指令启动/停止服务。

```bash
# start service
docker-compose up -d
# stop service
docker-compose stop

```

启动后，访问`http://127.0.0.1`进入项目主页，或直接通过子网址访问对应服务：

- GitLab: http://127.0.0.1/gitlab
- Redmine: http://127.0.0.1/gitlab
- Jenkins: http://127.0.0.1/gitlab