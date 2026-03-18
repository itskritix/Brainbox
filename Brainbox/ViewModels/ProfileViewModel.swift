import Foundation

@Observable
class ProfileViewModel {
    var profiles: [Profile] = []
    var activeProfile: Profile?
    var errorMessage: String?

    private let dataService: DataServiceProtocol

    var activeProfileId: String? {
        activeProfile?.id
    }

    init(dataService: DataServiceProtocol) {
        self.dataService = dataService
        refresh()
        restoreActiveProfile()
    }

    func refresh() {
        profiles = dataService.fetchProfiles()

        if let active = activeProfile,
           !profiles.contains(where: { $0.id == active.id }) {
            activeProfile = nil
            UserDefaults.standard.removeObject(forKey: UDKey.activeProfileId)
        }
    }

    func setActiveProfile(_ profile: Profile?) {
        activeProfile = profile
        if let profile {
            UserDefaults.standard.set(profile.id, forKey: UDKey.activeProfileId)
        } else {
            UserDefaults.standard.removeObject(forKey: UDKey.activeProfileId)
        }
    }

    func createProfile(name: String, emoji: String) -> String? {
        let profile = dataService.createProfile(name: name, emoji: emoji)
        refresh()
        errorMessage = nil
        return profile.id
    }

    func deleteProfile(id: String) {
        if activeProfile?.id == id {
            setActiveProfile(nil)
        }
        dataService.deleteProfile(id: id)
        refresh()
        errorMessage = nil
    }

    func renameProfile(id: String, name: String) {
        dataService.renameProfile(id: id, name: name)
        refresh()
        errorMessage = nil
    }

    private func restoreActiveProfile() {
        if let activeId = UserDefaults.standard.string(forKey: UDKey.activeProfileId),
           let match = profiles.first(where: { $0.id == activeId }) {
            activeProfile = match
        }
    }
}
