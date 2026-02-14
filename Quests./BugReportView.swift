import SwiftUI

private enum BugReportService {
    private static let endpoint = "https://api.web3forms.com/submit"
    // Create your key at web3forms.com and keep it here for now.
    private static let accessKey = "16e687bf-175a-4af1-bbe8-1e9e0624b922"

    private struct FormSubmitResponse: Decodable {
        let success: Bool?
        let message: String?
    }

    struct SubmitError: LocalizedError {
        let details: String?

        var errorDescription: String? {
            if let details, !details.isEmpty {
                return details
            }
            return NSLocalizedString("bug_report_error_submit", comment: "")
        }
    }

    static func submit(title: String, description: String) async throws {
        guard accessKey != "REPLACE_WITH_WEB3FORMS_ACCESS_KEY", !accessKey.isEmpty else {
            throw SubmitError(details: NSLocalizedString("bug_report_error_missing_access_key", comment: ""))
        }
        guard let url = URL(string: endpoint) else { throw SubmitError(details: nil) }

        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown"
        let locale = Locale.current.identifier
        let device = UIDevice.current.model

        let payload: [String: String] = [
            "access_key": accessKey,
            "from_name": "QuestReminder user",
            "subject": "QuestReminder Bug: \(title)",
            "message": description,
            "title": title,
            "app_version": "\(appVersion) (\(build))",
            "locale": locale,
            "device": device
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw SubmitError(details: nil)
        }

        if let parsed = try? JSONDecoder().decode(FormSubmitResponse.self, from: data) {
            if parsed.success != true {
                throw SubmitError(details: parsed.message)
            }
        }
    }
}

struct BugReportView: View {
    @State private var title = ""
    @State private var description = ""
    @State private var isSubmitting = false
    @State private var feedbackKey: String?
    @State private var isError = false

    var body: some View {
        Form {
            Section(header: Text(LocalizedStringKey("bug_report_title_label"))) {
                TextField(LocalizedStringKey("bug_report_title_placeholder"), text: $title)
            }

            Section(header: Text(LocalizedStringKey("bug_report_description_label"))) {
                TextField(LocalizedStringKey("bug_report_description_placeholder"), text: $description, axis: .vertical)
                    .lineLimit(6...14)
            }

            Section {
                Button {
                    Task { await submitReport() }
                } label: {
                    HStack {
                        if isSubmitting {
                            ProgressView()
                        }
                        Text(LocalizedStringKey("bug_report_submit"))
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isSubmitting || title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            if let feedbackKey {
                Section {
                    Text(LocalizedStringKey(feedbackKey))
                        .foregroundStyle(isError ? .red : .green)
                }
            }
        }
        .navigationTitle(Text("menu_bug"))
    }

    private func submitReport() async {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty, !trimmedDescription.isEmpty else { return }

        isSubmitting = true
        defer { isSubmitting = false }

        do {
            try await BugReportService.submit(title: trimmedTitle, description: trimmedDescription)
            isError = false
            feedbackKey = "bug_report_success"
            title = ""
            description = ""
        } catch {
            isError = true
            print("Bug report submit error:", error.localizedDescription)
            feedbackKey = "bug_report_error_submit_activation"
        }
    }
}
