//
//  ContentView.swift
//  Hexer
//
//  Created by 이지안 on 5/19/25.
//

import SwiftUI

struct SimpleDetailView: View {
    let message: String
    let idForcingRefresh: UUID

    init(message: String, id: UUID) {
        self.message = message
        self.idForcingRefresh = id
        print("[SimpleDetailView] init with message: \(message)")
    }

    var body: some View {
        let _ = print("[SimpleDetailView body] message: \(message)")
        Text(message)
            .font(.largeTitle)
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.green.opacity(0.3))
            .id(idForcingRefresh)
    }
}

struct ContentView: View {
    @StateObject private var primaryHexViewModel = HexEditorViewModel()

    @State private var detailMessage: String? = nil
    @State private var detailViewID = UUID()
    @State private var detailViewModel: HexEditorViewModel?

    @State private var columnVisibility: NavigationSplitViewVisibility = .automatic
    @State private var showFileImporter = false

    var body: some View {
            NavigationSplitView(columnVisibility: $columnVisibility) {
                SidebarView(
                    showFileImporter: $showFileImporter,
                    fileName: primaryHexViewModel.fileBuffer?.url.lastPathComponent
                )
            } detail: {
                NavigationStack {
                    if let currentDetailViewModel = detailViewModel {
                        HexEditorView(viewModel: currentDetailViewModel)
                            .id(detailViewID)
                            .onAppear {
                                print("[ContentView] HexEditorView (detail) appeared with detailViewModel.")
                            }
                    } else {
                        Text("Detail View Awaiting File...")
                            .onAppear{
                                print("[ContentView] Detail View Awaiting File... appeared.")
                            }
                    }
                }
            }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.data],
            allowsMultipleSelection: false
        ) { result in
            Task {
                await handleFileImport(result: result)
            }
        }
        .onChange(of: primaryHexViewModel.fileBuffer) { newBuffer in
                    print("[ContentView] primaryHexViewModel.fileBuffer changed.")
                    if let validNewBuffer = newBuffer, validNewBuffer.fileSize > 0 {
                        print("[ContentView] New valid fileBuffer in primary. Creating/updating detailViewModel.")
                        
                        let newDetailVM = HexEditorViewModel()
                        newDetailVM.fileBuffer = validNewBuffer
                        newDetailVM.refreshStateAfterExternalBufferSet()
                        newDetailVM.isLoading = false
                        
                        self.detailViewModel = newDetailVM
                        self.detailViewID = UUID()
                        print("[ContentView] detailViewModel set for HexEditorView. File: \(newDetailVM.fileBuffer?.url.lastPathComponent ?? "N/A"), Rows: \(newDetailVM.totalRowCount)")
                    } else {
                        print("[ContentView] primaryHexViewModel.fileBuffer is nil or empty. Clearing detailViewModel.")
                        self.detailViewModel = nil
                        self.detailViewID = UUID()
                    }
                }
            }

    private func handleFileImport(result: Result<[URL], Error>) {
            switch result {
            case .success(let urls):
                guard let url = urls.first else {
                    primaryHexViewModel.errorMessage = "No file selected."
                    self.detailMessage = "Error: No file selected."
                    return
                }
                Task {
                    await primaryHexViewModel.loadFile(url: url)
                }
            case .failure(let error):
                primaryHexViewModel.errorMessage = "Failed to import file: \(error.localizedDescription)"
                self.detailMessage = "Error: \(error.localizedDescription)"
            }
        }
    }

struct SidebarView: View {
    @Binding var showFileImporter: Bool
    var fileName: String?

    var body: some View {
        List {
            Section("File") {
                Button {
                    showFileImporter = true
                } label: {
                    Label("Import File", systemImage: "doc.badge.plus")
                }

                if let name = fileName, !name.isEmpty {
                    Text("Current: \(name)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("No file loaded.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("Hexer")
    }
}

#Preview {
    ContentView()
}
