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

struct AppQuest: Identifiable, Codable {
    var id: UUID = UUID()
    var title: String
    var type: QuestType
    var notes: String = ""
    var completed: Bool = false
    var archived: Bool = false
    var completedAt: Double? = nil // timestamp

}

struct ContentView: View {
    
    @Environment(\.scenePhase) private var scenePhase

    enum SidebarItem: Hashable {
        case home, archive, settings, bug
    }
    private var isPhone: Bool { UIDevice.current.userInterfaceIdiom == .phone }
    @State private var phonePath: [SidebarItem] = []
    @State private var didAutoOpenHome = false


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
            UpsertQuestView { newQuest in store.add(newQuest) }
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
        }
    }


    @ViewBuilder
    private var currentDetailView: some View {
        switch selectedItem {
        case .home: homeView
        case .archive: archiveView
        case .settings: settingsView
        case .bug: bugReportView
        }
    }

    @ViewBuilder
    private func sidebarList() -> some View {
        List {
            sidebarButton(.home, titleKey: "menu_home", systemImage: "house")
            sidebarButton(.archive, titleKey: "menu_archive", systemImage: "archivebox")

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
        Text("Settings (em breve)")
            .navigationTitle("Settings")
    }

    private var bugReportView: some View {
        Text("Bug Report (em breve)")
            .navigationTitle("Bug Report")
    }

    private var archiveView: some View {
        List {
            ForEach(store.quests.filter { $0.archived }) { quest in
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

                    // Delete permanentemente
                    Button(role: .destructive) {
                        store.deleteQuest(quest.id)
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
        .navigationTitle("Archive")
    }


    
    private var homeView: some View {
        VStack(spacing: 12) {

            // 🔥 STREAKS
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

            // 📜 QUEST LIST
            List {
                Section(header: sectionHeaderKey("daily_quests", isExpanded: $showDaily, type: .daily)) {
                    if showDaily {
                        ForEach(dailyQuests) { quest in
                            questRow(for: quest)
                        }
                    }
                }

                Section(header: sectionHeaderKey("weekly_quests", isExpanded: $showWeekly, type: .weekly)) {
                    if showWeekly {
                        ForEach(weeklyQuests) { quest in
                            questRow(for: quest)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .animation(.spring(), value: showDaily)
            .animation(.spring(), value: showWeekly)
        }
        .navigationTitle(Text(NSLocalizedString("app_title", comment: "")))
        .toolbar {
            Button { showAddQuest = true } label: {
                Image(systemName: "plus")
            }
        }
    }


    // MARK: - Computed helpers

    var dailyQuests: [AppQuest] {
        store.quests
            .filter { $0.type == .daily && !$0.archived }
            .sorted { !$0.completed && $1.completed }
    }

    var weeklyQuests: [AppQuest] {
        store.quests
            .filter { $0.type == .weekly && !$0.archived }
            .sorted { !$0.completed && $1.completed }
    }



    var dailyCompleted: Bool {
        !dailyQuests.isEmpty && dailyQuests.allSatisfy { $0.completed }
    }

    var weeklyCompleted: Bool {
        !weeklyQuests.isEmpty && weeklyQuests.allSatisfy { $0.completed }
    }

    // MARK: - Views

    func questRow(for quest: AppQuest) -> some View {

        HStack(spacing: 12) {
            Image(systemName: quest.completed ? "checkmark.seal.fill" : "flame.fill")
                .foregroundColor(quest.completed ? .green : .orange)
                .font(.title3)

            Text(quest.title)
                .fontWeight(.medium)
                .strikethrough(quest.completed)
                .foregroundColor(quest.completed ? .secondary : .primary)
            
            if !quest.notes.isEmpty {
                Text(quest.notes)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
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
            withAnimation(.spring()) {
                toggleQuest(quest)
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                store.deleteQuest(quest.id)
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

        switch quest.type {
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
        let filtered = store.quests.filter { $0.type == type && !$0.archived }
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

struct AddQuestView: View {

    @Environment(\.dismiss) var dismiss

    @State private var title = ""
    @State private var type: QuestType = .daily

    var onAdd: (AppQuest) -> Void

    var body: some View {
        NavigationView {
            Form {
                TextField(LocalizedStringKey("quest_title_placeholder"), text: $title)


                Picker(LocalizedStringKey("quest_type"), selection: $type) {
                    ForEach(QuestType.allCases) { type in
                        Text(type.localized).tag(type)
                    }
                }
                .pickerStyle(.segmented)
            }
            .navigationTitle(Text("new_quest"))
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(LocalizedStringKey("add")) {
                        onAdd(AppQuest(title: title, type: type))
                        dismiss()
                    }
                    .disabled(title.isEmpty)
                }

                ToolbarItem(placement: .cancellationAction) {
                    Button(LocalizedStringKey("cancel")) {
                        dismiss()
                    }
                }
            }
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

