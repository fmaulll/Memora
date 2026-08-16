//
//  CreateOwnDeckView.swift
//  Memora
//
//  Created by fuckdazeshit on 14/08/26.
//

import SwiftUI

struct CreateOwnDeckView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var deckTitle = ""
    @State private var subject = ""
    @State private var isShowingManualSubjectField = false
    @State private var educationLevel: EducationLevel = .highSchool
    @State private var isShowingAddFlashcards = false
    @FocusState private var focusedField: Field?

    private enum Field {
        case deckTitle
        case subject
    }

    private let accent = Color(red: 0.39, green: 0.40, blue: 0.95)
    private let levels = EducationLevel.allCases
    // Hardcoded for now — will be generated from deckTitle later.
    private let subjectSuggestions = ["Biology", "Excel", "Chemistry", "Anatomy", "Genetics"]

    private var canContinue: Bool {
        !deckTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !subject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ZStack {
            AppBackground {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            BackButton()
                            Spacer()
                        }

                        CreateDeckProgressIndicator(accent: accent)
                            .padding(.top, 32)

                        Text("NEW STUDY DECK")
                            .font(.custom("PlusJakartaSans-Bold", size: 14))
                            .foregroundStyle(.white.opacity(0.62))
                            .padding(.top, 16)

                        Text("What do you want\nto learn?")
                            .font(.custom("PlusJakartaSans-ExtraBold", size: 40))
                            .foregroundStyle(.white)
                            .tracking(-1)
                            .lineSpacing(-3)
                            .padding(.top, 16)

                        Text("Be specific for better flashcards")
                            .font(.custom("PlusJakartaSans-Regular", size: 16))
                            .foregroundStyle(.white.opacity(0.62))
                            .padding(.top, 20)

                        formField(
                            label: "DECK TITLE",
                            placeholder: "e.g. Spanish Vocabulary — Beginner",
                            text: $deckTitle
                        )
                        .padding(.top, 30)

                        subjectField
                            .padding(.top, 24)

                        Text("EDUCATION LEVEL")
                            .font(.custom("PlusJakartaSans-Regular", size: 14))
                            .foregroundStyle(.white.opacity(0.62))
                            .padding(.top, 24)

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                            ForEach(levels) { level in
                                Button {
                                    educationLevel = level
                                } label: {
                                    Text(level.title)
                                        .font(.custom("PlusJakartaSans-SemiBold", size: 16))
                                        .foregroundStyle(educationLevel == level ? .white : .white.opacity(0.62))
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 64)
                                        .background(
                                            educationLevel == level ? AnyShapeStyle(LinearGradient(colors: [accent, Color(red: 0.55, green: 0.36, blue: 0.96)], startPoint: .leading, endPoint: .trailing)) : AnyShapeStyle(.white.opacity(0.18)),
                                            in: RoundedRectangle(cornerRadius: 20)
                                        )
                                        .overlay {
                                            RoundedRectangle(cornerRadius: 20)
                                                .stroke(.white.opacity(0.28), lineWidth: 1.5)
                                        }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.top, 18)

                        Color.clear
                            .frame(height: 120)
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
        .preferredColorScheme(.dark)
        .navigationBarBackButtonHidden()
        .dismissKeyboardOnTap()
        .safeAreaInset(edge: .bottom, spacing: 0) {
            HStack {
                AppButton(
                    title: "Continue",
                    foreground: canContinue ? .white : .white.opacity(0.45),
                    background: canContinue ? AnyShapeStyle(LinearGradient(colors: [accent, Color(red: 0.55, green: 0.36, blue: 0.96)], startPoint: .leading, endPoint: .trailing)) : AnyShapeStyle(.white.opacity(0.16))
                ) {
                    isShowingAddFlashcards = true
                }
                .disabled(!canContinue)
                .padding(.horizontal, 20)
                .ignoresSafeArea(.keyboard, edges: .bottom)
                
            }
            .padding(.top, 12)
            .padding(.bottom, 12)
            .background(.black.opacity(0.92))
            
        }
        .navigationDestination(isPresented: $isShowingAddFlashcards) {
            AddFlashcardView(deckTitle: deckTitle, subject: subject, educationLevel: educationLevel.title)
        }
    }

    private var subjectField: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("SUBJECT")
                .font(.custom("PlusJakartaSans-Regular", size: 14))
                .foregroundStyle(.white.opacity(0.62))

            if isShowingManualSubjectField {
                TextField("e.g. Biology, Physics, History", text: $subject)
                    .font(.custom("PlusJakartaSans-Regular", size: 18))
                    .foregroundStyle(.white)
                    .tint(accent)
                    .focused($focusedField, equals: .subject)
                    .padding(.horizontal, 30)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .contentShape(Rectangle())
                    .background(.white.opacity(0.18), in: RoundedRectangle(cornerRadius: 20))
                    .overlay {
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(.white.opacity(0.28), lineWidth: 1.03)
                    }
                    .onTapGesture {
                        focusedField = .subject
                    }

                Button {
                    isShowingManualSubjectField = false
                } label: {
                    Text("Back to suggestions")
                        .font(.custom("PlusJakartaSans-Regular", size: 14))
                        .foregroundStyle(accent)
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            } else {
                FlowLayout(spacing: 10) {
                    ForEach(subjectSuggestions, id: \.self) { suggestion in
                        Button {
                            subject = suggestion
                        } label: {
                            Text(suggestion)
                                .font(.custom("PlusJakartaSans-SemiBold", size: 15))
                                .foregroundStyle(subject == suggestion ? .white : .white.opacity(0.62))
                                .padding(.horizontal, 18)
                                .padding(.vertical, 12)
                                .background(
                                    subject == suggestion ? AnyShapeStyle(accent) : AnyShapeStyle(.white.opacity(0.18)),
                                    in: Capsule()
                                )
                                .overlay {
                                    Capsule()
                                        .stroke(.white.opacity(0.28), lineWidth: 1.03)
                                }
                        }
                        .buttonStyle(.plain)
                    }
                }

                Button {
                    isShowingManualSubjectField = true
                } label: {
                    Text("Can't find it? Input manually")
                        .font(.custom("PlusJakartaSans-Regular", size: 14))
                        .foregroundStyle(accent)
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
        }
    }

    private func formField(label: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(label)
                .font(.custom("PlusJakartaSans-Regular", size: 14))
                .foregroundStyle(.white.opacity(0.62))

            TextField(placeholder, text: text)
                .font(.custom("PlusJakartaSans-Regular", size: 18))
                .foregroundStyle(.white)
                .tint(accent)
                .focused($focusedField, equals: .deckTitle)
                .padding(.horizontal, 30)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .contentShape(Rectangle())
                .background(.white.opacity(0.18), in: RoundedRectangle(cornerRadius: 20))
                .overlay {
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(.white.opacity(0.28), lineWidth: 1.03)
                }
                .onTapGesture {
                    focusedField = .deckTitle
                }
        }
    }
}

private struct FlowLayout: Layout {
    var spacing: CGFloat = 10

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var rowWidth: CGFloat = 0
        var totalHeight: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if rowWidth + size.width > maxWidth, rowWidth > 0 {
                totalHeight += rowHeight + spacing
                rowWidth = 0
                rowHeight = 0
            }
            rowWidth += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        totalHeight += rowHeight
        return CGSize(width: maxWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

private struct CreateDeckProgressIndicator: View {
    let accent: Color

    var body: some View {
        HStack(spacing: 12) {
            ForEach(0..<3, id: \.self) { step in
                Capsule()
                    .fill(step == 1 ? accent : .white.opacity(0.12))
                    .frame(maxWidth: .infinity)
                    .frame(height: 6)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step 2 of 3")
    }
}

private enum EducationLevel: String, CaseIterable, Identifiable {
    case elementary
    case juniorHigh
    case highSchool
    case university
    case professional
    case selfStudy

    var id: String { rawValue }

    var title: String {
        switch self {
        case .elementary: "Elementary School"
        case .juniorHigh: "Junior High School"
        case .highSchool: "High School"
        case .university: "University"
        case .professional: "Professional"
        case .selfStudy: "Self-Study"
        }
    }
}

#Preview {
    CreateOwnDeckView()
}
