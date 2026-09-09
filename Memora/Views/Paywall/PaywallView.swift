import SwiftUI
import StoreKit

struct PaywallView: View {
    let onSubscribed: () -> Void
    let onContinueFree: () -> Void
    var deckTitle: String? = nil
    @State private var subscriptions = SubscriptionManager.shared
    @State private var selectedProductID: String?
    @State private var didContinue = false

    private var selectedProduct: Product? {
        subscriptions.products.first { $0.id == selectedProductID } ?? subscriptions.products.first
    }

    var body: some View {
        AppBackground {
            ScrollView {
                VStack(spacing: 22) {
                    Image("MrEdTrade").resizable().scaledToFit().frame(height: 180)
                    VStack(spacing: 10) {
                        Text(deckTitle == nil ? "A simple deal." : "Your deck is ready.")
                            .font(.custom("PlusJakartaSans-ExtraBold", size: 30))
                        Text(deckTitle.map { "Unlock \($0). Then show me what you’ve learned." }
                             ?? "I’ll build the study plan. You still have to do the studying.")
                            .font(.custom("PlusJakartaSans-Regular", size: 15))
                            .foregroundStyle(Color.appTextSecondary)
                    }.multilineTextAlignment(.center)
                    VStack(alignment: .leading, spacing: 14) {
                        Label("AI-generated decks and flashcards", systemImage: "rectangle.stack.fill")
                        Label("Personal study plans and timelines", systemImage: "calendar")
                        Label("AI chapter exams and practice", systemImage: "checkmark.circle")
                    }
                    .font(.custom("PlusJakartaSans-SemiBold", size: 14))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(18).settingsPanel()

                    if subscriptions.isLoadingProducts { ProgressView("Loading plans…") }
                    ForEach(subscriptions.products, id: \.id) { product in
                        Button { selectedProductID = product.id } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(product.displayName).font(.custom("PlusJakartaSans-Bold", size: 16))
                                    Text("\(product.displayPrice) / \(periodLabel(product))")
                                        .font(.custom("PlusJakartaSans-Regular", size: 14))
                                }
                                Spacer()
                                Image(systemName: selectedProduct?.id == product.id ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(Color.appAccent)
                            }.padding(16).settingsPanel()
                        }.buttonStyle(.plain)
                    }
                    if let message = subscriptions.message {
                        Text(message).font(.custom("PlusJakartaSans-Regular", size: 13))
                            .foregroundStyle(Color.appTextSecondary).multilineTextAlignment(.center)
                    }
                    if let product = selectedProduct {
                        AppButton(title: subscriptions.isBusy ? "Please wait…" : "Subscribe — \(product.displayPrice)",
                                  foreground: Color.appBackground, background: Color.appAccent) {
                            Task { await subscriptions.purchase(product) }
                        }.disabled(subscriptions.isBusy || !subscriptions.purchasesConfigured)
                        Text("\(product.displayPrice) every \(periodLabel(product)). Automatically renews unless canceled in your Apple subscription settings. Apple confirms any eligible offer before payment.")
                            .font(.custom("PlusJakartaSans-Regular", size: 11))
                            .foregroundStyle(Color.appTextSecondary).multilineTextAlignment(.center)
                    } else if subscriptions.purchasesConfigured {
                        Button("Reload plans") { Task { await subscriptions.loadProducts() } }
                    }
                    Button("Restore purchases") { Task { await subscriptions.restore() } }
                        .disabled(subscriptions.isBusy)
                    HStack(spacing: 24) {
                        if let url = SubscriptionManager.privacyURL { Link("Privacy", destination: url) }
                        if let url = SubscriptionManager.termsURL { Link("Terms", destination: url) }
                    }
                    .font(.custom("PlusJakartaSans-Regular", size: 12))
                    Button(deckTitle == nil ? "Maybe later" : "Keep my deck locked for now", action: onContinueFree)
                        .foregroundStyle(Color.appTextSecondary)
                        .disabled(subscriptions.isBusy)
                }
                .foregroundStyle(Color.appTextPrimary)
                .padding(20)
            }
        }
        .tint(Color.appAccent)
        .interactiveDismissDisabled(subscriptions.isBusy)
        .task {
            await subscriptions.loadProducts()
            finishIfSubscribed()
        }
        .onChange(of: subscriptions.isSubscribed) { _, _ in finishIfSubscribed() }
    }

    private func finishIfSubscribed() {
        guard subscriptions.isSubscribed, !didContinue else { return }
        didContinue = true
        onSubscribed()
    }

    private func periodLabel(_ product: Product) -> String {
        guard let period = product.subscription?.subscriptionPeriod else { return "subscription period" }
        let unit: String
        switch period.unit {
        case .day: unit = "day"
        case .week: unit = "week"
        case .month: unit = "month"
        case .year: unit = "year"
        @unknown default: unit = "period"
        }
        return period.value == 1 ? unit : "\(period.value) \(unit)s"
    }
}


extension View {
    /// Present from the requesting screen, including an AI flow already in a sheet.
    func subscriptionPaywall(isPresented: Binding<Bool>) -> some View {
        sheet(isPresented: isPresented) {
            PaywallView(onSubscribed: { isPresented.wrappedValue = false },
                        onContinueFree: { isPresented.wrappedValue = false })
        }
    }
}
