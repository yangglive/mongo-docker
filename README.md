## docker mongodb 分片


### Pre-requisites
1. 安装docker
2. 安装 mongodb https://www.mongodb.com/docs/manual/installation/
3. 部署切片集群 https://www.mongodb.com/docs/manual/tutorial/deploy-shard-cluster/
4. 使用keyfile部署切片集群 https://www.mongodb.com/docs/manual/tutorial/deploy-sharded-cluster-with-keyfile-access-control/

> 要避免因 IP 地址变更而更新配置，请使用 DNS 主机名而非 IP 地址。在配置副本集成员或分片集群成员时，使用 DNS 主机名而非 IP 地址尤为重要。

### 创建keyfile

```
openssl rand -base64 756 > keyfile/key
chmod 400  keyfile/key
```

### config 服务
Run the below docker command to start the  config servers
```
make mongo
docker-compose -f config_server/docker-compose.yaml up -d
```
Once the instances are up, connect to the container using the below command.
```
mongosh mongodb://localhost
```
Now inside the container, we have to pass the instances as members to form a replica set.
```
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
You can check if the replica set status using the below command.
```
rs.status()
```

### Shard servers
Repeat the same process for creating shard-1 and shard-2 docker containers.
```
docker-compose -f shard_server1/docker-compose.yaml up -d
docker-compose -f shard_server2/docker-compose.yaml up -d
```
Login into the containers:
```
mongosh mongodb://localhost
mongosh mongodb://localhost
```
And initiate the replica sets:
#### In shard-1:
```
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

#### In shard-2:
```
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

### Mongo routers
Finally start the mongo routers:
```
docker-compose -f mongos/docker-compose.yaml up -d
```
```
mongosh mongodb://localhost:30000
```
Inside the container, now add both shards to the cluster 
```
sh.addShard("shard1_rs/shard_1_1:27017,shard_1_2:27017,shard_1_3:27017")
sh.addShard("shard2_rs/shard_2_1:27017,shard_2_2:27017,shard_2_3:27017")

```

**Note:** Replace ```192.168.1.83``` with your IPv4 address.


### Sharding the collection
Make sure your application is always connected to mongo routers, it is not suggested to directly connect to shard replica sets.

Connect to mongo router and run this command to create a database.
```
use <database>
```

Starting in MonogDB 6.0 you don't need to run the below command to shard a collection. If you are using earlier versions then it is recommended to run it.
```
sh.enableSharding("<database>")
```

Shard your collection, this command will automatically enable sharding if your using versions Mongo 6.0 or later.
```
sh.shardCollection("<database>.<collection>", { <shard key field> : "hashed" , ... } )
```

You can check the sharding status of a database using ``sh.status()``, and data distribution across shards for a collection using: 
```db.<collection>.getShardDistribution()```


```
db.getSiblingDB("admin").createUser(
  {
    user: "admin",
    pwd: passwordPrompt(),
    roles: [ 
      "userAdminAnyDatabase",
      "dbAdminAnyDatabase",
      "readWriteAnyDatabase"
    ]
  }
)

db.getSiblingDB("admin").updateUser("admin",
  {
    roles: [ 
      "userAdminAnyDatabase",
      "dbAdminAnyDatabase",
      "readWriteAnyDatabase"
    ]
  }
)


use admin
db.auth("admin","admin3edc*IK<")

```