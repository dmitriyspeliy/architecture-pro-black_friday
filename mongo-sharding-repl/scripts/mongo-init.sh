#!/bin/bash

set -e

echo "Waiting for MongoDB containers to start..."
sleep 15

echo "Initializing config server replica set..."
docker compose exec -T configSrv1 mongosh --eval '
rs.initiate({
  _id: "cfgReplSet",
  configsvr: true,
  members: [
    { _id: 0, host: "configSrv1:27017" },
    { _id: 1, host: "configSrv2:27017" },
    { _id: 2, host: "configSrv3:27017" }
  ]
})
'

echo "Waiting for config replica set..."
sleep 10

echo "Initializing shard1 replica set..."
docker compose exec -T shard1-1 mongosh --eval '
rs.initiate({
  _id: "shard1ReplSet",
  members: [
    { _id: 0, host: "shard1-1:27017" },
    { _id: 1, host: "shard1-2:27017" },
    { _id: 2, host: "shard1-3:27017" }
  ]
})
'

echo "Initializing shard2 replica set..."
docker compose exec -T shard2-1 mongosh --eval '
rs.initiate({
  _id: "shard2ReplSet",
  members: [
    { _id: 0, host: "shard2-1:27017" },
    { _id: 1, host: "shard2-2:27017" },
    { _id: 2, host: "shard2-3:27017" }
  ]
})
'

echo "Waiting for shard replica sets..."
sleep 15

echo "Adding shards to mongos..."
docker compose exec -T mongos mongosh --eval '
sh.addShard("shard1ReplSet/shard1-1:27017,shard1-2:27017,shard1-3:27017");
sh.addShard("shard2ReplSet/shard2-1:27017,shard2-2:27017,shard2-3:27017");
'

echo "Enabling sharding for database and collection..."
docker compose exec -T mongos mongosh --eval '
sh.enableSharding("somedb");
db = db.getSiblingDB("somedb");
sh.shardCollection("somedb.helloDoc", { name: "hashed" });
'

echo "Filling database with test data..."
docker compose exec -T mongos mongosh <<EOF
use somedb
for (var i = 0; i < 1000; i++) {
  db.helloDoc.insertOne({ age: i, name: "ly" + i })
}
EOF

echo "MongoDB cluster initialization completed."