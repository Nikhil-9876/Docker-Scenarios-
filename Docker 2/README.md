# Scenario 2: Dockerized Flask Webapp with PostgreSQL Database

## Objective
Dockerize an ML prediction web app (Iris dataset) connected to a persistent **PostgreSQL** database managed via **Docker Compose**. Predictions made via the ML model are automatically stored in PostgreSQL.

---

## Architecture

- **Web Service (`web`)**: Flask REST API & HTML UI served by Gunicorn WSGI server.
- **Database Service (`db`)**: PostgreSQL 15 database container.
- **Persistence**: Named Docker volume `postgres_data` ensures database data persists across restarts.
- **Orchestration**: `docker-compose.yml` links the web app and database with automated healthchecks (`pg_isready`).

---

## Guide & Instructions

### 1. Start Web App & PostgreSQL Services
Run from the `Docker 2` directory:
```bash
docker compose up --build -d
```

### 2. Verify Running Containers
```bash
docker compose ps
```
Both `docker2-web-1` (port `5000`) and `docker2-db-1` (port `5432`) should show `Up` and `healthy`.

### 3. Test API Endpoints

#### Make a Prediction (`POST /predict`):
```bash
curl -X POST http://localhost:5000/predict \
  -H "Content-Type: application/json" \
  -d '{"sepal_length": 6.2, "sepal_width": 2.8, "petal_length": 4.8, "petal_width": 1.8}'
```
*Response:* `{"prediction":"Virginica"}`

#### Fetch Prediction History (`GET /history`):
```bash
curl http://localhost:5000/history
```

### 4. Inspect Data Inside PostgreSQL Direct CLI (`psql`)
You can query the database directly inside the container:
```bash
docker compose exec db psql -U postgres -d iris_db -c "SELECT * FROM prediction_history;"
```

### 5. Check Container Logs
```bash
docker compose logs -f
```

### 6. Stop and Clean Up
```bash
# Stop containers but keep database volume
docker compose down

# Stop containers AND delete persistent database data volume
docker compose down -v
```

