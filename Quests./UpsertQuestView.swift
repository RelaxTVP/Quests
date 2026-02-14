//
//  UpsertQuestView.swift
//  Quests.
//
//  Created by Miguel Carretas on 12/02/2026.
//

import SwiftUI

struct UpsertQuestView: View {
    enum ScheduleChoice: String, CaseIterable, Identifiable {
        case today
        case custom

        var id: String { rawValue }

        var titleKey: String {
            switch self {
            case .today:
                return "quest_schedule_today"
            case .custom:
                return "quest_schedule_custom"
            }
        }
    }

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var purchaseManager: PurchaseManager

    private let existing: AppQuest?
    var onSave: (AppQuest) -> Void

    @State private var title: String
    @State private var type: QuestType
    @State private var notes: String
    @State private var scheduleChoice: ScheduleChoice
    @State private var scheduledDate: Date
    @State private var recurrence: QuestRecurrence
    @State private var icon: QuestIcon
    @State private var showPremiumSheet = false

    init(quest: AppQuest? = nil, defaultDate: Date? = nil, onSave: @escaping (AppQuest) -> Void) {
        let today = Calendar.current.startOfDay(for: Date())
        let initialDate: Date = {
            if let ts = quest?.scheduledDate {
                return Calendar.current.startOfDay(for: Date(timeIntervalSince1970: ts))
            }
            if let defaultDate {
                return Calendar.current.startOfDay(for: defaultDate)
            }
            return today
        }()

        self.existing = quest
        self.onSave = onSave
        _title = State(initialValue: quest?.title ?? "")
        _type = State(initialValue: quest?.type ?? .daily)
        _notes = State(initialValue: quest?.notes ?? "")
        _scheduledDate = State(initialValue: initialDate)
        _scheduleChoice = State(initialValue: Calendar.current.isDate(initialDate, inSameDayAs: today) ? .today : .custom)
        _recurrence = State(initialValue: quest?.recurrence ?? .none)
        _icon = State(initialValue: quest?.icon ?? .flame)
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

                Section(header: Text(LocalizedStringKey("quest_schedule"))) {
                    Picker(LocalizedStringKey("quest_schedule"), selection: $scheduleChoice) {
                        ForEach(ScheduleChoice.allCases) { choice in
                            Text(LocalizedStringKey(choice.titleKey)).tag(choice)
                        }
                    }
                    .pickerStyle(.segmented)

                    if scheduleChoice == .custom {
                        DatePicker(
                            LocalizedStringKey("quest_schedule_date"),
                            selection: $scheduledDate,
                            displayedComponents: .date
                        )
                    }
                }

                Section(header: Text(LocalizedStringKey("quest_recurrence"))) {
                    Picker(LocalizedStringKey("quest_recurrence"), selection: $recurrence) {
                        ForEach(recurrenceOptions) { recurrence in
                            Text(recurrence.localized).tag(recurrence)
                        }
                    }
                    .pickerStyle(.segmented)

                    if purchaseManager.isPaywallEnabled && !purchaseManager.isPremiumUnlocked {
                        Button(LocalizedStringKey("premium_unlock_weekly")) {
                            showPremiumSheet = true
                        }
                    }
                }

                Section(header: Text(LocalizedStringKey("quest_icon"))) {
                    Picker(LocalizedStringKey("quest_icon"), selection: $icon) {
                        ForEach(iconOptions) { icon in
                            Label(LocalizedStringKey(icon.titleKey), systemImage: icon.symbolName).tag(icon)
                        }
                    }

                    if purchaseManager.isPaywallEnabled && !purchaseManager.isPremiumUnlocked {
                        Button(LocalizedStringKey("premium_unlock_icons")) {
                            showPremiumSheet = true
                        }
                    }
                }
            }
            .navigationTitle(existing == nil ? Text("new_quest") : Text("edit_quest"))
            .sheet(isPresented: $showPremiumSheet) {
                PremiumSheetView()
            }
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
                        let chosenDate = scheduleChoice == .today ? Calendar.current.startOfDay(for: Date()) : Calendar.current.startOfDay(for: scheduledDate)
                        quest.scheduledDate = chosenDate.timeIntervalSince1970
                        let finalRecurrence: QuestRecurrence = (purchaseManager.isPaywallEnabled && !purchaseManager.isPremiumUnlocked && recurrence.requiresPremium) ? .daily : recurrence
                        let finalIcon: QuestIcon = (purchaseManager.isPaywallEnabled && !purchaseManager.isPremiumUnlocked && icon.requiresPremium) ? .flame : icon
                        quest.recurrence = finalRecurrence
                        quest.icon = finalIcon

                        onSave(quest)
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private var recurrenceOptions: [QuestRecurrence] {
        if !purchaseManager.isPaywallEnabled { return QuestRecurrence.allCases }
        var options = QuestRecurrence.allCases.filter { !($0.requiresPremium && !purchaseManager.isPremiumUnlocked) }
        if !options.contains(recurrence) {
            options.append(recurrence)
        }
        return options
    }

    private var iconOptions: [QuestIcon] {
        if !purchaseManager.isPaywallEnabled { return QuestIcon.allCases }
        var options = QuestIcon.allCases.filter { !($0.requiresPremium && !purchaseManager.isPremiumUnlocked) }
        if !options.contains(icon) {
            options.append(icon)
        }
        return options
    }
}
