import Foundation
import Observation

@Observable
final class QuestStore {
    var quests: [AppQuest] = []
    
    private let fileURL: URL
    
    init() {
        let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appFolder = folder.appendingPathComponent("QuestReminder", isDirectory: true)
        try? FileManager.default.createDirectory(at: appFolder, withIntermediateDirectories: true)
        
        self.fileURL = appFolder.appendingPathComponent("quests.json")
        load()
    }
    
    func add(_ quest: AppQuest) {
        quests.append(quest)
        save()
    }
    
    func toggle(_ questID: UUID) {
        guard let idx = quests.firstIndex(where: { $0.id == questID }) else { return }

        quests[idx].completed.toggle()

        if quests[idx].completed {
            quests[idx].completedAt = Date().timeIntervalSince1970
        } else {
            quests[idx].completedAt = nil
            quests[idx].archived = false // opcional: se desmarca, garante que não fica “arquivada”
        }

        save()
    }

    
    func delete(_ offsets: IndexSet, type: QuestType) {
        let filtered = quests.enumerated().filter { $0.element.type == type }
        for offset in offsets {
            quests.remove(at: filtered[offset].offset)
        }
        save()
    }
    func deleteQuest(_ id: UUID) {
        quests.removeAll { $0.id == id }
        save()
    }

    func update(_ quest: AppQuest) {
        guard let idx = quests.firstIndex(where: { $0.id == quest.id }) else { return }
        quests[idx] = quest
        save()
    }

    
    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        
        do {
            let data = try Data(contentsOf: fileURL)
            quests = try JSONDecoder().decode([AppQuest].self, from: data)
        } catch {
            print("Load error:", error.localizedDescription)
            quests = []
        }
    }
    
    private func save() {
        do {
            let data = try JSONEncoder().encode(quests)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            print("Save error:", error.localizedDescription)
        }
    }
    func forceSave() {
        save()
    }
    
}
