import Foundation

struct LocationOption: Hashable, Identifiable {
    let city: String
    let country: String

    var id: String {
        "\(city)|\(country)"
    }
}

enum LocationCatalog {
    static let entries: [LocationOption] = [
        LocationOption(city: "Algiers", country: "Algeria"),
        LocationOption(city: "Oran", country: "Algeria"),
        LocationOption(city: "Dhaka", country: "Bangladesh"),
        LocationOption(city: "Chittagong", country: "Bangladesh"),
        LocationOption(city: "Manama", country: "Bahrain"),
        LocationOption(city: "Toronto", country: "Canada"),
        LocationOption(city: "Montreal", country: "Canada"),
        LocationOption(city: "Vancouver", country: "Canada"),
        LocationOption(city: "Cairo", country: "Egypt"),
        LocationOption(city: "Alexandria", country: "Egypt"),
        LocationOption(city: "Giza", country: "Egypt"),
        LocationOption(city: "Paris", country: "France"),
        LocationOption(city: "Marseille", country: "France"),
        LocationOption(city: "Berlin", country: "Germany"),
        LocationOption(city: "Frankfurt", country: "Germany"),
        LocationOption(city: "Delhi", country: "India"),
        LocationOption(city: "Mumbai", country: "India"),
        LocationOption(city: "Hyderabad", country: "India"),
        LocationOption(city: "Bengaluru", country: "India"),
        LocationOption(city: "Jakarta", country: "Indonesia"),
        LocationOption(city: "Bandung", country: "Indonesia"),
        LocationOption(city: "Surabaya", country: "Indonesia"),
        LocationOption(city: "Amman", country: "Jordan"),
        LocationOption(city: "Nairobi", country: "Kenya"),
        LocationOption(city: "Kuwait City", country: "Kuwait"),
        LocationOption(city: "Kuala Lumpur", country: "Malaysia"),
        LocationOption(city: "Penang", country: "Malaysia"),
        LocationOption(city: "Johor Bahru", country: "Malaysia"),
        LocationOption(city: "Casablanca", country: "Morocco"),
        LocationOption(city: "Rabat", country: "Morocco"),
        LocationOption(city: "Marrakesh", country: "Morocco"),
        LocationOption(city: "Lagos", country: "Nigeria"),
        LocationOption(city: "Abuja", country: "Nigeria"),
        LocationOption(city: "Muscat", country: "Oman"),
        LocationOption(city: "Karachi", country: "Pakistan"),
        LocationOption(city: "Lahore", country: "Pakistan"),
        LocationOption(city: "Islamabad", country: "Pakistan"),
        LocationOption(city: "Doha", country: "Qatar"),
        LocationOption(city: "Makkah", country: "Saudi Arabia"),
        LocationOption(city: "Madinah", country: "Saudi Arabia"),
        LocationOption(city: "Riyadh", country: "Saudi Arabia"),
        LocationOption(city: "Jeddah", country: "Saudi Arabia"),
        LocationOption(city: "Dammam", country: "Saudi Arabia"),
        LocationOption(city: "Singapore", country: "Singapore"),
        LocationOption(city: "Johannesburg", country: "South Africa"),
        LocationOption(city: "Cape Town", country: "South Africa"),
        LocationOption(city: "Seoul", country: "South Korea"),
        LocationOption(city: "Tunis", country: "Tunisia"),
        LocationOption(city: "Istanbul", country: "Turkey"),
        LocationOption(city: "Ankara", country: "Turkey"),
        LocationOption(city: "Bursa", country: "Turkey"),
        LocationOption(city: "Dubai", country: "United Arab Emirates"),
        LocationOption(city: "Abu Dhabi", country: "United Arab Emirates"),
        LocationOption(city: "Sharjah", country: "United Arab Emirates"),
        LocationOption(city: "London", country: "United Kingdom"),
        LocationOption(city: "Birmingham", country: "United Kingdom"),
        LocationOption(city: "Manchester", country: "United Kingdom"),
        LocationOption(city: "New York", country: "United States"),
        LocationOption(city: "Chicago", country: "United States"),
        LocationOption(city: "Los Angeles", country: "United States")
    ]

    static let countries: [String] = {
        let unique = Set(entries.map(\.country))
        return unique.sorted(by: localizedAscending)
    }()

    static func cities(for country: String) -> [String] {
        entries
            .filter { $0.country == country }
            .map(\.city)
            .sorted(by: localizedAscending)
    }

    private static func localizedAscending(_ lhs: String, _ rhs: String) -> Bool {
        lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
    }
}
