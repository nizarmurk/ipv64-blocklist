# Build
FROM alpine:latest AS build

WORKDIR /app

COPY report.sh /app
RUN chmod +x /app/report.sh

# Image
FROM alpine:latest

# Work Directory
WORKDIR /app

COPY --from=build /app/report.sh /app/report.sh
RUN chmod +x /app/report.sh

# Alpine Packages
RUN apk update && \
    apk upgrade && \
    apk add --no-cache ca-certificates tzdata && \
    cp /usr/share/zoneinfo/Europe/Berlin /etc/localtime && \
    rm -rf /var/cache/apk/*

ENTRYPOINT [ "sh", "/app/report.sh" ]
