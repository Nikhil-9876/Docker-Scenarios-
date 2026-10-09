Write-Host "=== Scenario 3: Divide into Webapp + DBApp (Without Docker Compose) ===" -ForegroundColor Cyan

# Cleanup any leftover containers or network
docker stop iris-web-s3 iris-db-s3 2>$null | Out-Null
docker rm -f iris-web-s3 iris-db-s3 2>$null | Out-Null
docker network rm iris-net-s3 2>$null | Out-Null

Write-Host "`n1. Creating bridge network 'iris-net-s3'..." -ForegroundColor Yellow
docker network create iris-net-s3

Write-Host "`n2. Starting PostgreSQL container 'iris-db-s3' (ephemeral, no volume)..." -ForegroundColor Yellow
docker run -d --name iris-db-s3 --network iris-net-s3 `
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
    $status = docker inspect --format "{{json .State.Health.Status}}" iris-db-s3 2>$null
    if ($status -eq '"healthy"') {
        Write-Host "PostgreSQL is healthy!" -ForegroundColor Green
        break
    }
    Start-Sleep -Seconds 1
    $retries++
}

Write-Host "`n3. Building web image 'iris-web:s3'..." -ForegroundColor Yellow
docker build -t iris-web:s3 .

Write-Host "`n4. Starting web container 'iris-web-s3' on port 5003..." -ForegroundColor Yellow
docker run -d --name iris-web-s3 --network iris-net-s3 `
  -p 5003:5000 `
  -e POSTGRES_HOST=iris-db-s3 `
  -e POSTGRES_PORT=5432 `
  -e POSTGRES_USER=postgres `
  -e POSTGRES_PASSWORD=postgres `
  -e POSTGRES_DB=iris_db `
  iris-web:s3

Write-Host "Waiting for web server to start..." -ForegroundColor Yellow
Start-Sleep -Seconds 4

Write-Host "`n5. Testing prediction endpoint (POST /predict)..." -ForegroundColor Yellow
$pred = Invoke-RestMethod -Uri "http://localhost:5003/predict" -Method Post -ContentType "application/json" -Body '{"sepal_length": 5.8, "sepal_width": 2.7, "petal_length": 5.1, "petal_width": 1.9}'
Write-Host "Prediction result: $($pred.prediction)" -ForegroundColor Green

Write-Host "`n6. Testing history endpoint (GET /history)..." -ForegroundColor Yellow
$history = Invoke-RestMethod -Uri "http://localhost:5003/history" -Method Get
Write-Host "Database history records found: $($history.Count)" -ForegroundColor Green
$history | Format-Table -Property id, sepal_length, sepal_width, petal_length, petal_width, prediction, timestamp

Write-Host "`n7. Cleaning up containers and network..." -ForegroundColor Yellow
docker stop iris-web-s3 iris-db-s3
docker rm -f iris-web-s3 iris-db-s3
docker network rm iris-net-s3

Write-Host "`n=== Scenario 3 Test Completed Successfully! ===" -ForegroundColor Green
