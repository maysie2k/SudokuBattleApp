import Foundation
import SwiftUI
import Vision
import UIKit
import Combine

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var settings: AppSettings
    @Published var nameWarning: String?
    @Published var imageWarning: String?

    private let store: AppSettingsStore
    private let blockedWords: [String] = [
        "fuck", "shit", "bitch", "asshole", "dick", "cunt", "nigger", "faggot", "bastard"
    ]

    init(store: AppSettingsStore = .shared) {
        self.store = store
        self.settings = store.load()
    }

    func updateProfileName(_ value: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            nameWarning = "Name cannot be empty."
            return
        }

        if containsBlockedWord(trimmed) {
            nameWarning = "Name contains blocked language."
            return
        }

        if isNameResetExemption(trimmed) {
            settings.profileName = trimmed
            settings.nameChangeHistoryISO8601 = []
            nameWarning = nil
            store.save(settings)
            return
        }

        if !canChangeNameNow() {
            nameWarning = "Name can be changed only twice every 30 days."
            return
        }

        settings.profileName = trimmed
        appendNameChangeDate(Date())
        nameWarning = nil
        store.save(settings)
    }

    func setProfileImage(data: Data?) {
        guard let data else {
            settings.profileImageData = nil
            imageWarning = nil
            store.save(settings)
            return
        }

        Task {
            let containsProfanity = await imageContainsBlockedText(data)
            await MainActor.run {
                if containsProfanity {
                    self.imageWarning = "Profile image blocked by content filter."
                } else {
                    self.settings.profileImageData = data
                    self.imageWarning = nil
                    self.store.save(self.settings)
                }
            }
        }
    }

    func updateMusic(_ value: Double) {
        settings.musicVolume = value
        store.save(settings)
    }

    func updateFX(_ value: Double) {
        settings.fxVolume = value
        store.save(settings)
    }

    func updateHaptics(_ value: Bool) {
        settings.hapticsEnabled = value
        store.save(settings)
    }

    var nameCooldownMessage: String {
        let days = daysUntilNextNameChange()
        return "You have \(days) day\(days == 1 ? "" : "s") before you can change your name."
    }

    private func canChangeNameNow() -> Bool {
        let recent = nameChangeDates().filter { date in
            date > Date().addingTimeInterval(-30 * 24 * 60 * 60)
        }
        return recent.count < 2
    }

    private func daysUntilNextNameChange() -> Int {
        let threshold = Date().addingTimeInterval(-30 * 24 * 60 * 60)
        let recent = nameChangeDates()
            .filter { $0 > threshold }
            .sorted()

        guard recent.count >= 2, let earliestBlocking = recent.first else { return 0 }
        let unlockDate = earliestBlocking.addingTimeInterval(30 * 24 * 60 * 60)
        if unlockDate <= Date() { return 0 }
        let seconds = unlockDate.timeIntervalSinceNow
        return Int(ceil(seconds / (24 * 60 * 60)))
    }

    private func appendNameChangeDate(_ date: Date) {
        var dates = nameChangeDates()
        dates.append(date)
        settings.nameChangeHistoryISO8601 = dates.map { ISO8601DateFormatter().string(from: $0) }
    }

    private func nameChangeDates() -> [Date] {
        settings.nameChangeHistoryISO8601.compactMap { ISO8601DateFormatter().date(from: $0) }
    }

    private func containsBlockedWord(_ text: String) -> Bool {
        let lower = text.lowercased()
        return blockedWords.contains(where: { lower.contains($0) })
    }

    private func isNameResetExemption(_ text: String) -> Bool {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return normalized == "maysie" || normalized == "pete"
    }

    private func imageContainsBlockedText(_ data: Data) async -> Bool {
        guard let image = UIImage(data: data), let cgImage = image.cgImage else { return false }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true

        let handler = VNImageRequestHandler(cgImage: cgImage)
        do {
            try handler.perform([request])
            let text = request.results?
                .compactMap { $0.topCandidates(1).first?.string }
                .joined(separator: " ") ?? ""
            return containsBlockedWord(text)
        } catch {
            return false
        }
    }
}
