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
            
            AppBackground {
                
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        
                        Text("NEW STUDY DECK")
                            .font(.custom("PlusJakartaSans-Bold", size: 14))
                            .foregroundStyle(.white.opacity(0.62))
                            .padding(.top, 16)
                        
                        Text("Upload your files")
                            .font(.custom("PlusJakartaSans-ExtraBold", size: 40))
                            .foregroundStyle(.white)
                            .tracking(-1)
                            .lineSpacing(-3)
                            .padding(.top, 16)
                        
                        Text("PDF, DOCX, or TXT supported")
                            .font(.custom("PlusJakartaSans-Regular", size: 16))
                            .foregroundStyle(.white.opacity(0.62))
                            .padding(.top, 20)
                        
                        Button {
                            isShowingFileImporter = true
                        } label: {
                            VStack(spacing: 12) {
                                Image(systemName: hasSelectedFile ? "checkmark" : "arrow.up")
                                    .font(.system(size: 20, weight: .medium))
                                    .foregroundStyle(.white)
                                    .frame(width: 48, height: 48)
                                    .background(accent, in: RoundedRectangle(cornerRadius: 13))
                                
                                Text(selectedFileName ?? "Tap to browse files")
                                    .font(.custom("PlusJakartaSans-SemiBold", size: 18))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 200)
                            .padding(.horizontal, 20)
                            .background(.white.opacity(0.18), in: RoundedRectangle(cornerRadius: 16))
                            .overlay {
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(
                                        .white.opacity(0.38),
                                        style: StrokeStyle(lineWidth: 1.03, dash: [5, 5])
                                    )
                            }
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 30)
                        .accessibilityLabel(hasSelectedFile ? "Selected file \(selectedFileName ?? "")" : "Browse files")
                        
                        Button {
                            selectedFileName = "Sample study material.pdf"
                        } label: {
                            Text(hasSelectedFile ? "Choose a different file" : "+ Add sample file (demo)")
                                .font(.custom("PlusJakartaSans-Regular", size: 16))
                                .foregroundStyle(accent)
                                .frame(maxWidth: .infinity)
                        }
                        .padding(.top, 24)
                        
                        Color.clear
                            .frame(height: 110)
                    }
                    .padding(.horizontal, 20)
                }
                
                .safeAreaInset(edge: .top, spacing: 0) {
                    BackNavigationBar {
                        EmptyView()
                    }
                }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    VStack(spacing: 0) {
                        WorkflowIndicator(numberOfSteps: 3, currentStep: 1, accent: accent)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 12)

                        HStack {
                            AppButton(
                                title: "Continue",
                                foreground: hasSelectedFile ? .white : .white.opacity(0.45),
                                background: AnyShapeStyle(LinearGradient(colors: [accent, Color(red: 0.55, green: 0.36, blue: 0.96)], startPoint: .leading, endPoint: .trailing))
                            ) {
                                guard hasSelectedFile else { return }
                                isShowingContinueAlert = true
                            }
                            .disabled(!hasSelectedFile)
                            .padding(.horizontal, 20)
                        }
                    }
                    .padding(.top, 12)
                    .padding(.bottom, 12)
                    .background(.black.opacity(0.92))
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
}

#Preview {
    UploadStudyMaterialsView()
}
