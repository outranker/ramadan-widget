# Ramadan Menu Bar Widget (macOS)

Native macOS menu bar app that shows the next Ramadan event in the status bar:
- `Sehri HH:mm` before Sehri time
- `Iftar HH:mm` after Sehri and before Iftar
- `Sehri HH:mm` after Iftar (next day)

On click, it opens a styled popover with:
- Ramadan calendar (date, Sehri, Iftar)
- Sehri and Iftar duas
- City/country dropdowns with live API refresh

## Data source
Uses the deployed Go API at `https://ramadan-calendar-api.javohirmirzo.com`, which proxies MuslimSalat data and returns Ramadan calendar days.

To point the widget at a different backend while developing:
```bash
RAMADAN_API_BASE_URL=http://localhost:8080 swift run
```

## Run
```bash
swift run
```

## Build
```bash
swift build
```

## Backend API
The Go backend lives in `api/` and is dockerized for deployment.

### Run with Docker Compose
1. Copy the example env and set your MuslimSalat API key:
   ```bash
   cp .env.example .env
   # Edit .env and set MUSLIMSALAT_API_KEY=your_key
   ```
2. Build and start:
   ```bash
   docker compose up -d --build
   ```
   API is at `http://localhost:8080` (e.g. `/healthz`, `/v1/ramadan-calendar?city=...&country=...`).

### Raspberry Pi / ARM64
The image builds for the host architecture. On a Raspberry Pi 4 (or other ARM64), run the same commands; the Dockerfile uses `TARGETARCH` so the binary is built for ARM64 and the exec format error is avoided. From an x86 host you can build for the Pi with:
```bash
docker buildx build --platform linux/arm64 -t ramadan-widget-api:latest ./api
```
