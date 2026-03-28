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

wait_for_rs_ready() {
  local service=$1
  local port=$2

  echo "Waiting for replica set on $service ..."
  until docker compose exec -T "$service" mongosh --port "$port" --quiet --eval "
    try {
      const st = rs.status();
      const hasPrimary = st.members.some(m => m.stateStr === 'PRIMARY');
      const secondaries = st.members.filter(m => m.stateStr === 'SECONDARY').length;
      if (hasPrimary && secondaries >= 2) { print('READY') }
    } catch (e) {}
  " 2>/dev/null | grep -q "READY"; do
    sleep 2
  done
  echo "Replica set on $service is ready"
}

wait_for_mongos() {
  echo "Waiting for mongos ..."
  until docker compose exec -T mongos mongosh --host mongos --port 27017 --quiet --eval "db.adminCommand({ ping: 1 }).ok" >/dev/null 2>&1; do
    sleep 2
  done
  echo "mongos is ready"
}

echo "=== Waiting for MongoDB services ==="
wait_for_mongo configSrv1 27017
wait_for_mongo configSrv2 27017
wait_for_mongo configSrv3 27017
wait_for_mongo shard1-1 27017
wait_for_mongo shard1-2 27017
wait_for_mongo shard1-3 27017
wait_for_mongo shard2-1 27017
wait_for_mongo shard2-2 27017
wait_for_mongo shard2-3 27017

echo "=== Initializing config replica set ==="
docker compose exec -T configSrv1 mongosh --port 27017 --quiet --eval 'try {
  rs.initiate({
    _id: "cfgReplSet",
    configsvr: true,
    members: [
      { _id: 0, host: "configSrv1:27017" },
      { _id: 1, host: "configSrv2:27017" },
      { _id: 2, host: "configSrv3:27017" }
    ]
  })
} catch (e) { print(e) }'

wait_for_rs_ready configSrv1 27017

echo "=== Waiting for mongos after config replica set is ready ==="
wait_for_mongos

echo "=== Initializing shard1 replica set ==="
docker compose exec -T shard1-1 mongosh --port 27017 --quiet --eval 'try {
  rs.initiate({
    _id: "shard1ReplSet",
    members: [
      { _id: 0, host: "shard1-1:27017" },
      { _id: 1, host: "shard1-2:27017" },
      { _id: 2, host: "shard1-3:27017" }
    ]
  })
} catch (e) { print(e) }'

echo "=== Initializing shard2 replica set ==="
docker compose exec -T shard2-1 mongosh --port 27017 --quiet --eval 'try {
  rs.initiate({
    _id: "shard2ReplSet",
    members: [
      { _id: 0, host: "shard2-1:27017" },
      { _id: 1, host: "shard2-2:27017" },
      { _id: 2, host: "shard2-3:27017" }
    ]
  })
} catch (e) { print(e) }'

wait_for_rs_ready shard1-1 27017
wait_for_rs_ready shard2-1 27017

echo "=== Adding shards and enabling sharding ==="
docker compose exec -T mongos mongosh --host mongos --port 27017 --quiet --eval 'try { sh.addShard("shard1ReplSet/shard1-1:27017,shard1-2:27017,shard1-3:27017") } catch (e) { print(e) }
try { sh.addShard("shard2ReplSet/shard2-1:27017,shard2-2:27017,shard2-3:27017") } catch (e) { print(e) }
try { sh.enableSharding("somedb") } catch (e) { print(e) }
db = db.getSiblingDB("somedb")
try { sh.shardCollection("somedb.helloDoc", { name: "hashed" }) } catch (e) { print(e) }
if (db.helloDoc.countDocuments() === 0) {
  for (var i = 0; i < 1000; i++) {
    db.helloDoc.insertOne({ age: i, name: "ly" + i })
  }
}
sh.status()'

echo "=== MongoDB sharding with replication initialization completed ==="