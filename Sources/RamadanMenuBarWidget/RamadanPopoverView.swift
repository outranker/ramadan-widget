import AppKit
import SwiftUI

struct RamadanPopoverView: View {
    @ObservedObject var store: RamadanStore
    @State private var selectedCountry: String = LocationCatalog.countries.first ?? ""
    @State private var selectedCity: String = {
        let firstCountry = LocationCatalog.countries.first ?? ""
        return LocationCatalog.cities(for: firstCountry).first ?? ""
    }()

    private let sehriDua = "Wa bisawmi ghadinn nawaytu min shahri Ramadan."
    private let iftarDua = "Allahumma inni laka sumtu wa bika aamantu wa 'alayka tawakkaltu wa ala rizqika aftartu."

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    WidgetTheme.gradientTop,
                    WidgetTheme.gradientBottom
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 12) {
                headerCard
                locationCard
                calendarCard
                duaCard
                footerRow
            }
            .padding(14)
        }
        .frame(width: 440)
        .onAppear {
            syncSelectionFromStore()
        }
        .onChange(of: store.city) { _ in
            syncSelectionFromStore()
        }
        .onChange(of: store.country) { _ in
            syncSelectionFromStore()
        }
        .onChange(of: selectedCountry) { newCountry in
            let citiesForCountry = cityOptions(for: newCountry, includeSelectedCity: false)
            if !citiesForCountry.contains(selectedCity) {
                selectedCity = citiesForCountry.first ?? cleanedValue(store.city)
            }
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Ramadan Widget")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))

            Text(store.statusTitle)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)

            Text(store.statusDetails)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.85))
        }
        .cardStyle()
    }

    private var locationCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("City")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
                Spacer()
                Text("Country")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
            }

            HStack(spacing: 8) {
                locationPicker(
                    selection: $selectedCity,
                    options: availableCities
                )

                locationPicker(
                    selection: $selectedCountry,
                    options: availableCountries
                )
                .frame(width: 180)
            }

            HStack(spacing: 8) {
                Button {
                    Task {
                        await store.submitLocation(city: selectedCity, country: selectedCountry)
                    }
                } label: {
                    if store.isLoading {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text("Update")
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(WidgetTheme.buttonTint)
                .disabled(store.isLoading || selectedCity.isEmpty || selectedCountry.isEmpty)

                Button("Refresh") {
                    Task {
                        await store.refresh(force: true)
                    }
                }
                .buttonStyle(.bordered)
                .tint(WidgetTheme.secondaryButtonTint)
                .disabled(store.isLoading)

                Spacer()

                Text(store.lastUpdatedLabel)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.8))
            }

            if let errorMessage = store.errorMessage {
                Text(errorMessage)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(Color(red: 0.96, green: 0.77, blue: 0.44))
            }
        }
        .cardStyle()
    }

    private var calendarCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Ramadan Calendar")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                Spacer()
                Text("\(store.city), \(store.country)")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.8))
            }

            HStack {
                Text("Date").frame(maxWidth: .infinity, alignment: .leading)
                Text("Sehri").frame(width: 70, alignment: .leading)
                Text("Iftar").frame(width: 70, alignment: .leading)
            }
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundStyle(.white.opacity(0.85))
            .padding(.bottom, 2)

            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(store.calendarDays) { day in
                        HStack {
                            Text(store.dateLabel(for: day))
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text(day.sehri)
                                .frame(width: 70, alignment: .leading)
                                .monospacedDigit()
                            Text(day.iftar)
                                .frame(width: 70, alignment: .leading)
                                .monospacedDigit()
                        }
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(store.isToday(day) ? WidgetTheme.todayRowBackground : WidgetTheme.rowBackground)
                        )
                    }
                }
                .padding(.vertical, 2)
            }
            .frame(height: 220)
        }
        .cardStyle()
    }

    private var duaCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Duas")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)

            VStack(alignment: .leading, spacing: 4) {
                Text("Sehri Dua")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))
                Text(sehriDua)
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundStyle(.white.opacity(0.86))
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Iftar Dua")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))
                Text(iftarDua)
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundStyle(.white.opacity(0.86))
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .cardStyle()
    }

    private var footerRow: some View {
        HStack {
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.bordered)
            .tint(WidgetTheme.secondaryButtonTint)

            Spacer()
        }
    }

    private var availableCountries: [String] {
        mergedOptions(
            base: LocationCatalog.countries,
            extras: [selectedCountry, cleanedValue(store.country)]
        )
    }

    private var availableCities: [String] {
        cityOptions(for: selectedCountry, includeSelectedCity: true)
    }

    private func cityOptions(for country: String, includeSelectedCity: Bool) -> [String] {
        var extras: [String] = []
        if includeSelectedCity {
            extras.append(selectedCity)
        }
        if country == cleanedValue(store.country) {
            extras.append(cleanedValue(store.city))
        }

        return mergedOptions(
            base: LocationCatalog.cities(for: country),
            extras: extras
        )
    }

    private func mergedOptions(base: [String], extras: [String]) -> [String] {
        var seen: Set<String> = []
        var merged: [String] = []

        for option in base + extras {
            let cleaned = cleanedValue(option)
            guard !cleaned.isEmpty else { continue }
            if seen.insert(cleaned).inserted {
                merged.append(cleaned)
            }
        }

        return merged
    }

    private func cleanedValue(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func syncSelectionFromStore() {
        let storeCountry = cleanedValue(store.country)
        if !storeCountry.isEmpty {
            selectedCountry = storeCountry
        } else if selectedCountry.isEmpty {
            selectedCountry = LocationCatalog.countries.first ?? ""
        }

        let storeCity = cleanedValue(store.city)
        let citiesForCountry = cityOptions(for: selectedCountry, includeSelectedCity: false)

        if !storeCity.isEmpty, citiesForCountry.contains(storeCity) {
            selectedCity = storeCity
        } else if !selectedCity.isEmpty, citiesForCountry.contains(selectedCity) {
            // Keep user selection when still valid for the country.
        } else if let firstCity = citiesForCountry.first {
            selectedCity = firstCity
        } else {
            selectedCity = storeCity
        }
    }

    private func locationPicker(selection: Binding<String>, options: [String]) -> some View {
        Picker("", selection: selection) {
            if options.isEmpty {
                Text("Select").tag("")
            } else {
                ForEach(options, id: \.self) { option in
                    Text(option).tag(option)
                }
            }
        }
        .labelsHidden()
        .pickerStyle(.menu)
        .foregroundStyle(.white)
        .tint(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(WidgetTheme.fieldFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(WidgetTheme.fieldStroke, lineWidth: 0.8)
        )
    }
}

private enum WidgetTheme {
    static let gradientTop = Color(red: 0.03, green: 0.18, blue: 0.10)
    static let gradientBottom = Color(red: 0.07, green: 0.34, blue: 0.18)
    static let cardFill = Color(red: 0.90, green: 0.98, blue: 0.92).opacity(0.14)
    static let cardStroke = Color(red: 0.78, green: 0.93, blue: 0.82).opacity(0.35)
    static let fieldFill = Color.white.opacity(0.14)
    static let fieldStroke = Color.white.opacity(0.22)
    static let rowBackground = Color(red: 0.87, green: 0.99, blue: 0.90).opacity(0.12)
    static let todayRowBackground = Color(red: 0.72, green: 0.90, blue: 0.76).opacity(0.32)
    static let buttonTint = Color(red: 0.19, green: 0.63, blue: 0.33)
    static let secondaryButtonTint = Color(red: 0.43, green: 0.68, blue: 0.50)
}

private extension View {
    func cardStyle() -> some View {
        padding(12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(WidgetTheme.cardFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(WidgetTheme.cardStroke, lineWidth: 0.8)
            )
    }
}
