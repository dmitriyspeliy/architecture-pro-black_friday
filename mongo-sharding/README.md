# mongo-sharding

## Описание

В этой версии проекта реализовано шардирование MongoDB.

Используются:
- `pymongo_api`
- `mongos`
- `configSrv`
- `shard1`
- `shard2`

Приложение подключается к MongoDB через `mongos`, а данные коллекции `somedb.helloDoc` распределяются между двумя шардами.

## Запуск проекта

Собрать и запустить контейнеры:

```bash
docker compose up -d --build