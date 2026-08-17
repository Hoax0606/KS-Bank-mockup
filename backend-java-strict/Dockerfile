# ---- build ----
FROM maven:3.9-eclipse-temurin-21 AS build
WORKDIR /app
COPY pom.xml .
RUN mvn -q -B dependency:go-offline
COPY src ./src
RUN mvn -q -B package -DskipTests

# ---- run ----
FROM eclipse-temurin:21-jre
WORKDIR /app
# 온라인(REST) 서버 구동용 fat jar
COPY --from=build /app/target/minibank-backend-strict-0.1.0-SNAPSHOT.jar app.jar
# 배치(10개 독립 프로세스) 구동용 flat classpath — fat jar의 BOOT-INF/lib 구조를
# `java -cp app.jar <FQCN>`으로 직접 못 찾으므로 별도로 풀어둔다.
COPY --from=build /app/target/classes classes
COPY --from=build /app/target/dependency dependency
COPY run_batch.sh run_batch.sh
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]
