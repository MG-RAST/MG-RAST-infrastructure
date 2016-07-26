FROM golang:1.6-alpine

RUN apk update && \
  apk add git && \
  go get -d github.com/driskell/log-courier &&\
  apk del git

RUN cd $GOPATH/src/github.com/driskell/log-courier && \
  go generate . ./lc-admin && \
  go install . ./lc-admin ./lc-tlscert
