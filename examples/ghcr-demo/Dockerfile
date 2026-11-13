FROM --platform=$BUILDPLATFORM golang:1.23-alpine AS build
ARG TARGETOS
ARG TARGETARCH
WORKDIR /src
COPY go.mod main.go ./
RUN CGO_ENABLED=0 GOOS=$TARGETOS GOARCH=$TARGETARCH go build -trimpath -ldflags="-s -w" -o /out/server .

FROM alpine:3.21
RUN addgroup -S app && adduser -S -G app app
COPY --from=build /out/server /server
USER app
EXPOSE 8080
ENTRYPOINT ["/server"]
