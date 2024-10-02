#!/bin/bash

###
# Инициализируем MongoDB Config Server
###

docker compose exec -T mongo-config-server mongosh --port 27017 --quiet <<EOF
rs.initiate(
  {
    _id : "mongo-config-server",
       configsvr: true,
    members: [
      { _id : 0, host : "mongo-config-server:27017" }
    ]
  }
);
EOF

###
# Инициализируем MongoDB Shard 1
###

docker compose exec -T mongo-shard-1 mongosh --port 27019 --quiet <<EOF
rs.initiate(
  {
    _id : "mongo-shard-1",
    members: [
      { _id : 0, host : "mongo-shard-1:27019", priority:100 },
      { _id : 1, host : "mongo-shard-1-slave-1:27020", priority: 1 },
      { _id : 2, host : "mongo-shard-1-slave-2:27021", priority: 1 }
    ]
  }
);
EOF

###
# Инициализируем MongoDB Shard 2
###

docker compose exec -T mongo-shard-2 mongosh --port 27022 --quiet <<EOF
rs.initiate(
  {
    _id : "mongo-shard-2",
    members: [
      { _id : 0, host : "mongo-shard-2:27022", priority:100 },
      { _id : 1, host : "mongo-shard-2-slave-1:27023", priority:1 },
      { _id : 2, host : "mongo-shard-2-slave-2:27024", priority:1 }
    ]
  }
);
EOF

###
# Инициализируем MongoDB Router
###

docker compose exec -T mongo-router mongosh --port 27018 --quiet <<EOF

sh.addShard( "mongo-shard-1/mongo-shard-1:27019,mongo-shard-1-slave-1:27020,mongo-shard-1-slave-2:27021");
sh.addShard( "mongo-shard-2/mongo-shard-2:27022,mongo-shard-2-slave-1:27023,mongo-shard-2-slave-2:27024");

sh.enableSharding("somedb");
sh.shardCollection("somedb.helloDoc", { "name" : "hashed" } )

EOF

###
# Генерируем тестовые данные в MongoDB
###

docker compose exec -T mongo-router mongosh --port 27018 --quiet <<EOF

use somedb;

for(var i = 0; i < 1000; i++) db.helloDoc.insertOne({age:i, name:"doc-"+i});
db.helloDoc.countDocuments();

EOF

###
# Проверяем документы на MongoDB Shard 1
###

docker compose exec -T mongo-shard-1 mongosh --port 27019 --quiet <<EOF

use somedb;
db.helloDoc.countDocuments();

EOF

###
# Проверяем документы на MongoDB Shard 2
###

docker compose exec -T mongo-shard-1 mongosh --port 27020 --quiet <<EOF

use somedb;
db.helloDoc.countDocuments();

EOF