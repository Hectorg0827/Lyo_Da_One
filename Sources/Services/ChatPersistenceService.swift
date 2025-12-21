import Foundation
import SwiftData

@MainActor
@available(iOS 17.0, *)
class ChatPersistenceService: ObservableObject {
    static let shared = ChatPersistenceService()
    
    var container: ModelContainer?
    
    private init() {
        do {
            let schema = Schema([
                ChatFolder.self,
                ChatSession.self
            ])
            let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            self.container = try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            print("❌ Failed to create ModelContainer: \(error)")
        }
    }
    
    // MARK: - CRUD Operations
    
    func createFolder(name: String, icon: String = "folder") {
        guard let context = container?.mainContext else { return }
        let folder = ChatFolder(name: name, icon: icon)
        context.insert(folder)
    }
    
    func createSession(title: String, message: String, folder: ChatFolder?) {
        guard let context = container?.mainContext else { return }
        let session = ChatSession(title: title, lastMessage: message)
        session.folder = folder
        context.insert(session)
    }
    
    func deleteSession(_ session: ChatSession) {
        guard let context = container?.mainContext else { return }
        context.delete(session)
    }
    
    func deleteFolder(_ folder: ChatFolder) {
        guard let context = container?.mainContext else { return }
        context.delete(folder)
    }
    
    func togglePin(_ session: ChatSession) {
        session.isPinned.toggle()
        // Context autosaves
    }
    
    // MARK: - Mock Seeding (For testing)
    func seedMockDataIfNeeded() {
        guard let context = container?.mainContext else { return }
        
        do {
            let descriptor = FetchDescriptor<ChatFolder>()
            let count = try context.fetchCount(descriptor)
            
            if count == 0 {
                // Seed Folders
                let physics = ChatFolder(name: "Physics Help", icon: "atom")
                let essays = ChatFolder(name: "Essay Drafts", icon: "doc.text")
                let coding = ChatFolder(name: "Coding", icon: "terminal.fill")
                
                context.insert(physics)
                context.insert(essays)
                context.insert(coding)
                
                // Seed Sessions
                let s1 = ChatSession(title: "Kinematics Problems", lastMessage: "Explain the formula for velocity...", timestamp: Date())
                s1.folder = physics
                
                let s2 = ChatSession(title: "History Essay Outline", lastMessage: "Help with Civil War topics", timestamp: Date().addingTimeInterval(-3600))
                s2.folder = essays
                
                let s3 = ChatSession(title: "General Chat", lastMessage: "Tell me a fun fact", timestamp: Date().addingTimeInterval(-86400))
                
                context.insert(s1)
                context.insert(s2)
                context.insert(s3)
                
                print("🌱 Seeded mock chat data")
            }
        } catch {
            print("❌ Seeding failed: \(error)")
        }
    }
}
