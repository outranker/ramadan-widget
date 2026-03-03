import Foundation

@MainActor
final class RamadanStore: ObservableObject {
    @Published private(set) var statusTitle: String = "Loading..."
    @Published private(set) var statusDetails: String = "Fetching prayer times..."
    @Published private(set) var allDays: [DayTimes] = []
    @Published private(set) var calendarDays: [DayTimes] = []
    @Published private(set) var lastUpdatedLabel: String = "Not updated yet"
    @Published var city: String
    @Published var country: String
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private enum Keys {
        static let city = "ramadan.city"
        static let country = "ramadan.country"
    }

    private let client: AlAdhanClient
    private let defaults: UserDefaults
    private let fileManager: FileManager
    private let method: Int = 2
    private var timer: Timer?

    init(
        client: AlAdhanClient = AlAdhanClient(),
        defaults: UserDefaults = .standard,
        fileManager: FileManager = .default
    ) {
        self.client = client
        self.defaults = defaults
        self.fileManager = fileManager
        self.city = defaults.string(forKey: Keys.city) ?? "New York"
        self.country = defaults.string(forKey: Keys.country) ?? "US"

        startTimer()

        Task {
            await refresh(force: false)
        }
    }

    func submitLocation(city: String, country: String) async {
        let cleanedCity = city.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedCountry = normalizedCountry(country)

        guard !cleanedCity.isEmpty, !cleanedCountry.isEmpty else {
            errorMessage = "Enter both city and country."
            return
        }

        self.city = cleanedCity
        self.country = cleanedCountry
        await refresh(force: true)
    }

    func refresh(force: Bool = true) async {
        let cleanedCity = city.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedCountry = normalizedCountry(country)

        guard !cleanedCity.isEmpty, !cleanedCountry.isEmpty else {
            statusTitle = "Set City"
            statusDetails = "Add city and country to load prayer times."
            errorMessage = "City and country are required."
            return
        }

        city = cleanedCity
        country = cleanedCountry
        defaults.set(cleanedCity, forKey: Keys.city)
        defaults.set(cleanedCountry, forKey: Keys.country)

        if !force, let cached = loadCache(city: cleanedCity, country: cleanedCountry), isCacheFresh(cached.fetchedAt) {
            applyDays(cached.days, fetchedAt: cached.fetchedAt)
            errorMessage = nil
            return
        }

        isLoading = true
        errorMessage = nil

        defer {
            isLoading = false
        }

        do {
            let fetched = try await client.fetchDaysAroundToday(
                city: cleanedCity,
                country: cleanedCountry,
                method: method
            )
            guard !fetched.isEmpty else {
                throw RamadanStoreError.emptyData
            }

            applyDays(fetched, fetchedAt: Date())
            saveCache(
                payload: CachePayload(fetchedAt: Date(), days: fetched),
                city: cleanedCity,
                country: cleanedCountry
            )
        } catch {
            if let cached = loadCache(city: cleanedCity, country: cleanedCountry) {
                applyDays(cached.days, fetchedAt: cached.fetchedAt)
                errorMessage = "Live refresh failed. Showing cached times."
            } else {
                allDays = []
                calendarDays = []
                statusTitle = "Unavailable"
                statusDetails = "Could not load prayer times right now."
                lastUpdatedLabel = "Not updated yet"
                errorMessage = "Failed to load \(cleanedCity), \(cleanedCountry). Check the city spelling and network."
            }
        }
    }

    func isToday(_ day: DayTimes) -> Bool {
        day.dateISO == isoDateString(from: Date())
    }

    func dateLabel(for day: DayTimes) -> String {
        let parts = day.dateISO.split(separator: "-")
        guard parts.count == 3 else { return day.dateISO }
        guard
            let year = Int(parts[0]),
            let month = Int(parts[1]),
            let dayValue = Int(parts[2])
        else {
            return day.dateISO
        }

        let calendar = Calendar(identifier: .gregorian)
        let components = DateComponents(year: year, month: month, day: dayValue)
        guard let date = calendar.date(from: components) else { return day.dateISO }

        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale.current
        formatter.setLocalizedDateFormatFromTemplate("MMM d")
        let gregorian = formatter.string(from: date)

        return "\(gregorian) · \(day.hijriDay) \(day.hijriMonthName)"
    }

    private func applyDays(_ days: [DayTimes], fetchedAt: Date) {
        let deduped = Dictionary(grouping: days, by: \.dateISO)
            .compactMap { $0.value.first }
            .sorted { $0.dateISO < $1.dateISO }

        allDays = deduped

        let ramadanOnly = deduped.filter { $0.hijriMonthNumber == 9 }
        calendarDays = ramadanOnly.isEmpty ? deduped : ramadanOnly

        lastUpdatedLabel = "Updated \(relativeUpdateText(since: fetchedAt))"
        updateStatus(now: Date())
    }

    private func updateStatus(now: Date) {
        guard let event = nextEvent(after: now) else {
            statusTitle = "No Times"
            statusDetails = "No upcoming Sehri/Iftar found in fetched range."
            return
        }

        statusTitle = "\(event.kind.displayName) \(event.displayTime)"
        statusDetails = "\(event.kind.displayName) at \(event.displayTime) \(relativeDayText(for: event.day.dateISO, now: now)) (\(countdownText(to: event.date, now: now)))"
    }

    private func nextEvent(after now: Date) -> PrayerEvent? {
        guard !allDays.isEmpty else {
            return nil
        }

        var candidate: PrayerEvent?

        for day in allDays {
            if let sehriDate = combine(day.dateISO, day.sehri), sehriDate > now {
                let event = PrayerEvent(kind: .sehri, day: day, displayTime: day.sehri, date: sehriDate)
                candidate = earlierEvent(current: candidate, incoming: event)
            }

            if let iftarDate = combine(day.dateISO, day.iftar), iftarDate > now {
                let event = PrayerEvent(kind: .iftar, day: day, displayTime: day.iftar, date: iftarDate)
                candidate = earlierEvent(current: candidate, incoming: event)
            }
        }

        return candidate
    }

    private func earlierEvent(current: PrayerEvent?, incoming: PrayerEvent) -> PrayerEvent {
        guard let current else { return incoming }
        return incoming.date < current.date ? incoming : current
    }

    private func combine(_ isoDate: String, _ hhmm: String) -> Date? {
        let dateParts = isoDate.split(separator: "-")
        let timeParts = hhmm.split(separator: ":")

        guard dateParts.count == 3, timeParts.count >= 2 else { return nil }
        guard
            let year = Int(dateParts[0]),
            let month = Int(dateParts[1]),
            let day = Int(dateParts[2]),
            let hour = Int(timeParts[0]),
            let minute = Int(timeParts[1].prefix(2))
        else {
            return nil
        }

        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = TimeZone.current
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        components.second = 0
        return components.date
    }

    private func isoDateString(from date: Date) -> String {
        let calendar = Calendar(identifier: .gregorian)
        let parts = calendar.dateComponents(in: TimeZone.current, from: date)
        let year = parts.year ?? 0
        let month = parts.month ?? 0
        let day = parts.day ?? 0
        return String(format: "%04d-%02d-%02d", year, month, day)
    }

    private func relativeDayText(for isoDate: String, now: Date) -> String {
        let todayISO = isoDateString(from: now)
        let tomorrowDate = Calendar(identifier: .gregorian).date(byAdding: .day, value: 1, to: now) ?? now
        let tomorrowISO = isoDateString(from: tomorrowDate)

        if isoDate == todayISO { return "today" }
        if isoDate == tomorrowISO { return "tomorrow" }

        let dateParts = isoDate.split(separator: "-")
        guard dateParts.count == 3 else { return "soon" }
        guard
            let year = Int(dateParts[0]),
            let month = Int(dateParts[1]),
            let day = Int(dateParts[2])
        else {
            return "soon"
        }

        let calendar = Calendar(identifier: .gregorian)
        let components = DateComponents(year: year, month: month, day: day)
        guard let date = calendar.date(from: components) else { return "soon" }

        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale.current
        formatter.setLocalizedDateFormatFromTemplate("MMM d")
        return "on \(formatter.string(from: date))"
    }

    private func countdownText(to date: Date, now: Date) -> String {
        let totalSeconds = max(0, Int(date.timeIntervalSince(now)))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m left"
        }
        return "\(minutes)m left"
    }

    private func relativeUpdateText(since fetchedAt: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: fetchedAt, relativeTo: Date())
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateStatus(now: Date())
            }
        }
        timer?.tolerance = 3
    }

    private func isCacheFresh(_ fetchedAt: Date) -> Bool {
        Date().timeIntervalSince(fetchedAt) < 60 * 60 * 12
    }

    private func cacheURL(city: String, country: String) -> URL? {
        guard let appSupport = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            return nil
        }

        let folder = appSupport.appendingPathComponent("RamadanMenuBarWidget", isDirectory: true)
        do {
            try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        } catch {
            return nil
        }

        let citySlug = slug(city)
        let countrySlug = slug(country)
        return folder.appendingPathComponent("cache-\(citySlug)-\(countrySlug).json")
    }

    private func loadCache(city: String, country: String) -> CachePayload? {
        guard let url = cacheURL(city: city, country: country) else { return nil }
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(CachePayload.self, from: data)
    }

    private func saveCache(payload: CachePayload, city: String, country: String) {
        guard let url = cacheURL(city: city, country: country) else { return }
        guard let data = try? JSONEncoder().encode(payload) else { return }
        try? data.write(to: url, options: .atomic)
    }

    private func slug(_ value: String) -> String {
        let transformed = value.lowercased().map { character -> Character in
            if character.isLetter || character.isNumber {
                return character
            }
            return "-"
        }
        return String(transformed)
    }

    private func normalizedCountry(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count <= 3 {
            return trimmed.uppercased()
        }
        return trimmed
    }
}

private struct CachePayload: Codable {
    let fetchedAt: Date
    let days: [DayTimes]
}

private struct PrayerEvent {
    enum Kind {
        case sehri
        case iftar

        var displayName: String {
            switch self {
            case .sehri:
                return "Sehri"
            case .iftar:
                return "Iftar"
            }
        }
    }

    let kind: Kind
    let day: DayTimes
    let displayTime: String
    let date: Date
}

private enum RamadanStoreError: LocalizedError {
    case emptyData

    var errorDescription: String? {
        switch self {
        case .emptyData:
            return "The API returned no prayer times."
        }
    }
}
