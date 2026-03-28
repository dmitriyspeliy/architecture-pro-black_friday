#!/bin/bash

set -e

echo "Waiting for MongoDB services to start..."
sleep 20

echo "Initializing config server replica set..."
docker compose exec -T configSrv mongosh --port 27017 --quiet <<EOF
rs.initiate({
  _id: "cfgReplSet",
  configsvr: true,
  members: [
    { _id: 0, host: "configSrv:27017" }
  ]
})
EOF

echo "Initializing shard1 replica set..."
docker compose exec -T shard1 mongosh --port 27017 --quiet <<EOF
rs.initiate({
  _id: "shard1ReplSet",
  members: [
    { _id: 0, host: "shard1:27017" }
  ]
})
EOF

echo "Initializing shard2 replica set..."
docker compose exec -T shard2 mongosh --port 27017 --quiet <<EOF
rs.initiate({
  _id: "shard2ReplSet",
  members: [
    { _id: 0, host: "shard2:27017" }
  ]
})
EOF

echo "Waiting for replica sets..."
sleep 15

echo "Adding shards to mongos..."
docker compose exec -T mongos mongosh --port 27017 --quiet <<EOF
sh.addShard("shard1ReplSet/shard1:27017")
sh.addShard("shard2ReplSet/shard2:27017")
sh.enableSharding("somedb")
sh.shardCollection("somedb.helloDoc", { name: "hashed" })
EOF

echo "Filling database with test data..."
docker compose exec -T mongos mongosh --port 27017 --quiet <<EOF
use somedb
for (var i = 0; i < 1000; i++) {
  db.helloDoc.insertOne({ age: i, name: "ly" + i })
}
EOF

echo "Done."