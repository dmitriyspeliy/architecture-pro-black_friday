# mongo-sharding-repl

## Описание

В этой версии проекта реализованы:
- шардирование MongoDB;
- репликация каждого шарда.

Используются:
- `pymongo_api`
- `mongos`
- `configSrv1`, `configSrv2`, `configSrv3`
- `shard1-1`, `shard1-2`, `shard1-3`
- `shard2-1`, `shard2-2`, `shard2-3`

Приложение подключается к MongoDB через `mongos`.  
Каждый шард реализован как Replica Set из трёх узлов.

## Запуск проекта

Собрать и запустить контейнеры:

```bash
docker compose up -d --build