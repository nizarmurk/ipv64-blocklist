FROM alpine:latest

WORKDIR /app

COPY report.sh /app

RUN apk update
RUN apk upgrade
RUN apk add ca-certificates
RUN apk add tzdata
RUN cp /usr/share/zoneinfo/Europe/Berlin /etc/localtime
RUN ls /usr/share/zoneinfo
# RUN apt update -y && apt upgrade -y
# RUN apt install ca-certificates tzdata -y

ENTRYPOINT [ "report.sh" ]
