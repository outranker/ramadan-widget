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
