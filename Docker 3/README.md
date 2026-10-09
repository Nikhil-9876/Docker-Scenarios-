# Scenario 3: Divide into Webapp + DBApp (Without Docker Compose)

## Objective
Split the unified application into **two separate, communicating Docker containers**:
1. **`iris-db-s3`**: An official PostgreSQL container.
2. **`iris-web-s3`**: A custom Flask web application container.

**Key Requirements:**
- **No Docker Compose** (use native `docker run` commands).
- **No Docker Volume** (database filesystem is ephemeral).
- **Docker Bridge Network** (`iris-net-s3`) is used so containers discover and communicate with each other using container DNS names.

---

## Architecture Diagram
```
+------------------------------------------------------------+
| Docker Network: iris-net-s3                                |
|                                                            |
|  +--------------------+        +------------------------+  |
|  | Container:         |        | Container:             |  |
|  | iris-web-s3        | ====>  | iris-db-s3             |  |
|  | (Flask Web Server) |  5432  | (PostgreSQL Database)  |  |
|  +--------------------+        +------------------------+  |
|            |                                               |
+------------|-----------------------------------------------+
             | (Port 5003:5000)
             v
       Host Browser
```

---

## Step-by-Step Manual Commands

### 1. Create a Custom Docker Bridge Network
```powershell
docker network create iris-net-s3
```

### 2. Run the PostgreSQL Database Container (Without Volume)
```powershell
docker run -d `
  --name iris-db-s3 `
  --network iris-net-s3 `
  -e POSTGRES_USER=postgres `
  -e POSTGRES_PASSWORD=postgres `
  -e POSTGRES_DB=iris_db `
  postgres:16-alpine
```

### 3. Build the Flask Web Application Image
```powershell
docker build -t iris-web:s3 .
```

### 4. Run the Flask Web Container
```powershell
docker run -d `
  --name iris-web-s3 `
  --network iris-net-s3 `
  -p 5003:5000 `
  -e POSTGRES_HOST=iris-db-s3 `
  -e POSTGRES_PORT=5432 `
  -e POSTGRES_USER=postgres `
  -e POSTGRES_PASSWORD=postgres `
  -e POSTGRES_DB=iris_db `
  iris-web:s3
```
*Access Web UI:* `http://localhost:5003`

### 5. Test Endpoints
```powershell
# Send prediction request
Invoke-RestMethod -Uri "http://localhost:5003/predict" -Method Post -ContentType "application/json" -Body '{"sepal_length": 5.8, "sepal_width": 2.7, "petal_length": 5.1, "petal_width": 1.9}'

# Check prediction history in PostgreSQL
Invoke-RestMethod -Uri "http://localhost:5003/history" -Method Get
```

### 6. Clean Up Containers and Network
```powershell
docker stop iris-web-s3 iris-db-s3
docker rm iris-web-s3 iris-db-s3
docker network rm iris-net-s3
```

---

## Automated Script
Run the automated test script:
```powershell
.\run.ps1
```
