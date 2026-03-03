import Foundation

struct DayTimes: Codable, Hashable, Identifiable, Sendable {
    let dateISO: String
    let sehri: String
    let iftar: String
    let hijriDay: String
    let hijriMonthNumber: Int
    let hijriMonthName: String

    var id: String { dateISO }
}

struct AlAdhanClient {
    private let session: URLSession
    private let baseURL: URL

    init(session: URLSession = .shared, baseURL: URL? = nil) {
        self.session = session

        if let baseURL {
            self.baseURL = baseURL
            return
        }

        let configuredBaseURL = ProcessInfo.processInfo.environment["RAMADAN_API_BASE_URL"]
        if let configuredBaseURL, let parsed = URL(string: configuredBaseURL) {
            self.baseURL = parsed
        } else {
            self.baseURL = URL(string: "https://ramadan-calendar-api.javohirmirzo.com")!
        }
    }

    func fetchDaysAroundToday(
        city: String,
        country: String,
        method: Int,
        now: Date = Date()
    ) async throws -> [DayTimes] {
        guard var components = URLComponents(
            url: endpointURL(),
            resolvingAgainstBaseURL: false
        ) else {
            throw APIError.invalidURL
        }

        let year = Calendar(identifier: .gregorian).component(.year, from: now)
        components.queryItems = [
            URLQueryItem(name: "city", value: city),
            URLQueryItem(name: "country", value: country),
            URLQueryItem(name: "year", value: "\(year)"),
            URLQueryItem(name: "method", value: "\(method)")
        ]

        guard let url = components.url else {
            throw APIError.invalidURL
        }

        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.badResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw APIError.httpFailure(httpResponse.statusCode)
        }

        let decoded = try JSONDecoder().decode(RamadanCalendarResponse.self, from: data)
        if decoded.days.isEmpty {
            throw APIError.emptyData
        }

        let deduped = Dictionary(grouping: decoded.days, by: \.dateISO)
            .compactMap { $0.value.first }
            .sorted { $0.dateISO < $1.dateISO }

        return deduped
    }

    private func endpointURL() -> URL {
        baseURL
            .appendingPathComponent("v1")
            .appendingPathComponent("ramadan-calendar")
    }
}

private struct RamadanCalendarResponse: Decodable {
    let days: [DayTimes]
}

private enum APIError: LocalizedError {
    case invalidURL
    case badResponse
    case httpFailure(Int)
    case emptyData

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Could not build the Ramadan API request."
        case .badResponse:
            return "The Ramadan API response was not valid."
        case .httpFailure(let code):
            return "Ramadan API returned an HTTP \(code) response."
        case .emptyData:
            return "The Ramadan API returned no prayer times."
        }
    }
}
