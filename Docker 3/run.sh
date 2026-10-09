#!/bin/bash
set -e

echo "=== Scenario 3: Webapp + DB Containers (No Compose, No Volume) ==="

# Cleanup any leftover containers or network
echo -e "\nCleaning up any previous run..."
docker stop iris-web-s3 iris-db-s3 2>/dev/null || true
docker rm -f iris-web-s3 iris-db-s3 2>/dev/null || true
docker network rm iris-net-s3 2>/dev/null || true

# 1. Create bridge network
echo -e "\n1. Creating bridge network 'iris-net-s3'..."
docker network create iris-net-s3

# 2. Run Postgres container (no volume = ephemeral)
echo -e "\n2. Starting PostgreSQL container 'iris-db-s3' (ephemeral, no volume)..."
docker run -d \
  --name iris-db-s3 \
  --network iris-net-s3 \
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
  STATUS=$(docker inspect --format "{{json .State.Health.Status}}" iris-db-s3 2>/dev/null || echo "null")
  if [ "$STATUS" = '"healthy"' ]; then
    echo "PostgreSQL is healthy!"
    break
  fi
  sleep 1
done

# 3. Build web image
echo -e "\n3. Building web image 'iris-web:s3'..."
docker build -t iris-web:s3 .

# 4. Run web container
echo -e "\n4. Starting web container 'iris-web-s3' on port 5003..."
docker run -d \
  --name iris-web-s3 \
  --network iris-net-s3 \
  -p 5003:5000 \
  -e POSTGRES_HOST=iris-db-s3 \
  -e POSTGRES_PORT=5432 \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_PASSWORD=postgres \
  -e POSTGRES_DB=iris_db \
  iris-web:s3

sleep 3

# 5. Test prediction endpoint
echo -e "\n5. Testing prediction endpoint (POST /predict)..."
curl -s -X POST http://localhost:5003/predict \
  -H "Content-Type: application/json" \
  -d '{"sepal_length": 5.8, "sepal_width": 2.7, "petal_length": 5.1, "petal_width": 1.9}' | python3 -m json.tool

# 6. Test history endpoint
echo -e "\n6. Testing history endpoint (GET /history)..."
curl -s http://localhost:5003/history | python3 -m json.tool

echo -e "\n=== App running at http://localhost:5003 ==="
echo "Run the following to clean up when done:"
echo "  docker stop iris-web-s3 iris-db-s3 && docker rm iris-web-s3 iris-db-s3 && docker network rm iris-net-s3"
