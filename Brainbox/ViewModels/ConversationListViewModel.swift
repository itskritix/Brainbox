import Foundation

@Observable
class ConversationListViewModel {
    var conversations: [Conversation] = []
    var archivedConversations: [Conversation] = []
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
        archivedConversations = dataService.fetchArchivedConversations(profileId: profileId)
        errorMessage = nil
    }

    func fetchArchivedConversations(profileId: String? = nil) -> [Conversation] {
        dataService.fetchArchivedConversations(profileId: profileId)
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

    func archiveConversation(id: String) {
        dataService.archiveConversation(id: id)
        refresh()
        errorMessage = nil
    }

    func unarchiveConversation(id: String) {
        dataService.unarchiveConversation(id: id)
        refresh()
        errorMessage = nil
    }
}
