import Foundation
import Combine

class StackService: ObservableObject {
    @Published var items: [StackItem] = []
    @Published var isLoading = false
    @Published var error: String?
    
    private let repository = LyoRepository.shared
    
    func fetchStackItems(status: StackItemStatus? = .active) async {
        await MainActor.run { isLoading = true }
        do {
            let fetchedItems = try await repository.getStackItems(status: status)
            await MainActor.run {
                self.items = fetchedItems
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    func createStackItem(type: StackItemType, refId: String, tags: [String]? = nil, contextData: [String: String]? = nil) async {
        let request = CreateStackItemRequest(type: type, refId: refId, tags: tags, contextData: contextData)
        do {
            let newItem = try await repository.createStackItem(request: request)
            await MainActor.run {
                self.items.insert(newItem, at: 0)
            }
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
            }
        }
    }
    
    func updateStackItem(id: String, pinned: Bool? = nil, status: StackItemStatus? = nil) async {
        let request = UpdateStackItemRequest(pinned: pinned, status: status)
        do {
            let updatedItem = try await repository.updateStackItem(id: id, request: request)
            await MainActor.run {
                if let index = self.items.firstIndex(where: { $0.id == id }) {
                    self.items[index] = updatedItem
                    // Remove if status changed to something other than active (assuming we only show active)
                    if let status = status, status != .active {
                        self.items.remove(at: index)
                    }
                }
            }
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
            }
        }
    }
}
