# syntax=docker/dockerfile:1

FROM golang:1.24-alpine AS build
WORKDIR /src

COPY go.mod ./
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -trimpath -ldflags="-s -w" -o /out/ramadan-calendar-api ./main.go

FROM gcr.io/distroless/base-debian12:nonroot
WORKDIR /app

COPY --from=build /out/ramadan-calendar-api /app/ramadan-calendar-api

ENV PORT=8080
EXPOSE 8080

ENTRYPOINT ["/app/ramadan-calendar-api"]
