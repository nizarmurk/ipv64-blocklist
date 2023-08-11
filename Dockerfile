FROM alpine:latest

WORKDIR /app

COPY report.sh /app

# APK Packages
RUN apk update
RUN apk upgrade
RUN apk add ca-certificates
RUN apk add tzdata

# Copy Europe/Berlin in /etc/localtime
RUN cp /usr/share/zoneinfo/Europe/Berlin /etc/localtime

ENTRYPOINT [ "report.sh" ]
