package main

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log"
	"net/http"
	"net/url"
	"os"
	"sort"
	"strconv"
	"strings"
	"time"
)

const (
	defaultPort         = "8080"
	defaultMethod       = 5
	defaultUpstreamBase = "https://muslimsalat.com"
)

type server struct {
	client       *http.Client
	upstreamBase string
	apiKey       string
}

type dayTimes struct {
	DateISO          string `json:"dateISO"`
	Sehri            string `json:"sehri"`
	Iftar            string `json:"iftar"`
	HijriDay         string `json:"hijriDay"`
	HijriMonthNumber int    `json:"hijriMonthNumber"`
	HijriMonthName   string `json:"hijriMonthName"`
}

type calendarResponse struct {
	City        string     `json:"city"`
	Country     string     `json:"country"`
	Year        int        `json:"year"`
	Attribution string     `json:"attribution"`
	Days        []dayTimes `json:"days"`
}

type errorResponse struct {
	Error string `json:"error"`
}

type muslimSalatResponse struct {
	Title             string           `json:"title"`
	Query             string           `json:"query"`
	For               string           `json:"for"`
	Method            json.Number      `json:"method"`
	StatusValid       json.Number      `json:"status_valid"`
	StatusCode        json.Number      `json:"status_code"`
	StatusDescription string           `json:"status_description"`
	StatusError       json.RawMessage  `json:"status_error"`
	Country           string           `json:"country"`
	Items             []muslimSalatDay `json:"items"`
}

type muslimSalatDay struct {
	DateFor  string `json:"date_for"`
	Fajr     string `json:"fajr"`
	Shurooq  string `json:"shurooq"`
	Dhuhr    string `json:"dhuhr"`
	Asr      string `json:"asr"`
	Maghrib  string `json:"maghrib"`
	Isha     string `json:"isha"`
}

func main() {
	apiKey := strings.TrimSpace(os.Getenv("MUSLIMSALAT_API_KEY"))
	if apiKey == "" {
		log.Fatal("MUSLIMSALAT_API_KEY is required")
	}

	port := strings.TrimSpace(os.Getenv("PORT"))
	if port == "" {
		port = defaultPort
	}

	upstreamBase := strings.TrimSpace(os.Getenv("MUSLIMSALAT_BASE_URL"))
	if upstreamBase == "" {
		upstreamBase = defaultUpstreamBase
	}
	upstreamBase = strings.TrimRight(upstreamBase, "/")

	s := &server{
		client: &http.Client{
			Timeout: 25 * time.Second,
		},
		upstreamBase: upstreamBase,
		apiKey:       apiKey,
	}

	mux := http.NewServeMux()
	mux.HandleFunc("/healthz", s.handleHealth)
	mux.HandleFunc("/v1/ramadan-calendar", s.handleRamadanCalendar)

	httpServer := &http.Server{
		Addr:              ":" + port,
		Handler:           withCORS(mux),
		ReadHeaderTimeout: 5 * time.Second,
	}

	log.Printf("ramadan-calendar-api listening on :%s", port)
	if err := httpServer.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
		log.Fatalf("server failed: %v", err)
	}
}

func withCORS(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Header().Set("Access-Control-Allow-Methods", "GET, OPTIONS")
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type")

		if r.Method == http.MethodOptions {
			w.WriteHeader(http.StatusNoContent)
			return
		}

		next.ServeHTTP(w, r)
	})
}

func (s *server) handleHealth(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		writeJSONError(w, http.StatusMethodNotAllowed, "method not allowed")
		return
	}

	writeJSON(w, http.StatusOK, map[string]any{
		"ok":      true,
		"service": "ramadan-calendar-api",
	})
}

func (s *server) handleRamadanCalendar(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		writeJSONError(w, http.StatusMethodNotAllowed, "method not allowed")
		return
	}

	city := cleaned(r.URL.Query().Get("city"))
	country := cleaned(r.URL.Query().Get("country"))

	if city == "" || country == "" {
		writeJSONError(w, http.StatusBadRequest, "city and country are required")
		return
	}

	year := time.Now().Year()
	if yearRaw := cleaned(r.URL.Query().Get("year")); yearRaw != "" {
		parsedYear, err := strconv.Atoi(yearRaw)
		if err != nil || parsedYear < 2000 || parsedYear > 2100 {
			writeJSONError(w, http.StatusBadRequest, "year must be between 2000 and 2100")
			return
		}
		year = parsedYear
	}

	method := defaultMethod
	if methodRaw := cleaned(r.URL.Query().Get("method")); methodRaw != "" {
		parsedMethod, err := strconv.Atoi(methodRaw)
		if err != nil || parsedMethod < 1 || parsedMethod > 7 {
			writeJSONError(w, http.StatusBadRequest, "method must be between 1 and 7")
			return
		}
		method = parsedMethod
	}

	days, err := s.fetchRamadanCalendar(r.Context(), city, country, year, method)
	if err != nil {
		log.Printf("ramadan-calendar fetch failed for %s, %s: %v", city, country, err)
		writeJSONError(w, http.StatusBadGateway, "failed to load prayer times from upstream")
		return
	}

	writeJSON(w, http.StatusOK, calendarResponse{
		City:        city,
		Country:     country,
		Year:        year,
		Attribution: "Prayer times sourced from MuslimSalat.com",
		Days:        days,
	})
}

func (s *server) fetchRamadanCalendar(
	ctx context.Context,
	city string,
	country string,
	year int,
	method int,
) ([]dayTimes, error) {
	// MuslimSalat URL: /{location}/yearly/{date}/{daylight}/{method}.json?key=...
	// Date format: MM-DD-YYYY
	location := fmt.Sprintf("%s, %s", city, country)
	startDate := fmt.Sprintf("01-01-%04d", year)
	pathSegment := fmt.Sprintf("/%s/yearly/%s/false/%d.json",
		url.PathEscape(location), startDate, method)

	u, err := url.Parse(s.upstreamBase + pathSegment)
	if err != nil {
		return nil, fmt.Errorf("build upstream URL: %w", err)
	}
	q := u.Query()
	q.Set("key", s.apiKey)
	u.RawQuery = q.Encode()

	log.Printf("upstream request: %s/%s/yearly/%s/false/%d.json",
		s.upstreamBase, location, startDate, method)

	req, err := http.NewRequestWithContext(ctx, http.MethodGet, u.String(), nil)
	if err != nil {
		return nil, fmt.Errorf("create upstream request: %w", err)
	}
	req.Header.Set("Accept", "application/json")

	resp, err := s.client.Do(req)
	if err != nil {
		return nil, fmt.Errorf("execute upstream request: %w", err)
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(io.LimitReader(resp.Body, 2<<20))
	if err != nil {
		return nil, fmt.Errorf("read upstream body: %w", err)
	}

	if resp.StatusCode < 200 || resp.StatusCode > 299 {
		return nil, fmt.Errorf("upstream returned HTTP %d: %s", resp.StatusCode, string(body))
	}

	var decoded muslimSalatResponse
	if err := json.Unmarshal(body, &decoded); err != nil {
		return nil, fmt.Errorf("decode upstream payload: %w", err)
	}

	if valid, _ := decoded.StatusValid.Int64(); valid != 1 {
		return nil, fmt.Errorf("upstream API error (status_code=%s): %s — %s",
			decoded.StatusCode, decoded.StatusDescription, string(decoded.StatusError))
	}

	if len(decoded.Items) == 0 {
		return nil, errors.New("upstream returned no calendar items")
	}

	deduped := make(map[string]dayTimes)

	for _, item := range decoded.Items {
		day, ok := toRamadanDay(item)
		if !ok {
			continue
		}
		deduped[day.DateISO] = day
	}

	if len(deduped) == 0 {
		return nil, errors.New("no ramadan days in upstream response")
	}

	days := make([]dayTimes, 0, len(deduped))
	for _, day := range deduped {
		days = append(days, day)
	}

	sort.Slice(days, func(i, j int) bool {
		return days[i].DateISO < days[j].DateISO
	})

	return days, nil
}

func toRamadanDay(item muslimSalatDay) (dayTimes, bool) {
	date, err := parseDateFor(item.DateFor)
	if err != nil {
		return dayTimes{}, false
	}

	sehri, sehriOK := normalizePrayerTime(item.Fajr)
	if !sehriOK {
		return dayTimes{}, false
	}

	iftar, iftarOK := normalizePrayerTime(item.Maghrib)
	if !iftarOK {
		return dayTimes{}, false
	}

	hijriYear, hijriMonth, hijriDay := gregorianToHijri(date.Year(), int(date.Month()), date.Day())
	_ = hijriYear

	if hijriMonth != 9 {
		return dayTimes{}, false
	}

	return dayTimes{
		DateISO:          date.Format("2006-01-02"),
		Sehri:            sehri,
		Iftar:            iftar,
		HijriDay:         strconv.Itoa(hijriDay),
		HijriMonthNumber: hijriMonth,
		HijriMonthName:   "Ramadan",
	}, true
}

func parseDateFor(value string) (time.Time, error) {
	trimmed := cleaned(value)
	if trimmed == "" {
		return time.Time{}, errors.New("empty date")
	}

	layouts := []string{
		"2006-01-02",
		"02-01-2006",
		"2-1-2006",
		"02 Jan 2006",
		"2 Jan 2006",
		"Jan 2, 2006",
		"January 2, 2006",
		"Monday, January 2, 2006",
		"Mon, Jan 2, 2006",
	}

	for _, layout := range layouts {
		if parsed, err := time.ParseInLocation(layout, trimmed, time.UTC); err == nil {
			return parsed, nil
		}
	}

	return time.Time{}, fmt.Errorf("unsupported date format: %s", value)
}

func normalizePrayerTime(value string) (string, bool) {
	trimmed := cleaned(value)
	if trimmed == "" {
		return "", false
	}

	// Drop timezone suffixes such as "(+03)".
	if idx := strings.Index(trimmed, "("); idx >= 0 {
		trimmed = cleaned(trimmed[:idx])
	}

	trimmed = strings.ReplaceAll(trimmed, ".", "")
	fields := strings.Fields(trimmed)

	candidates := make([]string, 0, 2)
	if len(fields) >= 2 && (strings.EqualFold(fields[1], "am") || strings.EqualFold(fields[1], "pm")) {
		candidates = append(candidates, strings.ToUpper(fields[0]+" "+fields[1]))
	}
	if len(fields) >= 1 {
		candidates = append(candidates, fields[0])
	}
	candidates = append(candidates, strings.ToUpper(trimmed))

	layouts := []string{"3:04 PM", "03:04 PM", "15:04"}

	for _, candidate := range candidates {
		for _, layout := range layouts {
			if parsed, err := time.Parse(layout, candidate); err == nil {
				return parsed.Format("15:04"), true
			}
		}
	}

	return "", false
}

func cleaned(value string) string {
	return strings.TrimSpace(value)
}

// gregorianToHijri converts Gregorian date to Islamic civil date.
// It is deterministic and dependency-free for lightweight deployment.
func gregorianToHijri(year int, month int, day int) (int, int, int) {
	jd := gregorianToJulianDay(year, month, day)
	l := jd - 1948440 + 10632
	n := (l - 1) / 10631
	l = l - 10631*n + 354
	j := ((10985-l)/5316)*((50*l)/17719) + (l/5670)*((43*l)/15238)
	l = l - ((30-j)/15)*((17719*j)/50) - (j/16)*((15238*j)/43) + 29
	hijriMonth := (24 * l) / 709
	hijriDay := l - (709*hijriMonth)/24
	hijriYear := 30*n + j - 30
	return hijriYear, hijriMonth, hijriDay
}

func gregorianToJulianDay(year int, month int, day int) int {
	a := (14 - month) / 12
	y := year + 4800 - a
	m := month + 12*a - 3
	return day + (153*m+2)/5 + 365*y + y/4 - y/100 + y/400 - 32045
}

func writeJSON(w http.ResponseWriter, statusCode int, payload any) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(statusCode)
	if err := json.NewEncoder(w).Encode(payload); err != nil {
		log.Printf("write response failed: %v", err)
	}
}

func writeJSONError(w http.ResponseWriter, statusCode int, message string) {
	writeJSON(w, statusCode, errorResponse{Error: message})
}
