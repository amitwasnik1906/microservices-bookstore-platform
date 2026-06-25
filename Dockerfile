# syntax=docker/dockerfile:1

# ---- Shared builder: compiles the whole multi-module reactor once ----
# BuildKit caches this stage and reuses it for every service target below,
# so Maven runs a single time for the entire `docker compose build`.
FROM maven:3.9-eclipse-temurin-17 AS build
WORKDIR /build
COPY . .
# A BuildKit cache mount keeps the Maven repo (~/.m2) between builds, so dependencies are
# downloaded once and reused — later builds only recompile. No -q, so progress is visible.
RUN --mount=type=cache,target=/root/.m2 mvn -B clean package -DskipTests

# ---- Per-service runtime stages (Java 17 JRE) ----
FROM eclipse-temurin:17-jre AS service-discovery
COPY --from=build /build/service-discovery/target/*.jar /app.jar
ENTRYPOINT ["java", "-jar", "/app.jar"]

FROM eclipse-temurin:17-jre AS service-config
COPY --from=build /build/service-config/target/*.jar /app.jar
ENTRYPOINT ["java", "-jar", "/app.jar"]

FROM eclipse-temurin:17-jre AS backend-user
COPY --from=build /build/backend-user/target/*.jar /app.jar
ENTRYPOINT ["java", "-jar", "/app.jar"]

FROM eclipse-temurin:17-jre AS service-books
COPY --from=build /build/service-books/target/*.jar /app.jar
ENTRYPOINT ["java", "-jar", "/app.jar"]

FROM eclipse-temurin:17-jre AS service-prices
COPY --from=build /build/service-prices/target/*.jar /app.jar
ENTRYPOINT ["java", "-jar", "/app.jar"]

FROM eclipse-temurin:17-jre AS service-users
COPY --from=build /build/service-users/target/*.jar /app.jar
ENTRYPOINT ["java", "-jar", "/app.jar"]

FROM eclipse-temurin:17-jre AS service-mails
COPY --from=build /build/service-mails/target/*.jar /app.jar
ENTRYPOINT ["java", "-jar", "/app.jar"]

FROM eclipse-temurin:17-jre AS service-batch
COPY --from=build /build/service-batch/target/*.jar /app.jar
ENTRYPOINT ["java", "-jar", "/app.jar"]
