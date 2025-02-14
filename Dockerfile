FROM golang:1.20.1-alpine3.17 AS BUILD_IMAGE
ENV WEBHOOK_VERSION "2.8.1"

RUN apk add --update --no-cache -t build-deps curl gcc libc-dev libgcc
WORKDIR /go/src/github.com/adnanh/webhook

COPY . /go/src/github.com/adnanh/webhook
RUN go get -d && \
   go build -ldflags="-s -w" -o /usr/local/bin/webhook

FROM alpine:3.19.0

WORKDIR /infra
COPY --from=BUILD_IMAGE /usr/local/bin/webhook /usr/local/bin/webhook

ARG YQ_VERSION="v4.34.1"
ENV YQ_VERSION "${YQ_VERSION}"

RUN apk update && apk add --no-cache \
  bash \
  jq \
  curl \
  tini

RUN curl -L -o /usr/local/bin/yq https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_amd64 \
  && chmod +x /usr/local/bin/yq

RUN addgroup -g 10001 sre && \
  adduser -u 10000 -S sre -G sre \
  && chown -R sre:sre /infra

USER sre

EXPOSE 9000
ENTRYPOINT ["/sbin/tini", "--", "/usr/local/bin/webhook"]
CMD ["-verbose", "-hotreload", "-hooks=hooks.yml"]
