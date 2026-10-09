#!/bin/bash
set -e

echo "=== Scenario 4: Webapp + DB with Volume (No Compose) ==="

# Cleanup any leftover containers, networks, or volumes
echo -e "\nCleaning up any previous run..."
docker stop iris-web-s4 iris-db-s4 2>/dev/null || true
docker rm -f iris-web-s4 iris-db-s4 2>/dev/null || true
docker network rm iris-net-s4 2>/dev/null || true
docker volume rm iris-pgdata-s4 2>/dev/null || true

# 1. Create persistent volume
echo -e "\n1. Creating persistent volume 'iris-pgdata-s4'..."
docker volume create iris-pgdata-s4

# 2. Create bridge network
echo -e "\n2. Creating bridge network 'iris-net-s4'..."
docker network create iris-net-s4

# 3. Run Postgres WITH volume mounted
echo -e "\n3. Starting PostgreSQL container 'iris-db-s4' WITH VOLUME mounted..."
docker run -d \
  --name iris-db-s4 \
  --network iris-net-s4 \
  -v iris-pgdata-s4:/var/lib/postgresql/data \
  --health-cmd "pg_isready -U postgres" \
  --health-interval 2s \
  --health-timeout 3s \
  --health-retries 15 \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_PASSWORD=postgres \
  -e POSTGRES_DB=iris_db \
  postgres:16

# Wait for Postgres to be healthy
echo "Waiting for PostgreSQL to be ready..."
for i in $(seq 1 30); do
  STATUS=$(docker inspect --format "{{json .State.Health.Status}}" iris-db-s4 2>/dev/null || echo "null")
  if [ "$STATUS" = '"healthy"' ]; then
    echo "PostgreSQL is healthy!"
    break
  fi
  sleep 1
done

# 4. Build & run web container
echo -e "\n4. Building web image 'iris-web:s4'..."
docker build -t iris-web:s4 .

echo -e "\n5. Starting web container 'iris-web-s4' on port 5004..."
docker run -d \
  --name iris-web-s4 \
  --network iris-net-s4 \
  -p 5004:5000 \
  -e POSTGRES_HOST=iris-db-s4 \
  -e POSTGRES_PORT=5432 \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_PASSWORD=postgres \
  -e POSTGRES_DB=iris_db \
  iris-web:s4

sleep 3

# 6. Make a prediction (writes to DB)
echo -e "\n6. Making a prediction to write data into PostgreSQL..."
curl -s -X POST http://localhost:5004/predict \
  -H "Content-Type: application/json" \
  -d '{"sepal_length": 6.7, "sepal_width": 3.0, "petal_length": 5.2, "petal_width": 2.3}' | python3 -m json.tool

# 7. Check history before destroying DB
echo -e "\n7. History BEFORE destroying DB container:"
curl -s http://localhost:5004/history | python3 -m json.tool

# 8. Destroy the DB container completely
echo -e "\n8. Destroying the DB container (docker rm -f iris-db-s4)..."
docker rm -f iris-db-s4

# 9. Spawn a NEW DB container with the SAME volume
echo -e "\n9. Spawning a NEW DB container mounting the SAME volume..."
docker run -d \
  --name iris-db-s4 \
  --network iris-net-s4 \
  -v iris-pgdata-s4:/var/lib/postgresql/data \
  --health-cmd "pg_isready -U postgres" \
  --health-interval 2s \
  --health-timeout 3s \
  --health-retries 15 \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_PASSWORD=postgres \
  -e POSTGRES_DB=iris_db \
  postgres:16

echo "Waiting for new PostgreSQL container to be ready..."
for i in $(seq 1 30); do
  STATUS=$(docker inspect --format "{{json .State.Health.Status}}" iris-db-s4 2>/dev/null || echo "null")
  if [ "$STATUS" = '"healthy"' ]; then
    echo "New PostgreSQL container is healthy!"
    break
  fi
  sleep 1
done

# 10. Verify data persisted across container replacement
echo -e "\n10. History AFTER replacing DB container (should still have data!):"
curl -s http://localhost:5004/history | python3 -m json.tool

echo -e "\n=== App running at http://localhost:5004 ==="
echo "To clean up when done:"
echo "  docker stop iris-web-s4 iris-db-s4 && docker rm -f iris-web-s4 iris-db-s4 && docker network rm iris-net-s4 && docker volume rm iris-pgdata-s4"
