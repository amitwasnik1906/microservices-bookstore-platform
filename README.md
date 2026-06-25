# Bookstore — Microservices Application

A bookstore back end built with **Spring Boot** and **Spring Cloud** (Eureka service
discovery, Spring Cloud Config, Spring Cloud Gateway, OpenFeign, Resilience4j, Kafka,
Sleuth/Zipkin tracing). The whole stack runs with a single `docker compose` command.

---

## Architecture

| Service | Role | Port |
|---|---|---|
| `service-discovery` | Eureka registry — every service registers here | 8761 |
| `service-config` | Spring Cloud Config server (serves config from `classpath:/config`) | 8888 |
| `backend-user` | **API Gateway** — the public entry point; routes & authenticates requests | 8081 |
| `service-books` | Books REST API (calls `service-prices` via Feign) | dynamic* |
| `service-prices` | Prices REST API | dynamic* |
| `service-users` | Users / auth (sign up, sign in, token validation); publishes welcome emails to Kafka | dynamic* |
| `service-mails` | Consumes Kafka messages and sends emails | dynamic* |
| `service-batch` | Spring Batch jobs | dynamic* |

\* These register with Eureka on a random port and are reached **through the gateway**, never directly.

**Infrastructure:** PostgreSQL (database), Apache Kafka (messaging), Zipkin (distributed tracing).

---

## Prerequisites

- **Docker Desktop** (with Docker Compose v2). That's it — the images build Java/Maven inside
  Docker, so you do **not** need a local JDK or Maven.

---

## Run it

From the project root:

```bash
# 1) Build the images. Build sequentially the first time to avoid a known BuildKit
#    parallel-export race ("image already exists") with Docker Desktop's image store:
for s in service-discovery service-config backend-user service-books \
         service-prices service-users service-mails service-batch; do
  docker compose build "$s"
done

# 2) Start the whole stack
docker compose up -d
```

On **Windows PowerShell**, use this for step 1:
```powershell
foreach ($s in 'service-discovery','service-config','backend-user','service-books',
               'service-prices','service-users','service-mails','service-batch') {
  docker compose build $s
}
docker compose up -d
```

Compose starts everything in the correct order automatically (Postgres / Kafka / Zipkin →
Eureka → Config server → application services), gated by health checks.

> The first build downloads base images and Maven dependencies and may take several minutes.
> After that, `docker compose up -d` alone is enough (re-add a `docker compose build <svc>`
> only for services whose code you changed).

### Stopping
```bash
docker compose down        # stop and remove containers
docker compose down -v     # also wipe the Postgres data volume
```

---

## Access points

| What | URL |
|---|---|
| **API Gateway** (use this for the app) | http://localhost:8081 |
| Eureka dashboard (see registered services) | http://localhost:8761 |
| Zipkin tracing UI | http://localhost:9412 |
| PostgreSQL (from host) | `localhost:5433` (db `bookstore`, user `ser` / `ser`) |

> Postgres and Zipkin are published on **5433** and **9412** (instead of the usual 5432 / 9411)
> so they don't clash with any local Postgres/Zipkin you may already run. Inside the Docker
> network the services still use the standard ports.

---

## Try the API

All requests go through the gateway on port **8081**. The `service-books` route is protected,
so the flow is **sign up → sign in → use the returned token**.

```bash
# 1) Create a user
curl -X POST http://localhost:8081/users/signUp \
  -H "Content-Type: application/json" \
  -d '{"login":"alice","password":"secret123","birthDate":"1990-01-01"}'

# 2) Sign in -> response contains a token
curl -X POST http://localhost:8081/users/signIn \
  -H "Content-Type: application/json" \
  -d '{"login":"alice","password":"secret123"}'

# 3) Call a protected endpoint with the token from step 2
curl http://localhost:8081/books/1 \
  -H "Authorization: Bearer <token-from-step-2>"
```

Quick health checks (no auth needed):
```bash
docker compose ps                                  # all containers Up/healthy
curl http://localhost:8081/actuator/gateway/routes # gateway sees the services
```

Follow logs while testing:
```bash
docker compose logs -f backend-user service-users service-books
```

---

## Configuration

Configuration is centralized in the **config server**, which serves the per-service YAML files
under `service-config/src/main/resources/config/`. Each service only carries a small
`bootstrap.yml` pointing at the config server.

Hostnames in the config use `${VAR:localhost}` placeholders (e.g. `${DB_HOST:localhost}`), so:
- under Docker, Compose injects the container hostnames (`postgres`, `kafka`, `service-discovery`, …);
- running a service directly with `mvn spring-boot:run` falls back to `localhost`.

---

## Running a single service without Docker (optional)

You need JDK 17 + Maven and the infrastructure (Postgres, Kafka, Zipkin) reachable on
`localhost`. Start `service-discovery` first, then `service-config`, then the service you want:

```bash
mvn -pl service-discovery spring-boot:run
mvn -pl service-config    spring-boot:run
mvn -pl service-books     spring-boot:run
```

---

## Known issue

- **`service-mails` does not start.** It fails with
  `UnsupportedOperationException: Implementations of KafkaClientSupplier should implement the getAdmin() method` —
  a version mismatch between the old Spring Cloud Stream Kafka Streams binder (Spring Cloud
  `2021.0.0`) and the Kafka Streams client. This is independent of the Docker setup. The other
  five application services and the gateway run normally; only the email-consumer is affected.
  Fixing it requires bumping the Spring Cloud / Kafka Streams versions in `service-mails`.
