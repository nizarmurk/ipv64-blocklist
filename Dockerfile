FROM ubuntu:latest as builder

WORKDIR /

COPY . .
RUN apt install ca-certificates tzdata -y
RUN go get -v -d ./...
RUN go build -a -installsuffix cgo -o /make/app

FROM scratch as production
WORKDIR /
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY --from=builder /usr/share/zoneinfo /usr/share/zoneinfo
COPY --from=builder /make/app /app
CMD [ "/app" ]
