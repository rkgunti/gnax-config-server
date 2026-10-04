FROM mcr.microsoft.com/openjdk/jdk:17-ubuntu AS build
WORKDIR /workspace

COPY .mvn .mvn
COPY mvnw pom.xml ./
RUN ./mvnw -B -q dependency:go-offline

COPY src src
RUN ./mvnw -B -q clean package -DskipTests

FROM mcr.microsoft.com/openjdk/jdk:17-ubuntu
WORKDIR /app

RUN groupadd --system gnax && useradd --system --gid gnax gnax
USER gnax

COPY --from=build /workspace/target/gnax-config-server-0.0.1-SNAPSHOT.jar /app/app.jar

ARG APP_PORT=8080
EXPOSE ${APP_PORT}

ENTRYPOINT ["java", "-jar", "/app/app.jar"]