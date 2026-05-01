# Build stage
FROM dart:stable AS build

WORKDIR /app

# Resolve dependencies first for layer caching
COPY pubspec.* ./
RUN dart pub get

# Copy source and compile to native exe
COPY bin/ bin/
RUN dart compile exe bin/server.dart -o bin/server

# Runtime stage — debian bookworm-slim mirrors the downstream-server pattern.
FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y \
    ca-certificates \
    libsqlite3-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY --from=build /app/bin/server /app/bin/server

ENV PORT=8081
EXPOSE 8081

CMD ["/app/bin/server"]
