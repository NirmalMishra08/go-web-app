# Stage 1: Build
FROM --platform=$BUILDPLATFORM golang:1.22.5 AS builder

WORKDIR /app

# Improve caching by copying mods first
COPY go.mod ./
# If you have a go.sum, uncomment the next line
# COPY go.sum ./
RUN go mod download

# Copy the rest of the source code
COPY . .

# Build the binary
ARG TARGETOS TARGETARCH
RUN CGO_ENABLED=0 GOOS=$TARGETOS GOARCH=$TARGETARCH go build -o main .

# Stage 2: Final Runtime
FROM gcr.io/distroless/static-debian12 
# Note: 'static-debian12' is even smaller and better for Go than 'base'

WORKDIR /app

# Copy binary and static files from builder
COPY --from=builder /app/main .
COPY --from=builder /app/static ./static

EXPOSE 8080

# Use absolute path for the entrypoint to be safe
CMD ["/app/main"]