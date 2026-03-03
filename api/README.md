# Ramadan Calendar API (Go)

Minimal Go API that fetches prayer times from MuslimSalat and returns a Ramadan-only calendar payload for the macOS widget.

## Endpoints
- `GET /healthz`
- `GET /v1/ramadan-calendar?city=Seoul&country=South%20Korea&year=2026`

## Environment variables
- `MUSLIMSALAT_API_KEY` (required)
- `PORT` (optional, default `8080`)
- `MUSLIMSALAT_BASE_URL` (optional, default `https://muslimsalat.com`)

## Run locally
```bash
cd api
MUSLIMSALAT_API_KEY=your_key go run .
```

## Docker
```bash
cd api
docker build -t ramadan-calendar-api .
docker run --rm -p 8080:8080 \
  -e MUSLIMSALAT_API_KEY=your_key \
  ramadan-calendar-api
```

## Deploy target
Set your deployed base URL to:
- `https://ramadan-calendar-api.javohirmirzo.com`
