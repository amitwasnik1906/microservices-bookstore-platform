# syntax=docker/dockerfile:1

# ---- Shared builder: compiles the whole multi-module reactor once ----
# BuildKit caches this stage and reuses it for every service target below,
# so Maven runs a single time for the entire `docker compose build`.
FROM maven:3.9-eclipse-temurin-17 AS build
WORKDIR /build
# Cache dependencies first for faster incremental rebuilds.
COPY pom.xml .
COPY backend-user/pom.xml        backend-user/pom.xml
COPY service-batch/pom.xml       service-batch/pom.xml
COPY service-books/pom.xml       service-books/pom.xml
COPY service-config/pom.xml      service-config/pom.xml
COPY service-discovery/pom.xml   service-discovery/pom.xml
COPY service-mails/pom.xml       service-mails/pom.xml
COPY service-prices/pom.xml      service-prices/pom.xml
COPY service-users/pom.xml       service-users/pom.xml
RUN mvn -B -q dependency:go-offline || true
COPY . .
RUN mvn -B clean package -DskipTests

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
