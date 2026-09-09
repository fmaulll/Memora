import SwiftUI
import SwiftData
import StoreKit

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var auth = AuthManager.shared
    @State private var subscriptions = SubscriptionManager.shared
    @State private var showingPaywall = false
    @State private var showingManageSubscriptions = false
    @State private var confirmingLogout = false
    @State private var confirmingReset = false
    @State private var isRefreshing = false
    @State private var pendingGeneration: [GenerationRequestStore.Intent] = []
    @State private var recoveringGeneration = false
    @State private var errorMessage: String?
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("hasStartedOnboarding") private var hasStartedOnboarding = false

    var body: some View {
        AppBackground {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Settings").font(.custom("PlusJakartaSans-ExtraBold", size: 30))
                    section("ACCOUNT") {
                        NavigationLink { AccountSettingsView() } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "person.crop.circle").font(.system(size: 28)).foregroundStyle(Color.appAccent)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(auth.currentUser?.name ?? "Your profile").font(.custom("PlusJakartaSans-Bold", size: 17))
                                    Text(auth.currentUser?.isAnonymous == true ? "Guest account · Save your account" : auth.currentUser?.email ?? "Connect to load your profile")
                                        .font(.custom("PlusJakartaSans-Regular", size: 13)).foregroundStyle(Color.appTextSecondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                            }
                        }.buttonStyle(.plain)
                    }
                    section("SUBSCRIPTION") {
                        HStack {
                            Label(subscriptions.isSubscribed ? "Nudge subscription" : "Free account", systemImage: "sparkles")
                                .font(.custom("PlusJakartaSans-Bold", size: 17))
                            Spacer()
                            Text(statusLabel).foregroundStyle(Color.appAccent)
                                .font(.custom("PlusJakartaSans-SemiBold", size: 12))
                        }
                        if let entitlement = subscriptions.entitlement {
                            if let date = entitlement.status == "grace_period" ? entitlement.gracePeriodExpiresAt : entitlement.expiresAt {
                                Text("\(entitlement.status == "grace_period" ? "Grace period ends" : entitlement.autoRenew ? "Renews" : "Paid period ends") \(date.formatted(date: .abbreviated, time: .omitted))")
                                    .font(.custom("PlusJakartaSans-Regular", size: 13)).foregroundStyle(Color.appTextSecondary)
                            }
                        }
                        Text(subscriptions.entitlement == nil ? "Connect to check your free AI deck allowance." : subscriptions.freeAIDeckAvailable ? "Your first free AI deck is still available." : "Your first free AI deck has been used.")
                            .font(.custom("PlusJakartaSans-Regular", size: 13)).foregroundStyle(Color.appTextSecondary)
                        if !subscriptions.isSubscribed {
                            action("View subscription plans", icon: "sparkles") { showingPaywall = true }
                        }
                        action("Manage Apple subscription", icon: "arrow.up.right.square") { showingManageSubscriptions = true }
                        action("Restore purchases", icon: "arrow.clockwise") { Task { await subscriptions.restore() } }
                            .disabled(subscriptions.isBusy)
                        action(isRefreshing ? "Checking subscription…" : "Refresh subscription status", icon: "checkmark.shield") {
                            refreshSubscription()
                        }.disabled(isRefreshing || subscriptions.isBusy)
                        if let message = subscriptions.message {
                            Text(message).font(.custom("PlusJakartaSans-Regular", size: 13)).foregroundStyle(Color.appTextSecondary)
                        }
                    }
                    if !pendingGeneration.isEmpty {
                        section("INTERRUPTED DECK CREATION") {
                            Text("Resume the original request without creating a duplicate or using another free allowance.")
                                .font(.custom("PlusJakartaSans-Regular", size: 13)).foregroundStyle(Color.appTextSecondary)
                            ForEach(pendingGeneration, id: \.key) { intent in
                                action("Resume \(intent.request.plan.title)", icon: "arrow.clockwise") { recover(intent) }
                                    .disabled(recoveringGeneration)
                            }
                        }
                    }
                    if SubscriptionManager.privacyURL != nil || SubscriptionManager.termsURL != nil {
                        section("ABOUT") {
                            if let url = SubscriptionManager.privacyURL { Link("Privacy policy", destination: url) }
                            if let url = SubscriptionManager.termsURL { Link("Terms of use", destination: url) }
                        }
                    }
                    #if DEBUG
                    section("DEVELOPER OPTIONS") {
                        Text("Debug build only. These tools do not change purchases or the server’s free-deck allowance.")
                            .font(.custom("PlusJakartaSans-Regular", size: 12)).foregroundStyle(Color.appTextSecondary)
                        action("Reset onboarding", icon: "arrow.counterclockwise") { confirmingReset = true }
                        action("Sync account data", icon: "arrow.triangle.2.circlepath") {
                            Task { await AppSyncManager.shared.sync(modelContext: modelContext) }
                        }
                        Text("Purchase setup: \(subscriptions.purchasesConfigured ? "Configured" : "Missing product IDs or legal URLs")")
                        Text("User: \(auth.currentUser?.id.uuidString ?? "Unavailable")").textSelection(.enabled)
                        Text("Local StoreKit test purchases are rejected by the backend. Use a configured sandbox deployment for purchase testing.")
                            .foregroundStyle(Color.appTextSecondary)
                    }
                    .font(.custom("PlusJakartaSans-Regular", size: 12))
                    #endif
                    Button(role: .destructive) { confirmingLogout = true } label: {
                        Label("Log out", systemImage: "rectangle.portrait.and.arrow.right")
                            .frame(maxWidth: .infinity).padding(16).settingsPanel()
                    }
                    Text("Nudge · Version \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0")")
                        .font(.custom("PlusJakartaSans-Regular", size: 12)).foregroundStyle(Color.appTextSecondary)
                        .frame(maxWidth: .infinity)
                }.foregroundStyle(Color.appTextPrimary).padding(20)
            }
            .safeAreaInset(edge: .top) { BackNavigationBar { EmptyView() } }
        }
        .tint(Color.appAccent)
        .navigationBarBackButtonHidden()
        .sheet(isPresented: $showingPaywall) {
            PaywallView(onSubscribed: { showingPaywall = false }, onContinueFree: { showingPaywall = false })
        }
        .manageSubscriptionsSheet(isPresented: $showingManageSubscriptions)
        .onChange(of: showingManageSubscriptions) { _, showing in if !showing { refreshSubscription() } }
        .task {
            loadPendingGeneration()
            await subscriptions.resume()
        }
        .confirmationDialog("Log out of Nudge?", isPresented: $confirmingLogout, titleVisibility: .visible) {
            Button("Log out", role: .destructive) {
                do { try auth.logout(modelContext: modelContext) }
                catch { errorMessage = error.localizedDescription }
            }
        } message: {
            Text(auth.currentUser?.isAnonymous == true
                 ? "This guest account has no login credentials. Save your account from Profile first to keep access to your decks and purchases. Logging out clears this device’s local study data."
                 : "This clears local study data from this device. Your synced decks stay in your account.")
        }
        .confirmationDialog("Replay onboarding?", isPresented: $confirmingReset, titleVisibility: .visible) {
            Button("Reset onboarding", role: .destructive) {
                #if DEBUG
                UserDefaults.standard.set(true, forKey: "developerReplayOnboarding")
                hasStartedOnboarding = true
                hasCompletedOnboarding = false
                dismiss()
                #endif
            }
        } message: { Text("Keeps your current account and decks. It does not create another free AI allowance.") }
        .alert("Couldn’t finish", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: { Text(errorMessage ?? "Please try again.") }
    }

    private func loadPendingGeneration() {
        pendingGeneration = auth.currentUser.map { GenerationRequestStore.shared.pending(account: $0.id) } ?? []
    }
    private func recover(_ intent: GenerationRequestStore.Intent) {
        guard !recoveringGeneration else { return }
        recoveringGeneration = true
        Task {
            defer { recoveringGeneration = false; loadPendingGeneration() }
            do {
                let response = try await AIService.shared.resumeGeneration(intent)
                _ = try AIDeckCreationService.shared.createDeck(from: response.deck, existingDeck: nil,
                                                               modelContext: modelContext, requiresSubscription: intent.requiresSubscription ?? false)
                await AppSyncManager.shared.sync(modelContext: modelContext)
                subscriptions.message = "Your deck is available in Library."
            } catch {
                showingPaywall = (error as? APIError)?.requiresSubscription == true
                errorMessage = error.localizedDescription
            }
        }
    }

    private var statusLabel: String {
        (subscriptions.entitlement?.status ?? "unavailable").replacingOccurrences(of: "_", with: " ").capitalized
    }
    private func refreshSubscription() {
        guard !isRefreshing else { return }
        isRefreshing = true
        Task {
            defer { isRefreshing = false }
            do { try await subscriptions.refresh(reconcile: true); subscriptions.message = "Subscription status updated." }
            catch { subscriptions.message = error.localizedDescription }
        }
    }
    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.custom("PlusJakartaSans-Bold", size: 11)).foregroundStyle(Color.appTextSecondary)
            VStack(alignment: .leading, spacing: 18, content: content)
                .frame(maxWidth: .infinity, alignment: .leading).padding(18).settingsPanel()
        }
    }
    private func action(_ title: String, icon: String, perform: @escaping () -> Void) -> some View {
        Button(action: perform) {
            Label(title, systemImage: icon).font(.custom("PlusJakartaSans-SemiBold", size: 14))
                .frame(maxWidth: .infinity, alignment: .leading)
        }.buttonStyle(.plain)
    }
}

extension View {
    func settingsPanel() -> some View {
        background(Color.appSurface, in: RoundedRectangle(cornerRadius: 8))
            .overlay { RoundedRectangle(cornerRadius: 8).stroke(Color.appBorder, lineWidth: 1) }
    }
}

private struct AccountSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var auth = AuthManager.shared
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var isBusy = false
    @State private var message: String?
    @State private var merging = false
    @State private var confirmingMerge = false
    private var isGuest: Bool { auth.currentUser?.isAnonymous == true }

    var body: some View {
        AppBackground {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Profile").font(.custom("PlusJakartaSans-ExtraBold", size: 30))
                    if isGuest {
                        Text("Save your decks, progress, and purchases by adding login details to your guest account.")
                            .foregroundStyle(Color.appTextSecondary)
                        Picker("Save account", selection: $merging) {
                            Text("New account").tag(false)
                            Text("Existing account").tag(true)
                        }.pickerStyle(.segmented)
                    }
                    if !isGuest || !merging {
                        TextField("Name", text: $name).textContentType(.name).padding(16).settingsPanel()
                    }
                    TextField("Email", text: $email).textContentType(.emailAddress).keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never).autocorrectionDisabled().padding(16).settingsPanel()
                    if isGuest {
                        SecureField("Password", text: $password).textContentType(merging ? .password : .newPassword)
                            .padding(16).settingsPanel()
                        Text(merging ? "Move this guest account’s decks, study progress, purchases, and AI usage into your existing account. This is an explicit merge, not an ordinary login."
                             : "Use at least 8 characters and no more than 72 UTF-8 bytes for your password.")
                            .font(.custom("PlusJakartaSans-Regular", size: 13)).foregroundStyle(Color.appTextSecondary)
                    }
                    if let message { Text(message).foregroundStyle(Color.appTextSecondary) }
                    AppButton(title: isBusy ? "Saving…" : isGuest ? (merging ? "Merge into existing account" : "Save my account") : "Save profile",
                              foreground: Color.appBackground, background: Color.appAccent) {
                        if merging && isGuest { confirmingMerge = true } else { save() }
                    }.disabled(isBusy || email.trimmingCharacters(in: .whitespaces).isEmpty || (!merging && name.trimmingCharacters(in: .whitespaces).isEmpty)
                               || (isGuest && (merging ? password.isEmpty : password.count < 8 || password.utf8.count > 72)))
                }
                .font(.custom("PlusJakartaSans-Regular", size: 15)).foregroundStyle(Color.appTextPrimary).padding(20)
            }
            .safeAreaInset(edge: .top) { BackNavigationBar { EmptyView() } }
        }
        .navigationBarBackButtonHidden().tint(Color.appAccent)
        .task {
            name = auth.currentUser?.name ?? ""
            email = isGuest ? "" : auth.currentUser?.email ?? ""
        }
        .confirmationDialog("Merge into \(email)?", isPresented: $confirmingMerge, titleVisibility: .visible) {
            Button("Merge accounts") { save() }
        } message: { Text("The guest account will be removed after its data moves. Purchases and free-deck usage stay linked. This cannot be undone from the app.") }
    }
    private func save() {
        guard !isBusy else { return }
        isBusy = true; message = nil
        Task {
            defer { isBusy = false; password = "" }
            do {
                if isGuest {
                    try await auth.convertGuest(name: name.trimmingCharacters(in: .whitespaces), email: email.trimmingCharacters(in: .whitespaces), password: password,
                                                merge: merging, modelContext: modelContext)
                } else {
                    try await auth.updateProfile(name: name.trimmingCharacters(in: .whitespaces), email: email.trimmingCharacters(in: .whitespaces), modelContext: modelContext)
                }
                merging = false
                name = auth.currentUser?.name ?? name
                email = auth.currentUser?.email ?? email
                message = "Your account has been saved."
            } catch { message = error.localizedDescription }
        }
    }
}
