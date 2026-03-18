import Foundation

@Observable
class ConversationListViewModel {
    var conversations: [Conversation] = []
    var errorMessage: String?

    private(set) var profileId: String?
    private let dataService: DataServiceProtocol

    init(dataService: DataServiceProtocol) {
        self.dataService = dataService
    }

    func setProfileId(_ id: String?) {
        guard profileId != id else { return }
        profileId = id
        refresh()
    }

    func refresh() {
        conversations = dataService.fetchConversations(profileId: profileId)
        errorMessage = nil
    }

    func createConversation() -> String? {
        let conv = dataService.createConversation(title: nil, profileId: profileId)
        refresh()
        errorMessage = nil
        return conv.id
    }

    func deleteConversation(id: String) {
        dataService.deleteConversation(id: id)
        refresh()
        errorMessage = nil
    }

    func renameConversation(id: String, title: String) {
        dataService.renameConversation(id: id, title: title)
        refresh()
        errorMessage = nil
    }
}
