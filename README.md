# gnax-config-server

Centralized configuration service for GnaX and its applications, built on Spring Cloud Config Server. It serves environment-specific, externalized configuration from a Git repository and exposes `/encrypt` and `/decrypt` endpoints for protecting secrets in that repository.

## Tech stack

- Java 17 (Microsoft OpenJDK)
- Spring Boot 4.1.1, Spring Cloud 2025.1.3
- Spring Cloud Config Server, Spring Security (HTTP Basic), Actuator
- Maven (wrapper included)

## Project structure

```
.
├── Dockerfile                                  # Multi-stage image build (non-root runtime user)
├── pom.xml
├── src/main/java/com/gnax/config/server/
│   ├── GnaxConfigServerApplication.java        # @EnableConfigServer entry point
│   └── config/SecurityConfig.java              # HTTP Basic auth, CSRF disabled, public health/info
├── src/main/resources/application.yaml
└── src/test/java/...
```

## Configuration

All variables are required and have no defaults:

| Variable | Description |
|---|---|
| `CONFIG_SERVER_USERNAME` | Basic-auth username clients use to access the server |
| `CONFIG_SERVER_PASSWORD` | Basic-auth password |
| `CONFIG_GIT_URI` | Git repository holding the configuration files (cloned on start, label `master`) |
| `ENCRYPT_KEY` | Symmetric key used by `/encrypt` and `/decrypt` and to decrypt `{cipher}` values |

Port: locally the server listens on Spring Boot's default `8080` (override with `SERVER_PORT`). The Docker image sets `SERVER_PORT=8888` (build arg `APP_PORT`), matching the Helm chart.

## Security

- Every endpoint requires HTTP Basic authentication, except `/actuator/health/**` and `/actuator/info`.
- CSRF protection is disabled (stateless API); without this, `POST /encrypt` and `/decrypt` are rejected with `401`.
- Actuator exposes `health`, `info` and `metrics`, with liveness/readiness probes enabled.
- Never commit real credentials or the encryption key. Supply them through environment variables or a Kubernetes Secret.

## Run locally (Maven)

```bash
export CONFIG_SERVER_USERNAME=admin
export CONFIG_SERVER_PASSWORD='change-me'
export CONFIG_GIT_URI=https://github.com/<org>/<config-repo>.git
export ENCRYPT_KEY='change-me-too'

./mvnw spring-boot:run
```

In IntelliJ, set the same variables in the run configuration's environment variables.

## Using the API

```bash
# Health (no credentials needed)
curl http://localhost:8080/actuator/health

# Fetch configuration: /{application}/{profile}[/{label}]
curl -u admin:change-me http://localhost:8080/<application>/<profile>

# Encrypt / decrypt (POST, plain text body)
curl -u admin:change-me -H 'Content-Type: text/plain' --data 'my-secret' http://localhost:8080/encrypt
curl -u admin:change-me -H 'Content-Type: text/plain' --data '<cipher>' http://localhost:8080/decrypt
```

Store the encrypted value in the config repository prefixed with `{cipher}`:

```yaml
spring:
  datasource:
    password: '{cipher}56ca1863...'
```

Troubleshooting `401`:

- Use the credentials of the running server process (for example the IntelliJ run configuration), not just your shell's.
- `/encrypt` and `/decrypt` only accept `POST`; a browser (GET) gets `405`/`401`.
- Changing `ENCRYPT_KEY` makes previously encrypted values undecryptable.

## Build and run with Docker

The `Dockerfile` is a multi-stage build:

- **Build stage:** `mcr.microsoft.com/openjdk/jdk:17-ubuntu` runs the Maven wrapper, caching dependencies (`dependency:go-offline`) before copying the sources, then packages the jar with tests skipped.
- **Runtime stage:** the same JDK image runs `app.jar` as a non-root `gnax` user.
- **Port:** build arg `APP_PORT` (default `8888`) sets both `EXPOSE` and the `SERVER_PORT` environment variable, so the app listens on it.
- **No secrets are baked in:** all configuration is passed at runtime as environment variables.

1. Build the image from the project root:

   ```bash
   docker build -t gnax-config-server:local .

   # custom port
   docker build --build-arg APP_PORT=9000 -t gnax-config-server:local .
   ```

2. Run the container (all four variables are required):

   ```bash
   docker run --rm --name gnax-config-server -p 8888:8888 \
     -e CONFIG_SERVER_USERNAME=admin \
     -e CONFIG_SERVER_PASSWORD=change-me \
     -e CONFIG_GIT_URI=https://github.com/<org>/<config-repo>.git \
     -e ENCRYPT_KEY=change-me-too \
     gnax-config-server:local
   ```

   Add `-d` to run in the background, and view logs with `docker logs -f gnax-config-server`.

3. Verify:

   ```bash
   curl http://localhost:8888/actuator/health
   curl -u admin:change-me http://localhost:8888/<application>/<profile>
   curl -u admin:change-me -H 'Content-Type: text/plain' --data 'my-secret' http://localhost:8888/encrypt
   ```

4. Stop it: `docker stop gnax-config-server`

Notes:

- The server clones `CONFIG_GIT_URI` on start; if the URI is unreachable or the variables are missing, the container exits. Check `docker logs`.
- For a private Git repository, use an HTTPS URI with a token (or otherwise provide credentials); the container has no access to your local SSH keys.
- `.dockerignore` excludes `target`, `.git`, `.idea`, `.vscode`, `.github`, `HELP.md`, `Dockerfile` and itself from the build context.

## Deploying to a local cluster

Kubernetes deployment is managed by the Helm chart `helm/services/gnax-config-server` in the `gnax-infrastructure` repository (values in `environments/<env>/gnax-config-server.yaml`, secrets in the git-ignored `gnax-config-server.secret.yaml`; copy from the `.example` file). The chart:

- creates a Secret (`config-server-secret`) injected into the pod via `envFrom`;
- exposes the service as `config-server.<namespace>.svc.cluster.local:8888` (NodePort `30888` in `dev`);
- uses the actuator health probes.

Make sure the Secret also provides `ENCRYPT_KEY` (the chart currently defines only username, password and Git URI). The chart's image tag is `0.0.1-SNAPSHOT` (`pullPolicy: IfNotPresent`), so build the image with that tag so the local cluster can use it:

```bash
docker build -t gnax-config-server:0.0.1-SNAPSHOT .
```

Clients such as `gnax-identity-service` connect with `spring.config.import=configserver:<url>` and the same Basic-auth credentials.

## Tests

```bash
./mvnw test
```

The context-load test requires the four environment variables above (or test-specific properties).
