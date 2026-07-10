import Foundation
import Combine

@MainActor
class StackService: ObservableObject {
    @Published var items: [StackItem] = []
    @Published var isLoading = false
    @Published var error: String?
    
    private let repository = LyoRepository.shared
    
    func fetchStackItems(status: StackItemStatus? = .active) async {
        isLoading = true
        do {
            let fetchedItems = try await repository.getStackItems(status: status)
            self.items = fetchedItems
            self.isLoading = false
        } catch {
            self.error = error.localizedDescription
            self.isLoading = false
        }
    }
    
    func createStackItem(type: StackItemType, refId: String, tags: [String]? = nil, contextData: [String: String]? = nil) async {
        let request = CreateStackItemRequest(
            type: type,
            refId: refId,
            title: contextData?["title"] ?? refId,
            tags: tags,
            contextData: contextData
        )
        do {
            let newItem = try await repository.createStackItem(request: request)
            self.items.insert(newItem, at: 0)
        } catch {
            self.error = error.localizedDescription
        }
    }
    
    func updateStackItem(id: String, pinned: Bool? = nil, status: StackItemStatus? = nil) async {
        let request = UpdateStackItemRequest(pinned: pinned, status: status)
        do {
            let updatedItem = try await repository.updateStackItem(id: id, request: request)
            if let index = self.items.firstIndex(where: { $0.id == id }) {
                self.items[index] = updatedItem
                // Remove if status changed to something other than active (assuming we only show active)
                if let status = status, status != .active {
                    self.items.remove(at: index)
                }
            }
        } catch {
            self.error = error.localizedDescription
        }
    }
}
