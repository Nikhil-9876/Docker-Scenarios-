# Scenario 4: Webapp + DB with Volume (Without Docker Compose)

## Objective
Extend Scenario 3 by attaching a **persistent Docker Volume** (`iris-pgdata-s4`) to the PostgreSQL database container. 

This ensures that even if the database container is deleted, crashed, or updated, all historical predictions remain safely stored in the volume and are restored when a new container mounts it.

---

## Architecture Diagram
```
+------------------------------------------------------------+
| Docker Network: iris-net-s4                                |
|                                                            |
|  +--------------------+        +------------------------+  |
|  | Container:         |        | Container:             |  |
|  | iris-web-s4        | ====>  | iris-db-s4             |  |
|  | (Flask Web Server) |  5432  | (PostgreSQL Database)  |  |
|  +--------------------+        +------------------------+  |
|            |                                |              |
+------------|--------------------------------|--------------+
             | (Port 5004:5000)               v
             v                     [Docker Named Volume]
       Host Browser                   iris-pgdata-s4
                                  (Persistent Storage)
```

---

## Step-by-Step Manual Commands

### 1. Create a Persistent Docker Volume
```powershell
docker volume create iris-pgdata-s4
```

### 2. Create the Docker Network
```powershell
docker network create iris-net-s4
```

### 3. Run the PostgreSQL Container with the Volume Attached
```powershell
docker run -d `
  --name iris-db-s4 `
  --network iris-net-s4 `
  -v iris-pgdata-s4:/var/lib/postgresql/data `
  -e POSTGRES_USER=postgres `
  -e POSTGRES_PASSWORD=postgres `
  -e POSTGRES_DB=iris_db `
  postgres:16-alpine
```

### 4. Build and Run the Web Application Container
```powershell
docker build -t iris-web:s4 .

docker run -d `
  --name iris-web-s4 `
  --network iris-net-s4 `
  -p 5004:5000 `
  -e POSTGRES_HOST=iris-db-s4 `
  -e POSTGRES_PORT=5432 `
  -e POSTGRES_USER=postgres `
  -e POSTGRES_PASSWORD=postgres `
  -e POSTGRES_DB=iris_db `
  iris-web:s4
```
*Access Web UI:* `http://localhost:5004`

### 5. Verify Persistence Test
1. Make a prediction:
   ```powershell
   Invoke-RestMethod -Uri "http://localhost:5004/predict" -Method Post -ContentType "application/json" -Body '{"sepal_length": 6.7, "sepal_width": 3.0, "petal_length": 5.2, "petal_width": 2.3}'
   ```
2. Remove the database container completely:
   ```powershell
   docker rm -f iris-db-s4
   ```
3. Start a new database container using the **same volume**:
   ```powershell
   docker run -d --name iris-db-s4 --network iris-net-s4 -v iris-pgdata-s4:/var/lib/postgresql/data -e POSTGRES_USER=postgres -e POSTGRES_PASSWORD=postgres -e POSTGRES_DB=iris_db postgres:16-alpine
   ```
4. Query the history endpoint:
   ```powershell
   Invoke-RestMethod -Uri "http://localhost:5004/history" -Method Get
   ```
   *Notice the previous record is still intact!*

### 6. Clean Up
```powershell
docker stop iris-web-s4 iris-db-s4
docker rm -f iris-web-s4 iris-db-s4
docker network rm iris-net-s4
docker volume rm iris-pgdata-s4
```

---

## Automated Script
```powershell
.\run.ps1
```
