FROM ubuntu:latest

WORKDIR /app

COPY report.sh /app

RUN apt update -y && apt upgrade -y
RUN apt install ca-certificates tzdata -y

ENTRYPOINT [ "report.sh" ]
