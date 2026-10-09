Write-Host "=== Scenario 2: Dockerize Webapp with Embedded Database ===" -ForegroundColor Cyan

Write-Host "`n1. Building Docker image 'iris-webapp-db:s2'..." -ForegroundColor Yellow
docker build -t iris-webapp-db:s2 .

Write-Host "`n2. Starting container 'iris-webapp-db-s2' on port 5002..." -ForegroundColor Yellow
docker run -d --name iris-webapp-db-s2 -p 5002:5000 iris-webapp-db:s2

Write-Host "`nWaiting for web server to start..." -ForegroundColor Yellow
Start-Sleep -Seconds 3

Write-Host "`n3. Testing prediction endpoint (POST /predict)..." -ForegroundColor Yellow
$pred = Invoke-RestMethod -Uri "http://localhost:5002/predict" -Method Post -ContentType "application/json" -Body '{"sepal_length": 6.2, "sepal_width": 2.8, "petal_length": 4.8, "petal_width": 1.8}'
Write-Host "Prediction result: $($pred.prediction)" -ForegroundColor Green

Write-Host "`n4. Testing history endpoint (GET /history)..." -ForegroundColor Yellow
$history = Invoke-RestMethod -Uri "http://localhost:5002/history" -Method Get
Write-Host "Database history records found: $($history.Count)" -ForegroundColor Green
$history | Format-Table -Property id, sepal_length, sepal_width, petal_length, petal_width, prediction, timestamp

Write-Host "`n5. Cleaning up container..." -ForegroundColor Yellow
docker stop iris-webapp-db-s2
docker rm iris-webapp-db-s2

Write-Host "`n=== Scenario 2 Test Completed Successfully! ===" -ForegroundColor Green
