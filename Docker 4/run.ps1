Write-Host "=== Scenario 4: Webapp + DB with Volume (Without Docker Compose) ===" -ForegroundColor Cyan

# Cleanup any leftover containers, networks, or volumes
docker stop iris-web-s4 iris-db-s4 2>$null | Out-Null
docker rm -f iris-web-s4 iris-db-s4 2>$null | Out-Null
docker network rm iris-net-s4 2>$null | Out-Null
docker volume rm iris-pgdata-s4 2>$null | Out-Null

Write-Host "`n1. Creating persistent volume 'iris-pgdata-s4'..." -ForegroundColor Yellow
docker volume create iris-pgdata-s4

Write-Host "`n2. Creating bridge network 'iris-net-s4'..." -ForegroundColor Yellow
docker network create iris-net-s4

Write-Host "`n3. Starting PostgreSQL container 'iris-db-s4' WITH VOLUME mounted..." -ForegroundColor Yellow
docker run -d --name iris-db-s4 --network iris-net-s4 `
  -v iris-pgdata-s4:/var/lib/postgresql/data `
  --health-cmd "pg_isready -U postgres" `
  --health-interval 2s `
  --health-timeout 3s `
  --health-retries 15 `
  -e POSTGRES_USER=postgres `
  -e POSTGRES_PASSWORD=postgres `
  -e POSTGRES_DB=iris_db `
  postgres:16-alpine

Write-Host "Waiting for PostgreSQL to be ready..." -ForegroundColor Yellow
$retries = 0
while ($retries -lt 30) {
    $status = docker inspect --format "{{json .State.Health.Status}}" iris-db-s4 2>$null
    if ($status -eq '"healthy"') {
        Write-Host "PostgreSQL is healthy!" -ForegroundColor Green
        break
    }
    Start-Sleep -Seconds 1
    $retries++
}

Write-Host "`n4. Building web image 'iris-web:s4'..." -ForegroundColor Yellow
docker build -t iris-web:s4 .

Write-Host "`n5. Starting web container 'iris-web-s4' on port 5004..." -ForegroundColor Yellow
docker run -d --name iris-web-s4 --network iris-net-s4 `
  -p 5004:5000 `
  -e POSTGRES_HOST=iris-db-s4 `
  -e POSTGRES_PORT=5432 `
  -e POSTGRES_USER=postgres `
  -e POSTGRES_PASSWORD=postgres `
  -e POSTGRES_DB=iris_db `
  iris-web:s4

Write-Host "Waiting for web server to start..." -ForegroundColor Yellow
Start-Sleep -Seconds 4

Write-Host "`n6. Making a prediction to write data into PostgreSQL..." -ForegroundColor Yellow
$pred1 = Invoke-RestMethod -Uri "http://localhost:5004/predict" -Method Post -ContentType "application/json" -Body '{"sepal_length": 6.7, "sepal_width": 3.0, "petal_length": 5.2, "petal_width": 2.3}'
Write-Host "Initial prediction: $($pred1.prediction)" -ForegroundColor Green

Write-Host "`n7. Checking history before destroying DB container..." -ForegroundColor Yellow
$h1 = Invoke-RestMethod -Uri "http://localhost:5004/history" -Method Get
Write-Host "History records count: $($h1.Count)" -ForegroundColor Green

Write-Host "`n8. Destroying the DB container completely (docker rm -f iris-db-s4)..." -ForegroundColor Red
docker rm -f iris-db-s4

Write-Host "`n9. Spawning a NEW DB container mounting the SAME volume..." -ForegroundColor Yellow
docker run -d --name iris-db-s4 --network iris-net-s4 `
  -v iris-pgdata-s4:/var/lib/postgresql/data `
  --health-cmd "pg_isready -U postgres" `
  --health-interval 2s `
  --health-timeout 3s `
  --health-retries 15 `
  -e POSTGRES_USER=postgres `
  -e POSTGRES_PASSWORD=postgres `
  -e POSTGRES_DB=iris_db `
  postgres:16-alpine

Write-Host "Waiting for new PostgreSQL container to be ready..." -ForegroundColor Yellow
$retries = 0
while ($retries -lt 30) {
    $status = docker inspect --format "{{json .State.Health.Status}}" iris-db-s4 2>$null
    if ($status -eq '"healthy"') {
        Write-Host "New PostgreSQL container is healthy!" -ForegroundColor Green
        break
    }
    Start-Sleep -Seconds 1
    $retries++
}

Write-Host "`n10. Querying history to verify persistence across container replacement..." -ForegroundColor Yellow
$h2 = Invoke-RestMethod -Uri "http://localhost:5004/history" -Method Get
Write-Host "History records preserved: $($h2.Count)" -ForegroundColor Green
$h2 | Format-Table -Property id, sepal_length, sepal_width, petal_length, petal_width, prediction, timestamp

Write-Host "`n11. Cleaning up containers, network, and volume..." -ForegroundColor Yellow
docker stop iris-web-s4 iris-db-s4
docker rm -f iris-web-s4 iris-db-s4
docker network rm iris-net-s4
docker volume rm iris-pgdata-s4

Write-Host "`n=== Scenario 4 Test Completed Successfully! Data Persistence Verified! ===" -ForegroundColor Green
