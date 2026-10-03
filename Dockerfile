FROM mcr.microsoft.com/openjdk/jdk:17-ubuntu AS build
WORKDIR /workspace

COPY .mvn .mvn
COPY mvnw pom.xml ./
RUN ./mvnw -B -q dependency:go-offline

COPY src src
RUN ./mvnw -B -q clean package -DskipTests \
    && java -Djarmode=tools -jar target/*.jar extract --layers --destination target/extracted

FROM mcr.microsoft.com/openjdk/jdk:17-ubuntu
WORKDIR /app

RUN groupadd --system gnax && useradd --system --gid gnax gnax
USER gnax

COPY --from=build /workspace/target/extracted/dependencies/ ./
COPY --from=build /workspace/target/extracted/spring-boot-loader/ ./
COPY --from=build /workspace/target/extracted/snapshot-dependencies/ ./
COPY --from=build /workspace/target/extracted/application/ ./

EXPOSE 8888

# CONFIG_SERVER_USERNAME, CONFIG_SERVER_PASSWORD and CONFIG_GIT_URI must be provided at runtime
ENTRYPOINT ["java", "-jar", "gnax-config-server-0.0.1-SNAPSHOT.jar"]
