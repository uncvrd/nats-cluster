### stage: get nats exporter
# FROM curlimages/curl:latest as metrics

# WORKDIR /metrics/
# USER root
# RUN mkdir -p /metrics/
# RUN curl -o nats-exporter.tar.gz -L https://github.com/nats-io/prometheus-nats-exporter/releases/download/v0.9.1/prometheus-nats-exporter-v0.9.1-linux-amd64.tar.gz
# RUN tar zxvf nats-exporter.tar.gz
# RUN mv prometheus-nats-exporter*/prometheus-nats-exporter ./

### stage: build flyutil
FROM golang:1.20.2 as flyutil
ARG VERSION

WORKDIR /go/src/github.com/fly-apps/nats-cluster
COPY go.mod ./
COPY go.sum ./
RUN go mod download

COPY . .

RUN CGO_ENABLED=0 GOOS=linux go build -buildvcs=false -v -o /fly/bin/start ./cmd/start

# stage: final image
FROM nats:2.9.16-scratch as nats-server

FROM debian:bullseye-slim

RUN apt-get update && apt-get install -y apt-transport-https ca-certificates curl gnupg && \
    curl -sLf --retry 3 --tlsv1.2 --proto "=https" 'https://packages.doppler.com/public/cli/gpg.DE2A7741A397C129.key' | apt-key add - && \
    echo "deb https://packages.doppler.com/public/cli/deb/debian any-version main" | tee /etc/apt/sources.list.d/doppler-cli.list && \
    apt-get update && \
    apt-get -y install doppler

COPY --from=nats-server /nats-server /usr/local/bin/
# COPY --from=metrics /metrics/prometheus-nats-exporter /usr/local/bin/nats-exporter
COPY --from=flyutil /fly/bin/start /usr/local/bin/

CMD ["start"]