//
//  ContentView.swift
//  QuestReminder
//
//  Created by Miguel Carretas on 10/02/2026.
//

import SwiftUI

enum QuestType: String, CaseIterable, Identifiable, Codable {
    case daily = "type_daily"
    case weekly = "type_weekly"
    var id: String { rawValue }
}

extension QuestType {
    var localized: String {
        NSLocalizedString(rawValue, comment: "")
    }
}

enum QuestRecurrence: String, CaseIterable, Identifiable, Codable {
    case none = "quest_repeat_none"
    case daily = "quest_repeat_daily"
    case weekly = "quest_repeat_weekly"

    var id: String { rawValue }

    var localized: String {
        NSLocalizedString(rawValue, comment: "")
    }

    var requiresPremium: Bool {
        switch self {
        case .none, .daily:
            return false
        case .weekly:
            return true
        }
    }
}

enum QuestIcon: String, CaseIterable, Identifiable, Codable {
    case flame = "flame.fill"
    case star = "star.fill"
    case bolt = "bolt.fill"
    case book = "book.fill"
    case trophy = "trophy.fill"
    case leaf = "leaf.fill"

    var id: String { rawValue }

    var symbolName: String { rawValue }

    var requiresPremium: Bool {
        self != .flame
    }

    var titleKey: String {
        switch self {
        case .flame:
            return "quest_icon_flame"
        case .star:
            return "quest_icon_star"
        case .bolt:
            return "quest_icon_bolt"
        case .book:
            return "quest_icon_book"
        case .trophy:
            return "quest_icon_trophy"
        case .leaf:
            return "quest_icon_leaf"
        }
    }
}

enum AppearanceMode: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var colorScheme: ColorScheme? {
        switch self {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }

    var titleKey: String {
        switch self {
        case .system:
            return "theme_system"
        case .light:
            return "theme_light"
        case .dark:
            return "theme_dark"
        }
    }
}

struct AppQuest: Identifiable, Codable {
    var id: UUID = UUID()
    var title: String
    var type: QuestType
    var notes: String = ""
    var scheduledDate: Double? = nil // start-of-day timestamp
    var recurrence: QuestRecurrence = .none
    var icon: QuestIcon = .flame
    var completed: Bool = false
    var archived: Bool = false
    var deleted: Bool = false
    var completedAt: Double? = nil // timestamp

}

struct ContentView: View {
    
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var purchaseManager: PurchaseManager

    enum SidebarItem: Hashable {
        case home, archive, deleted, settings, bug
    }
    enum HomeTab: Hashable {
        case quests, calendar
    }
    enum PlannerFilter: String, CaseIterable, Identifiable {
        case all = "planner_filter_all"
        case daily = "planner_filter_daily"
        case weekly = "planner_filter_weekly"
        case pending = "planner_filter_pending"
        case completed = "planner_filter_completed"

        var id: String { rawValue }
    }
    private var isPhone: Bool { UIDevice.current.userInterfaceIdiom == .phone }
    @State private var phonePath: [SidebarItem] = []
    @State private var didAutoOpenHome = false
    @State private var selectedHomeTab: HomeTab = .quests
    @State private var planningDate: Date = Calendar.current.startOfDay(for: Date())
    @State private var addQuestDefaultDate: Date? = Calendar.current.startOfDay(for: Date())
    @State private var plannerFilter: PlannerFilter = .all
    @State private var showPremiumSheet = false


    @State private var selectedItem: SidebarItem = .home
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    @State private var store = QuestStore()

    @State private var editingQuest: AppQuest?

    @State private var showAddQuest = false
    @State private var showDaily = true
    @State private var showWeekly = true

    @State private var celebrateDaily = false
    @State private var celebrateWeekly = false
    
    @AppStorage("dailyStreak") private var dailyStreak: Int = 0
    @AppStorage("weeklyStreak") private var weeklyStreak: Int = 0
    @AppStorage("appearanceMode") private var appearanceMode: String = AppearanceMode.system.rawValue

    @AppStorage("lastDailyCompletion") private var lastDailyCompletionTime: Double = 0
    @AppStorage("lastWeeklyCompletion") private var lastWeeklyCompletionTime: Double = 0
    
    // Daily rollback
    @AppStorage("dailyRollbackPeriod") private var dailyRollbackPeriod: Double = 0
    @AppStorage("dailyRollbackStreak") private var dailyRollbackStreak: Int = 0
    @AppStorage("dailyRollbackLastCompletion") private var dailyRollbackLastCompletionTime: Double = 0

    // Weekly rollback
    @AppStorage("weeklyRollbackPeriodKey") private var weeklyRollbackPeriodKey: Int = 0
    @AppStorage("weeklyRollbackStreak") private var weeklyRollbackStreak: Int = 0
    @AppStorage("weeklyRollbackLastCompletion") private var weeklyRollbackLastCompletionTime: Double = 0

    


    private var lastDailyCompletion: Date? {
        lastDailyCompletionTime > 0 ? Date(timeIntervalSince1970: lastDailyCompletionTime) : nil
    }

    private var lastWeeklyCompletion: Date? {
        lastWeeklyCompletionTime > 0 ? Date(timeIntervalSince1970: lastWeeklyCompletionTime) : nil
    }
    
    private func todayKey() -> Double {
        Calendar.current.startOfDay(for: Date()).timeIntervalSince1970
    }

    private func currentWeekKey() -> Int {
        let cal = Calendar.current
        let now = Date()
        let w = cal.component(.weekOfYear, from: now)
        let y = cal.component(.yearForWeekOfYear, from: now)
        return y * 100 + w
    }

    private func isToday(_ date: Date?) -> Bool {
        guard let date else { return false }
        return Calendar.current.isDate(date, inSameDayAs: Date())
    }

    private func isThisWeek(_ date: Date?) -> Bool {
        guard let date else { return false }
        let cal = Calendar.current
        return cal.component(.weekOfYear, from: date) == cal.component(.weekOfYear, from: Date())
            && cal.component(.yearForWeekOfYear, from: date) == cal.component(.yearForWeekOfYear, from: Date())
    }


    private var menuRootList: some View {
        List {
            Button {
                phonePath = [.home]
            } label: {
                Label(NSLocalizedString("menu_home", comment: ""), systemImage: "house")
            }

            Button {
                phonePath = [.archive]
            } label: {
                Label(NSLocalizedString("menu_archive", comment: ""), systemImage: "archivebox")
            }

            Button {
                phonePath = [.deleted]
            } label: {
                Label(NSLocalizedString("menu_deleted", comment: ""), systemImage: "trash")
            }

            Section {
                Button {
                    phonePath = [.settings]
                } label: {
                    Label(NSLocalizedString("menu_settings", comment: ""), systemImage: "gear")
                }

                Button {
                    phonePath = [.bug]
                } label: {
                    Label(NSLocalizedString("menu_bug", comment: ""), systemImage: "ladybug")
                }
            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
    }


    var body: some View {
        ZStack {
            if isPhone {
                NavigationStack(path: $phonePath) {
                    menuRootList
                        .navigationTitle(Text(NSLocalizedString("menu_title", comment: "")))
                        .navigationDestination(for: SidebarItem.self) { item in
                            switch item {
                            case .home: homeView
                            case .archive: archiveView
                            case .deleted: deletedView
                            case .settings: settingsView
                            case .bug: bugReportView
                            }
                        }
                        .onAppear {
                            if !didAutoOpenHome {
                                phonePath = [.home]
                                didAutoOpenHome = true
                            }
                        }

                }
            } else {
                // iPad mantém SplitView
                NavigationSplitView(columnVisibility: $columnVisibility) {
                    sidebarList()
                        .navigationTitle(Text(NSLocalizedString("menu_title", comment: "")))
                } detail: {
                    NavigationStack { currentDetailView }
                }
            }



            if celebrateDaily {
                CelebrationView(titleKey: "daily_complete") { celebrateDaily = false }
            }

            if celebrateWeekly {
                CelebrationView(titleKey: "weekly_complete") { celebrateWeekly = false }
            }
        }
        .sheet(isPresented: $showAddQuest) {
            UpsertQuestView(defaultDate: addQuestDefaultDate) { newQuest in store.add(newQuest) }
        }
        .sheet(item: $editingQuest) { original in
            UpsertQuestView(quest: original) { updated in
                var fixed = updated
                if updated.type != original.type { fixed.completed = false }
                store.update(fixed)
            }
        }
        .onChange(of: scenePhase, initial: true) { _, newPhase in
            if newPhase == .active {
                validateStreaksOnLaunchOrResume()
                archiveIfNeeded()
            } else {
                store.forceSave()
            }
        }
    }
    private struct PhoneMenuView: View {
        @Environment(\.dismiss) private var dismiss

        @Binding var selectedItem: ContentView.SidebarItem

        var body: some View {
            List {
                Button {
                    selectedItem = .home
                    dismiss()
                } label: {
                    Label(NSLocalizedString("menu_home", comment: ""), systemImage: "house")
                }

                Button {
                    selectedItem = .archive
                    dismiss()
                } label: {
                    Label(NSLocalizedString("menu_archive", comment: ""), systemImage: "archivebox")
                }

                Button {
                    selectedItem = .deleted
                    dismiss()
                } label: {
                    Label(NSLocalizedString("menu_deleted", comment: ""), systemImage: "trash")
                }

                Section {
                    Button {
                        selectedItem = .settings
                        dismiss()
                    } label: {
                        Label(NSLocalizedString("menu_settings", comment: ""), systemImage: "gear")
                    }

                    Button {
                        selectedItem = .bug
                        dismiss()
                    } label: {
                        Label(NSLocalizedString("menu_bug", comment: ""), systemImage: "ladybug")
                    }
                }
            }
            .navigationTitle(Text(NSLocalizedString("menu_title", comment: "")))
            .buttonStyle(.plain)
            .foregroundStyle(.primary)
        }
    }


    @ViewBuilder
    private var currentDetailView: some View {
        switch selectedItem {
        case .home: homeView
        case .archive: archiveView
        case .deleted: deletedView
        case .settings: settingsView
        case .bug: bugReportView
        }
    }

    @ViewBuilder
    private func sidebarList() -> some View {
        List {
            sidebarButton(.home, titleKey: "menu_home", systemImage: "house")
            sidebarButton(.archive, titleKey: "menu_archive", systemImage: "archivebox")
            sidebarButton(.deleted, titleKey: "menu_deleted", systemImage: "trash")

            Section {
                sidebarButton(.settings, titleKey: "menu_settings", systemImage: "gear")
                sidebarButton(.bug, titleKey: "menu_bug", systemImage: "ladybug")
            }
        }
    }


    private func sidebarButton(_ item: SidebarItem, titleKey: String, systemImage: String) -> some View {
        Button {
            selectedItem = item
        } label: {
            Label(NSLocalizedString(titleKey, comment: ""), systemImage: systemImage)
        }
        .buttonStyle(.plain)
    }



   

    private var settingsView: some View {
        Form {
            Section(LocalizedStringKey("settings_appearance")) {
                Picker(LocalizedStringKey("settings_theme"), selection: $appearanceMode) {
                    ForEach(AppearanceMode.allCases) { mode in
                        Text(LocalizedStringKey(mode.titleKey)).tag(mode.rawValue)
                    }
                }
                .pickerStyle(.segmented)
            }

            if purchaseManager.isPaywallEnabled {
                Section(LocalizedStringKey("premium_section_title")) {
                    HStack {
                        Text(LocalizedStringKey("premium_lifetime_label"))
                        Spacer()
                        Text(purchaseManager.isPremiumUnlocked ? LocalizedStringKey("premium_unlocked_short") : LocalizedStringKey("premium_locked_short"))
                            .foregroundStyle(purchaseManager.isPremiumUnlocked ? .green : .secondary)
                    }

                    if !purchaseManager.isPremiumUnlocked {
                        Button {
                            showPremiumSheet = true
                        } label: {
                            Text(LocalizedStringKey("premium_unlock_button"))
                        }
                    }
                }
            }
        }
        .navigationTitle(Text("menu_settings"))
        .sheet(isPresented: $showPremiumSheet) {
            PremiumSheetView()
        }
    }

    private var bugReportView: some View {
        BugReportView()
    }

    private var archiveView: some View {
        List {
            ForEach(store.quests.filter { $0.archived && !$0.deleted }) { quest in
                VStack(alignment: .leading, spacing: 4) {
                    Text(quest.title)
                        .font(.headline)

                    if !quest.notes.isEmpty {
                        Text(quest.notes)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                .padding(.vertical, 4)

                // SWIPE ACTIONS
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {

                    Button(role: .destructive) {
                        store.markDeleted(quest.id)
                    } label: {
                        Label("delete", systemImage: "trash")
                    }

                    // Restaurar para Home
                    Button {
                        var q = quest
                        q.archived = false
                        q.completed = false
                        q.completedAt = nil
                        store.update(q)
                    } label: {
                        Label("restore", systemImage: "arrow.uturn.backward")
                    }
                    .tint(.blue)
                }
            }
        }
        .navigationTitle(Text("menu_archive"))
    }

    private var deletedView: some View {
        List {
            let deletedQuests = store.quests.filter { $0.deleted }
            if deletedQuests.isEmpty {
                Text(LocalizedStringKey("deleted_empty"))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(deletedQuests) { quest in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(quest.title)
                            .font(.headline)

                        Text(scheduleLabel(for: quest))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            store.permanentlyDeleteQuest(quest.id)
                        } label: {
                            Label("delete_permanently", systemImage: "trash.fill")
                        }

                        Button {
                            store.restoreDeleted(quest.id)
                        } label: {
                            Label("restore", systemImage: "arrow.uturn.backward")
                        }
                        .tint(.green)
                    }
                }
            }
        }
        .navigationTitle(Text("menu_deleted"))
    }


    
    private var homeView: some View {
        VStack(spacing: 12) {
            if selectedHomeTab == .quests {
                HStack(spacing: 16) {
                    streakBadge(
                        title: "daily_streak",
                        count: dailyStreak,
                        icon: "flame.fill",
                        color: .orange
                    )

                    streakBadge(
                        title: "weekly_streak",
                        count: weeklyStreak,
                        icon: "bolt.fill",
                        color: .purple
                    )
                }
                .padding(.horizontal)

                List {
                    Section(header: sectionHeaderKey("daily_quests", isExpanded: $showDaily, type: .daily)) {
                        if showDaily {
                            if dailyQuests.isEmpty {
                                Text(LocalizedStringKey("home_no_daily_quests"))
                                    .foregroundStyle(.secondary)
                            } else {
                                ForEach(dailyQuests) { quest in
                                    questRow(for: quest)
                                }
                            }
                        }
                    }

                    Section(header: sectionHeaderKey("weekly_quests", isExpanded: $showWeekly, type: .weekly)) {
                        if showWeekly {
                            if weeklyQuests.isEmpty {
                                Text(LocalizedStringKey("home_no_weekly_quests"))
                                    .foregroundStyle(.secondary)
                            } else {
                                ForEach(weeklyQuests) { quest in
                                    questRow(for: quest)
                                }
                            }
                        }
                    }

                    if dailyQuests.isEmpty && weeklyQuests.isEmpty {
                        Section {
                            VStack(alignment: .leading, spacing: 10) {
                                Text(LocalizedStringKey("home_no_quests_due"))
                                    .foregroundStyle(.secondary)

                                Button {
                                    addQuestDefaultDate = Calendar.current.startOfDay(for: Date())
                                    showAddQuest = true
                                } label: {
                                    Label(LocalizedStringKey("home_add_first_quest"), systemImage: "plus.circle.fill")
                                }
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .animation(.spring(), value: showDaily)
                .animation(.spring(), value: showWeekly)
            } else {
                calendarPlannerView
            }
        }
        .navigationTitle(Text(NSLocalizedString("app_title", comment: "")))
        .toolbar {
            Button {
                addQuestDefaultDate = selectedHomeTab == .calendar
                    ? Calendar.current.startOfDay(for: planningDate)
                    : Calendar.current.startOfDay(for: Date())
                showAddQuest = true
            } label: {
                Image(systemName: "plus")
            }
        }
        .safeAreaInset(edge: .bottom) {
            homeBottomBar
        }
    }


    // MARK: - Computed helpers

    var dailyQuests: [AppQuest] {
        store.quests
            .filter { $0.type == .daily && !$0.archived && !$0.deleted && isQuestDueForHome($0) }
            .sorted { !$0.completed && $1.completed }
    }

    var weeklyQuests: [AppQuest] {
        store.quests
            .filter { $0.type == .weekly && !$0.archived && !$0.deleted && isQuestDueForHome($0) }
            .sorted { !$0.completed && $1.completed }
    }



    var dailyCompleted: Bool {
        !dailyQuests.isEmpty && dailyQuests.allSatisfy { $0.completed }
    }

    var weeklyCompleted: Bool {
        !weeklyQuests.isEmpty && weeklyQuests.allSatisfy { $0.completed }
    }

    // MARK: - Views

    func questRow(for quest: AppQuest, isInteractive: Bool = true) -> some View {

        HStack(spacing: 12) {
            Image(systemName: quest.completed ? "checkmark.seal.fill" : quest.icon.symbolName)
                .foregroundColor(quest.completed ? .green : .orange)
                .font(.title3)

            VStack(alignment: .leading, spacing: 4) {
                Text(quest.title)
                    .fontWeight(.medium)
                    .strikethrough(quest.completed)
                    .foregroundColor(quest.completed ? .secondary : .primary)

                HStack(spacing: 8) {
                    Text(scheduleLabel(for: quest))
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    if quest.recurrence != .none {
                        Label(quest.recurrence.localized, systemImage: "repeat")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                if !quest.notes.isEmpty {
                    Text(quest.notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }


            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .shadow(radius: quest.completed ? 0 : 4)
        )
        .onTapGesture {
            guard isInteractive else { return }
            withAnimation(.spring()) {
                toggleQuest(quest)
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                store.markDeleted(quest.id)
            } label: {
                Label("delete", systemImage: "trash")
            }

            Button {
                editingQuest = quest
            } label: {
                Label("edit", systemImage: "pencil")
            }
            .tint(.blue)
        }


    }

    private var calendarPlannerView: some View {
        List {
            Section {
                DatePicker(
                    LocalizedStringKey("planner_selected_date"),
                    selection: $planningDate,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)

                weekIndicatorsView

                Picker(LocalizedStringKey("planner_filter"), selection: $plannerFilter) {
                    ForEach(PlannerFilter.allCases) { filter in
                        Text(LocalizedStringKey(filter.rawValue)).tag(filter)
                    }
                }
                .pickerStyle(.menu)

                Button {
                    addQuestDefaultDate = Calendar.current.startOfDay(for: planningDate)
                    showAddQuest = true
                } label: {
                    Label(LocalizedStringKey("planner_add_for_date"), systemImage: "plus.circle.fill")
                }
            }

            Section(header: Text(LocalizedStringKey("planner_quests_for_date"))) {
                let dayQuests = quests(for: planningDate)

                if dayQuests.isEmpty {
                    Text(LocalizedStringKey("planner_no_quests_for_date"))
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(dayQuests) { quest in
                        questRow(for: quest, isInteractive: isDateInPastOrToday(planningDate))
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private var homeBottomBar: some View {
        HStack(spacing: 12) {
            homeTabButton(
                titleKey: "home_tab_quests",
                systemImage: "list.bullet",
                tab: .quests
            )

            homeTabButton(
                titleKey: "home_tab_calendar",
                systemImage: "calendar",
                tab: .calendar
            )
        }
        .padding(10)
        .background(.ultraThinMaterial, in: Capsule())
        .padding(.horizontal)
        .padding(.top, 8)
    }

    private var weekIndicatorsView: some View {
        let days = weekDates(around: planningDate)
        return VStack(alignment: .leading, spacing: 8) {
            Text(LocalizedStringKey("planner_week_overview"))
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                ForEach(days, id: \.self) { day in
                    let total = plannedQuestCount(on: day)
                    let completed = completedQuestCount(on: day)
                    let selected = Calendar.current.isDate(day, inSameDayAs: planningDate)
                    Button {
                        planningDate = Calendar.current.startOfDay(for: day)
                    } label: {
                        VStack(spacing: 4) {
                            Text(day, format: .dateTime.weekday(.narrow))
                                .font(.caption2)
                            Text(day, format: .dateTime.day())
                                .font(.caption)
                                .fontWeight(.semibold)
                            Text("\(completed)/\(total)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(selected ? Color.accentColor.opacity(0.2) : Color.clear)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func homeTabButton(titleKey: String, systemImage: String, tab: HomeTab) -> some View {
        Button {
            selectedHomeTab = tab
            addQuestDefaultDate = tab == .calendar
                ? Calendar.current.startOfDay(for: planningDate)
                : Calendar.current.startOfDay(for: Date())
        } label: {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                Text(LocalizedStringKey(titleKey))
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(selectedHomeTab == tab ? Color.accentColor.opacity(0.2) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }

    private func scheduledDay(for quest: AppQuest) -> Date {
        let timestamp = quest.scheduledDate ?? Calendar.current.startOfDay(for: Date()).timeIntervalSince1970
        return Calendar.current.startOfDay(for: Date(timeIntervalSince1970: timestamp))
    }

    private func weekDates(around date: Date) -> [Date] {
        let calendar = Calendar.current
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: date) else {
            return [calendar.startOfDay(for: date)]
        }
        return (0..<7).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: interval.start)
        }
    }

    private func plannedQuestCount(on date: Date) -> Int {
        let day = Calendar.current.startOfDay(for: date)
        return store.quests.filter {
            !$0.deleted && !$0.archived && Calendar.current.isDate(scheduledDay(for: $0), inSameDayAs: day)
        }.count
    }

    private func completedQuestCount(on date: Date) -> Int {
        let day = Calendar.current.startOfDay(for: date)
        return store.quests.filter {
            !$0.deleted && !$0.archived && $0.completed && Calendar.current.isDate(scheduledDay(for: $0), inSameDayAs: day)
        }.count
    }

    private func scheduleLabel(for quest: AppQuest) -> String {
        let day = scheduledDay(for: quest)
        if Calendar.current.isDateInToday(day) {
            return NSLocalizedString("quest_date_today", comment: "")
        }
        return DateFormatter.localizedString(from: day, dateStyle: .medium, timeStyle: .none)
    }

    private func isQuestDueForHome(_ quest: AppQuest) -> Bool {
        let today = Calendar.current.startOfDay(for: Date())
        return scheduledDay(for: quest) <= today
    }

    private func isDateInPastOrToday(_ date: Date) -> Bool {
        Calendar.current.startOfDay(for: date) <= Calendar.current.startOfDay(for: Date())
    }

    private func quests(for date: Date) -> [AppQuest] {
        let target = Calendar.current.startOfDay(for: date)
        return store.quests
            .filter { !$0.archived && !$0.deleted && Calendar.current.isDate(scheduledDay(for: $0), inSameDayAs: target) }
            .filter { quest in
                switch plannerFilter {
                case .all:
                    return true
                case .daily:
                    return quest.type == .daily
                case .weekly:
                    return quest.type == .weekly
                case .pending:
                    return !quest.completed
                case .completed:
                    return quest.completed
                }
            }
            .sorted { left, right in
                if left.completed != right.completed {
                    return !left.completed && right.completed
                }
                if left.type != right.type {
                    return left.type.rawValue < right.type.rawValue
                }
                return left.title.localizedCaseInsensitiveCompare(right.title) == .orderedAscending
            }
    }


    func sectionHeaderKey(_ key: String, isExpanded: Binding<Bool>, type: QuestType) -> some View {
        Button {
            withAnimation {
                isExpanded.wrappedValue.toggle()
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text(NSLocalizedString(key, comment: ""))
                        .font(.headline)

                    ProgressView(value: progress(for: type))
                        .tint(.green)
                }

                Spacer()

                Image(systemName: "chevron.down")
                    .rotationEffect(.degrees(isExpanded.wrappedValue ? 0 : -90))
            }
        }
        .foregroundColor(.primary)
    }
    private func rollbackDailyIfNeeded() {
        guard dailyRollbackPeriod == todayKey() else { return }
        guard isToday(lastDailyCompletion) else { return }

        dailyStreak = dailyRollbackStreak
        lastDailyCompletionTime = dailyRollbackLastCompletionTime

        dailyRollbackPeriod = 0
    }

    private func rollbackWeeklyIfNeeded() {
        guard weeklyRollbackPeriodKey == currentWeekKey() else { return }
        guard isThisWeek(lastWeeklyCompletion) else { return }

        weeklyStreak = weeklyRollbackStreak
        lastWeeklyCompletionTime = weeklyRollbackLastCompletionTime

        weeklyRollbackPeriodKey = 0
    }

    func archiveIfNeeded() {
        let cal = Calendar.current
        let now = Date()

        for index in store.quests.indices {
            guard store.quests[index].completed,
                  let completedAt = store.quests[index].completedAt,
                  !store.quests[index].deleted,
                  !store.quests[index].archived
            else { continue }

            let completedDate = Date(timeIntervalSince1970: completedAt)

            switch store.quests[index].type {
            case .daily:
                let days = cal.dateComponents([.day], from: cal.startOfDay(for: completedDate),
                                              to: cal.startOfDay(for: now)).day ?? 0
                if days >= 1 {
                    store.quests[index].archived = true
                }

            case .weekly:
                let weekNow = cal.component(.weekOfYear, from: now)
                let yearNow = cal.component(.yearForWeekOfYear, from: now)

                let weekCompleted = cal.component(.weekOfYear, from: completedDate)
                let yearCompleted = cal.component(.yearForWeekOfYear, from: completedDate)

                if weekNow != weekCompleted || yearNow != yearCompleted {
                    store.quests[index].archived = true
                }
            }
        }

        store.forceSave()
    }



    // MARK: - Logic

    func toggleQuest(_ quest: AppQuest) {
        store.toggle(quest.id)

        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        guard let updatedQuest = store.quests.first(where: { $0.id == quest.id }) else { return }

        switch updatedQuest.type {
        case .daily:
            if dailyCompleted {
                if !alreadyCountedDailyToday() {
                    handleDailyStreak()
                    celebrateDaily = true
                }
            } else {
                // acabou de deixar de estar completo
                rollbackDailyIfNeeded()
            }

        case .weekly:
            if weeklyCompleted {
                if !alreadyCountedWeeklyThisWeek() {
                    handleWeeklyStreak()
                    celebrateWeekly = true
                }
            } else {
                rollbackWeeklyIfNeeded()
            }
        }

        if updatedQuest.completed && updatedQuest.recurrence != .none {
            autoReschedule(quest: updatedQuest)
        }
    }

    private func autoReschedule(quest: AppQuest) {
        let current = scheduledDay(for: quest)
        let base = max(current, Calendar.current.startOfDay(for: Date()))
        let nextDate: Date

        switch quest.recurrence {
        case .daily:
            nextDate = Calendar.current.date(byAdding: .day, value: 1, to: base) ?? base
        case .weekly:
            nextDate = Calendar.current.date(byAdding: .day, value: 7, to: base) ?? base
        case .none:
            return
        }

        var moved = quest
        moved.scheduledDate = Calendar.current.startOfDay(for: nextDate).timeIntervalSince1970
        moved.completed = false
        moved.completedAt = nil
        store.update(moved)
    }


    private func alreadyCountedDailyToday() -> Bool {
        guard let last = lastDailyCompletion else { return false }
        return Calendar.current.isDate(last, inSameDayAs: Date())
    }

    private func alreadyCountedWeeklyThisWeek() -> Bool {
        guard let last = lastWeeklyCompletion else { return false }
        let cal = Calendar.current
        let now = Date()
        return cal.component(.weekOfYear, from: last) == cal.component(.weekOfYear, from: now)
            && cal.component(.yearForWeekOfYear, from: last) == cal.component(.yearForWeekOfYear, from: now)
    }


    func delete(_ offsets: IndexSet, type: QuestType) {
        store.delete(offsets, type: type)
    }

    func progress(for type: QuestType) -> Double {
        let filtered = store.quests.filter { $0.type == type && !$0.archived && !$0.deleted && isQuestDueForHome($0) }
        guard !filtered.isEmpty else { return 0 }
        let completed = filtered.filter { $0.completed }.count
        return Double(completed) / Double(filtered.count)
    }
    
    func handleDailyStreak() {
        let period = todayKey()
        dailyRollbackPeriod = period
        dailyRollbackStreak = dailyStreak
        dailyRollbackLastCompletionTime = lastDailyCompletionTime

        let today = Calendar.current.startOfDay(for: Date())

        if let last = lastDailyCompletion {
            let lastDay = Calendar.current.startOfDay(for: last)

            if Calendar.current.dateComponents([.day], from: lastDay, to: today).day == 1 {
                withAnimation(.spring()) { dailyStreak += 1 }
            } else if lastDay != today {
                withAnimation(.spring()) { dailyStreak = 1 }
            }
        } else {
            withAnimation(.spring()) { dailyStreak = 1 }
        }

        lastDailyCompletionTime = Calendar.current.startOfDay(for: Date()).timeIntervalSince1970


    }


    func handleWeeklyStreak() {
        let key = currentWeekKey()
        weeklyRollbackPeriodKey = key
        weeklyRollbackStreak = weeklyStreak
        weeklyRollbackLastCompletionTime = lastWeeklyCompletionTime

        let currentWeek = Calendar.current.component(.weekOfYear, from: Date())
        let currentYear = Calendar.current.component(.yearForWeekOfYear, from: Date())

        if let last = lastWeeklyCompletion {
            let lastWeek = Calendar.current.component(.weekOfYear, from: last)
            let lastYear = Calendar.current.component(.yearForWeekOfYear, from: last)

            if currentWeek == lastWeek + 1 && currentYear == lastYear {
                withAnimation(.spring()) { weeklyStreak += 1 }
            } else if currentWeek != lastWeek || currentYear != lastYear {
                withAnimation(.spring()) { weeklyStreak = 1 }
            }
        } else {
            withAnimation(.spring()) { weeklyStreak = 1 }
        }


        lastWeeklyCompletionTime = Date().timeIntervalSince1970

    }
    func streakBadge(title: String, count: Int, icon: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.title2)

            Text("\(count)")
                .font(.title)
                .fontWeight(.bold)

            Text(NSLocalizedString(title, comment: ""))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
    }
    func validateStreaksOnLaunchOrResume() {
        let cal = Calendar.current
        let now = Date()

        // Daily: se falhaste 1+ dias (não foi ontem nem hoje), reseta para 0
        if let last = lastDailyCompletion {
            let lastDay = cal.startOfDay(for: last)
            let today = cal.startOfDay(for: now)
            let diff = cal.dateComponents([.day], from: lastDay, to: today).day ?? 0

            // diff == 0 (hoje) ou diff == 1 (ontem) mantém
            if diff > 1 {
                dailyStreak = 0
                lastDailyCompletionTime = 0
            }
        } else {
            // opcional: garantir coerência
            if dailyStreak != 0 { dailyStreak = 0 }
        }

        // Weekly: se falhaste 1+ semanas, reseta para 0
        if let last = lastWeeklyCompletion {
            let wNow = cal.component(.weekOfYear, from: now)
            let yNow = cal.component(.yearForWeekOfYear, from: now)
            let wLast = cal.component(.weekOfYear, from: last)
            let yLast = cal.component(.yearForWeekOfYear, from: last)

            let weeksApart: Int = {
                if yNow == yLast { return wNow - wLast }
                // aproximação segura: se mudou de ano, assume que já passou pelo menos 1 semana
                return 2
            }()

            if weeksApart > 1 {
                weeklyStreak = 0
                lastWeeklyCompletionTime = 0
            }
        } else {
            if weeklyStreak != 0 { weeklyStreak = 0 }
        }
    }




}

struct CelebrationView: View {

    var titleKey: String
    var onDismiss: () -> Void

    @State private var scale: CGFloat = 0.6
    @State private var opacity: Double = 0

    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: "sparkles")
                    .font(.system(size: 60))
                    .foregroundColor(.yellow)

                Text(NSLocalizedString(titleKey, comment: ""))
                    .font(.title)
                    .fontWeight(.semibold)

                Button(NSLocalizedString("nice", comment: "")) {
                    onDismiss()
                }

            }
            .padding(40)
            .background(.ultraThinMaterial)
            .cornerRadius(24)
            .scaleEffect(scale)
            .opacity(opacity)
            .onAppear {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                    scale = 1
                    opacity = 1
                }
            }
        }
    }
}
