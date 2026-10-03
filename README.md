# gnax-config-server

Centralized configuration service for GnaX and its applications, built on Spring Cloud Config Server. It serves environment-specific, externalized configuration from a Git repository.

## Tech stack

- Java 17 (Microsoft OpenJDK)
- Spring Boot 4.1.1, Spring Cloud 2025.1.3
- Spring Cloud Config Server, Spring Security, Actuator
- Maven (wrapper included)

## Project structure

```
.
├── Dockerfile                  # Multi-stage image build
├── pom.xml
├── src/main/java/com/gnax/config/server/GnaxConfigServerApplication.java
├── src/main/resources/application.yaml
└── src/test/java/...
```

## Configuration

The server reads these environment variables (no defaults, all required):

| Variable | Description |
|---|---|
| `CONFIG_SERVER_USERNAME` | Basic-auth username clients use to access the server |
| `CONFIG_SERVER_PASSWORD` | Basic-auth password |
| `CONFIG_GIT_URI` | Git repository holding the configuration files (cloned on start, branch `main`) |

The server listens on port `8888`. Actuator exposes `health`, `info` and `metrics`, with liveness/readiness probes enabled.

## Run locally (Maven)

```bash
export CONFIG_SERVER_USERNAME=admin
export CONFIG_SERVER_PASSWORD='change-me'
export CONFIG_GIT_URI=https://github.com/<org>/<config-repo>.git

./mvnw spring-boot:run
```

## Build and run with Docker

1. Build the image from the project root:

   ```bash
   docker build -t gnax-config-server:local .
   ```

2. Run the container:

   ```bash
   docker run --rm --name gnax-config-server -p 8888:8888 \
     -e CONFIG_SERVER_USERNAME=admin \
     -e CONFIG_SERVER_PASSWORD=change-me \
     -e CONFIG_GIT_URI=https://github.com/<org>/<config-repo>.git \
     gnax-config-server:local
   ```

   Add `-d` to run in the background, and view logs with `docker logs -f gnax-config-server`.

3. Verify it is running:

   ```bash
   curl -u admin:change-me http://localhost:8888/actuator/health
   curl -u admin:change-me http://localhost:8888/<application>/<profile>
   ```

4. Stop it:

   ```bash
   docker stop gnax-config-server
   ```

For a private Git repository, use a URI and credentials the container can reach; the container has no access to your local SSH keys by default.

## Deploying to a local cluster

Deployment manifests live in the separate infrastructure repository. For a local cluster (kind or minikube), load the image first, then apply the manifests:

```bash
kind load docker-image gnax-config-server:local     # kind
minikube image load gnax-config-server:local        # minikube
```

The deployment must inject the three environment variables above (from a Secret or ConfigMap) and can use `/actuator/health/liveness` and `/actuator/health/readiness` on port `8888` for probes.

## Tests

```bash
./mvnw test
```

The context-load test needs the three environment variables set (or test-specific properties).
