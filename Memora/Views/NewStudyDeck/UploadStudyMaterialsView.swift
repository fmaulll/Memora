//
//  UploadStudyMaterialsView.swift
//  Memora
//
//  Created by fuckdazeshit on 14/08/26.
//

import SwiftUI
import UniformTypeIdentifiers

struct UploadStudyMaterialsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isShowingFileImporter = false
    @State private var selectedFileName: String?
    @State private var isShowingContinueAlert = false

    private let background = Color(red: 0.04, green: 0.04, blue: 0.13)
    private let accent = Color(red: 0.39, green: 0.40, blue: 0.95)
    private let uploadTypes: [UTType] = [
        .pdf,
        .plainText,
        UTType(filenameExtension: "docx") ?? .data
    ]

    private var hasSelectedFile: Bool {
        selectedFileName != nil
    }

    var body: some View {
        ZStack {
            background.ignoresSafeArea()

            DecorativeBackground()
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "arrow.left")
                                .font(.system(size: 22, weight: .medium))
                                .foregroundStyle(.white.opacity(0.78))
                                .frame(width: 56, height: 56)
                                .background(.white.opacity(0.18), in: Circle())
                        }
                        .accessibilityLabel("Back")

                        Spacer()
                    }

                    UploadProgressIndicator(accent: accent)
                        .padding(.top, 32)

                    Text("NEW STUDY DECK")
                        .font(.custom("PlusJakartaSans-Bold", size: 14))
                        .foregroundStyle(.white.opacity(0.62))
                        .padding(.top, 16)

                    Text("Upload your files")
                        .font(.custom("PlusJakartaSans-ExtraBold", size: 40))
                        .foregroundStyle(.white)
                        .tracking(-1)
                        .padding(.top, 68)

                    Text("PDF, DOCX, or TXT supported")
                        .font(.custom("PlusJakartaSans-Regular", size: 20))
                        .foregroundStyle(.white.opacity(0.62))
                        .padding(.top, 20)

                    Button {
                        isShowingFileImporter = true
                    } label: {
                        VStack(spacing: 26) {
                            Image(systemName: hasSelectedFile ? "checkmark" : "arrow.up")
                                .font(.system(size: 27, weight: .medium))
                                .foregroundStyle(.white)
                                .frame(width: 92, height: 92)
                                .background(accent, in: RoundedRectangle(cornerRadius: 22))

                            Text(selectedFileName ?? "Tap to browse files")
                                .font(.custom("PlusJakartaSans-SemiBold", size: 18))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 278)
                        .padding(.horizontal, 20)
                        .background(.white.opacity(0.18), in: RoundedRectangle(cornerRadius: 24))
                        .overlay {
                            RoundedRectangle(cornerRadius: 24)
                                .stroke(
                                    .white.opacity(0.38),
                                    style: StrokeStyle(lineWidth: 1.5, dash: [5, 4])
                                )
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 68)
                    .accessibilityLabel(hasSelectedFile ? "Selected file \(selectedFileName ?? "")" : "Browse files")

                    Button {
                        selectedFileName = "Sample study material.pdf"
                    } label: {
                        Text(hasSelectedFile ? "Choose a different file" : "+ Add sample file (demo)")
                            .font(.custom("PlusJakartaSans-Regular", size: 16))
                            .foregroundStyle(accent)
                            .frame(maxWidth: .infinity)
                    }
                    .padding(.top, 28)

                    Spacer(minLength: 180)

                    AppButton(
                        title: "Continue",
                        foreground: hasSelectedFile ? .white : .white.opacity(0.45),
                        background: hasSelectedFile ? AnyShapeStyle(LinearGradient(colors: [accent, Color(red: 0.55, green: 0.36, blue: 0.96)], startPoint: .leading, endPoint: .trailing)) : AnyShapeStyle(.white.opacity(0.16))
                    ) {
                        guard hasSelectedFile else { return }
                        isShowingContinueAlert = true
                    }
                    .disabled(!hasSelectedFile)
                    .padding(.bottom, 28)
                }
                .padding(.horizontal, 36)
            }
        }
        .preferredColorScheme(.dark)
        .navigationBarBackButtonHidden(true)
        .fileImporter(
            isPresented: $isShowingFileImporter,
            allowedContentTypes: uploadTypes,
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                selectedFileName = urls.first?.lastPathComponent
            case .failure:
                selectedFileName = nil
            }
        }
        .alert("Ready to continue", isPresented: $isShowingContinueAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("\(selectedFileName ?? "Your file") is ready for processing.")
        }
    }
}

private struct UploadProgressIndicator: View {
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

#Preview {
    UploadStudyMaterialsView()
}
