//
//  UpsertQuestView.swift
//  Quests.
//
//  Created by Miguel Carretas on 12/02/2026.
//

import SwiftUI

struct UpsertQuestView: View {
    @Environment(\.dismiss) private var dismiss

    private let existing: AppQuest?
    var onSave: (AppQuest) -> Void

    @State private var title: String
    @State private var type: QuestType
    @State private var notes: String

    init(quest: AppQuest? = nil, onSave: @escaping (AppQuest) -> Void) {
        self.existing = quest
        self.onSave = onSave
        _title = State(initialValue: quest?.title ?? "")
        _type = State(initialValue: quest?.type ?? .daily)
        _notes = State(initialValue: quest?.notes ?? "")
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text(NSLocalizedString("quest_details", comment: ""))) {
                    TextField(LocalizedStringKey("quest_title_placeholder"), text: $title)

                    Picker(LocalizedStringKey("quest_type"), selection: $type) {
                        ForEach(QuestType.allCases) { t in
                            Text(t.localized).tag(t)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section(header: Text(NSLocalizedString("notes", comment: ""))) {
                    TextField(LocalizedStringKey("notes_placeholder"), text: $notes, axis: .vertical)
                        .lineLimit(3...8)
                }
            }
            .navigationTitle(existing == nil ? Text("new_quest") : Text("edit_quest"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(LocalizedStringKey("cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(existing == nil ? LocalizedStringKey("add") : LocalizedStringKey("save")) {
                        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)

                        var quest = existing ?? AppQuest(title: trimmedTitle, type: type)
                        quest.title = trimmedTitle
                        quest.type = type
                        quest.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)

                        onSave(quest)
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
