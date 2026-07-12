import Data
public import Domain
public import FactoryKit

/// Player preferences wiring.
public extension Container {
    var settingsRepository: Factory<any SettingsRepository> {
        self { UserDefaultsSettingsRepository() }
            .singleton
    }
}
