#!/bin/bash

set -e

wait_for_mongo() {
  local service=$1
  local port=$2

  echo "Waiting for $service:$port ..."
  until docker compose exec -T "$service" mongosh --port "$port" --quiet --eval "db.adminCommand({ ping: 1 }).ok" >/dev/null 2>&1; do
    sleep 2
  done
  echo "$service:$port is ready"
}

wait_for_rs_primary() {
  local service=$1
  local port=$2

  echo "Waiting for PRIMARY on $service ..."
  until docker compose exec -T "$service" mongosh --port "$port" --quiet --eval "rs.status().myState" 2>/dev/null | grep -q "1"; do
    sleep 2
  done
  echo "$service is PRIMARY"
}

wait_for_mongos() {
  echo "Waiting for mongos ..."
  until docker compose exec -T mongos mongosh --host mongos --port 27017 --quiet --eval "db.adminCommand({ ping: 1 }).ok" >/dev/null 2>&1; do
    sleep 2
  done
  echo "mongos is ready"
}

echo "=== Waiting for MongoDB services ==="
wait_for_mongo configSrv 27017
wait_for_mongo shard1 27017
wait_for_mongo shard2 27017

echo "=== Initializing config replica set ==="
docker compose exec -T configSrv mongosh --port 27017 --quiet --eval 'try {
  rs.initiate({
    _id: "cfgReplSet",
    configsvr: true,
    members: [
      { _id: 0, host: "configSrv:27017" }
    ]
  })
} catch (e) { print(e) }'

wait_for_rs_primary configSrv 27017
wait_for_mongos

echo "=== Initializing shard1 replica set ==="
docker compose exec -T shard1 mongosh --port 27017 --quiet --eval 'try {
  rs.initiate({
    _id: "shard1ReplSet",
    members: [
      { _id: 0, host: "shard1:27017" }
    ]
  })
} catch (e) { print(e) }'

echo "=== Initializing shard2 replica set ==="
docker compose exec -T shard2 mongosh --port 27017 --quiet --eval 'try {
  rs.initiate({
    _id: "shard2ReplSet",
    members: [
      { _id: 0, host: "shard2:27017" }
    ]
  })
} catch (e) { print(e) }'

wait_for_rs_primary shard1 27017
wait_for_rs_primary shard2 27017

echo "=== Adding shards and enabling sharding ==="
docker compose exec -T mongos mongosh --host mongos --port 27017 --quiet --eval 'try { sh.addShard("shard1ReplSet/shard1:27017") } catch (e) { print(e) }
try { sh.addShard("shard2ReplSet/shard2:27017") } catch (e) { print(e) }
try { sh.enableSharding("somedb") } catch (e) { print(e) }
db = db.getSiblingDB("somedb")
try { sh.shardCollection("somedb.helloDoc", { name: "hashed" }) } catch (e) { print(e) }
if (db.helloDoc.countDocuments() === 0) {
  for (var i = 0; i < 1000; i++) {
    db.helloDoc.insertOne({ age: i, name: "ly" + i })
  }
}
sh.status()'

echo "=== MongoDB sharding initialization completed ==="