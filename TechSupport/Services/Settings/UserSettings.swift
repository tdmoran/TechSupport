import Foundation

@Observable
@MainActor
final class UserSettings {
    // MARK: - Storage Keys

    private enum Keys {
        static let refreshInterval = "userSettings.refreshInterval"
        static let historySize = "userSettings.historySize"
        static let preferredModel = "userSettings.preferredModel"
    }

    // MARK: - Defaults

    static let defaultRefreshInterval: Int = Int(AppConstants.monitorRefreshInterval)
    static let defaultHistorySize: Int = AppConstants.metricsHistoryCount
    static let defaultPreferredModel: ClaudeModel = AppConstants.defaultModel

    static let refreshIntervalRange = 1...10
    static let historySizeRange = 10...120

    // MARK: - Published Properties

    var refreshInterval: Int {
        didSet { UserDefaults.standard.set(refreshInterval, forKey: Keys.refreshInterval) }
    }

    var historySize: Int {
        didSet { UserDefaults.standard.set(historySize, forKey: Keys.historySize) }
    }

    var preferredModel: ClaudeModel {
        didSet { UserDefaults.standard.set(preferredModel.rawValue, forKey: Keys.preferredModel) }
    }

    // MARK: - Init

    init() {
        let defaults = UserDefaults.standard

        if defaults.object(forKey: Keys.refreshInterval) != nil {
            self.refreshInterval = defaults.integer(forKey: Keys.refreshInterval)
        } else {
            self.refreshInterval = Self.defaultRefreshInterval
        }

        if defaults.object(forKey: Keys.historySize) != nil {
            self.historySize = defaults.integer(forKey: Keys.historySize)
        } else {
            self.historySize = Self.defaultHistorySize
        }

        if let modelString = defaults.string(forKey: Keys.preferredModel),
           let model = ClaudeModel(rawValue: modelString) {
            self.preferredModel = model
        } else {
            self.preferredModel = Self.defaultPreferredModel
        }
    }

    // MARK: - Reset

    func resetToDefaults() {
        refreshInterval = Self.defaultRefreshInterval
        historySize = Self.defaultHistorySize
        preferredModel = Self.defaultPreferredModel
    }
}
