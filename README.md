## docker mongodb 分片


### Pre-requisites
1. 安装docker
2. 安装 mongodb https://www.mongodb.com/docs/manual/installation/
3. 部署切片集群 https://www.mongodb.com/docs/manual/tutorial/deploy-shard-cluster/
4. 使用keyfile部署切片集群 https://www.mongodb.com/docs/manual/tutorial/deploy-sharded-cluster-with-keyfile-access-control/

> 要避免因 IP 地址变更而更新配置，请使用 DNS 主机名而非 IP 地址。在配置副本集成员或分片集群成员时，使用 DNS 主机名而非 IP 地址尤为重要。

### 创建keyfile

```bash
openssl rand -base64 756 > keyfile/key
chmod 400  keyfile/key
```

### 创建带keyfile的镜像

Dockerfile
```dockerfile
FROM mongo:latest
ADD keyfile /data/keyfile
RUN chmod 400 /data/keyfile/key
RUN chown -R mongodb:mongodb /data/keyfile
```

### 创建镜像 mongo:keyfile

```bash
make build
```

### 创建docker

compose文件: mongo_server/docker-compose.yaml

将创建

#### config
* config_1
* config_2
* config_3

#### shard_1
* config_1_1
* config_1_2
* config_1_3
  
#### shard_2
* config_2_1
* config_2_2
* config_2_3

#### mongos
* mongos_1 27117
* mongos_2 27118

```bash
make install
```

### 配置副本集

> 通过本地主机接口将 mongosh 连接到一个 mongod 实例。您必须在与 mongod 实例相同的物理机器上运行 mongosh。

登录 config_1

```bash
mongosh mongodb://localhost
```

使用 rs.initiate() 方法和配置文档启动副本集：

```javascript
rs.initiate(
  {
    _id: "config_rs",
    configsvr: true,
    members: [
      { _id : 0, host : "config_1:27017" },
      { _id : 1, host : "config_2:27017" },
      { _id : 2, host : "config_3:27017" }
    ]
  }
)
```

查看

```javascript
rs.status()
```

### 分片副本集

> 通过本地主机接口将 mongosh 连接到一个 mongod 实例。您必须在与 mongod 实例相同的物理机器上运行 mongosh。

登录 shard_1_1

```bash
mongosh mongodb://localhost
```

使用 rs.initiate() 方法和配置文档启动副本集：

```javascript
rs.initiate(
  {
    _id: "shard1_rs",
    members: [
      { _id : 0, host : "shard_1_1:27017" },
      { _id : 1, host : "shard_1_2:27017" },
      { _id : 2, host : "shard_1_3:27017" }
    ]
  }
)
```


登录 shard_2_1

```bash
mongosh mongodb://localhost
```

使用 rs.initiate() 方法和配置文档启动副本集：

```javascript
rs.initiate(
  {
    _id: "shard2_rs",
    members: [
      { _id : 0, host : "shard_2_1:27017" },
      { _id : 1, host : "shard_2_2:27017" },
      { _id : 2, host : "shard_2_3:27017" }
    ]
  }
)
```

### 创建用户管理员

> 重要
创建第一个用户后，本地主机异常就不再可用。
第一个用户必须拥有创建其他用户的特权，如具备 userAdminAnyDatabase 的用户。这样可以确保在自管理部署中的本地主机异常关闭后，您可以创建更多用户。
如果至少一个用户没有创建用户的权限，一旦本地主机异常关闭，您可能无法使用创建或修改具有新特权的用户，因此无法访问必要的操作。
使用 db.createUser() 方法添加用户。该用户应在 admin 数据库中至少拥有 userAdminAnyDatabase 角色。
您必须连接到主节点才能创建用户。

登录 mongos_1

```javascript
db.getSiblingDB("admin").createUser(
  {
    user: "admin",
    pwd: passwordPrompt(),
    roles: [
      { role: 'readWriteAnyDatabase', db: 'admin' },
      { role: 'dbAdminAnyDatabase', db: 'admin' },
      { role: 'clusterAdmin', db: 'admin' },
      { role: 'userAdminAnyDatabase', db: 'admin' }
    ]
  }
)
```


### 创建分片本地用户管理员（可选）。

登录 shard_1_1

```javascript
db.getSiblingDB("admin").createUser(
  {
    user: "admin",
    pwd: passwordPrompt(),
    roles: [
      { role: 'readWriteAnyDatabase', db: 'admin' },
      { role: 'dbAdminAnyDatabase', db: 'admin' },
      { role: 'clusterAdmin', db: 'admin' },
      { role: 'userAdminAnyDatabase', db: 'admin' }
    ]
  }
)
```

### 向集群添加分片

要继续，您必须连接到 mongos，并以分片集群的集群管理员用户身份进行身份验证。
若要将每个分片添加到集群，请使用 sh.addShard() 方法。如果分片是副本集，请指定副本集的名称，然后指定该副本集的节点。在生产部署中，所有分片都应是副本集。
以下操作将单个分片副本集添加到该集群中：

```javascript
sh.addShard("shard1_rs/shard_1_1:27017,shard_1_2:27017,shard_1_3:27017")
sh.addShard("shard2_rs/shard_2_1:27017,shard_2_2:27017,shard_2_3:27017")
```

### 更新用户

```javascript
db.getSiblingDB("admin").updateUser("admin",
  {
    roles: [
      { role: 'readWriteAnyDatabase', db: 'admin' },
      { role: 'dbAdminAnyDatabase', db: 'admin' },
      { role: 'clusterAdmin', db: 'admin' },
      { role: 'userAdminAnyDatabase', db: 'admin' }
    ]
  }
)
```

### 集合分片

```javascript
sh.shardCollection("<database>.<collection>", { <key> : <direction> } )
```

