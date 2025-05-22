//
//  HexEditorView.swift
//  Hexer
//
//  Created by 이지안 on 5/19/25.
//

import SwiftUI

struct HexEditorView: View {
    @ObservedObject var viewModel: HexEditorViewModel
    // @State private var showJumpToOffsetAlert = false
    // @State private var jumpOffsetInput: String = ""
    // @State private var showSearchSheet = false
    // @State private var showMetadataSheet = false
    // @State private var showStringExtractorSheet = false
    
    var body: some View {
        let _ = print("[HexEditorView body E] Re-evaluating. isLoading: \(viewModel.isLoading), fileBuffer isNil: \(viewModel.fileBuffer == nil), fileSize: \(viewModel.fileBuffer?.fileSize ?? -1), error: \(viewModel.errorMessage ?? "None")")
        
        Group {
            if viewModel.isLoading {
                let _ = print("[HexEditorView body E] Branch: isLoading")
                ProgressView("Loading...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.orange.opacity(0.3))
            } else if let fileBuffer = viewModel.fileBuffer, fileBuffer.fileSize > 0 {
                let _ = print("[HexEditorView body E] Branch: File loaded, has size.")
                editorContent
            } else if viewModel.fileBuffer != nil && viewModel.fileBuffer!.fileSize == 0 {
                let _ = print("[HexEditorView body E] Branch: File is empty.")
                Text("File is empty: \(viewModel.fileBuffer?.url.lastPathComponent ?? "N/A")")
                    .padding().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage = viewModel.errorMessage {
                let _ = print("[HexEditorView body E] Branch: ErrorMessage - \(errorMessage)")
                Text("Error: \(errorMessage)")
                    .foregroundColor(.red).padding().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                let _ = print("[HexEditorView body E] Branch: No file, no error (initial state)")
                Text("No file loaded. Import a file to start.")
                    .padding().frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        // .background(Color.purple.opacity(0.2))
        .navigationTitle("Test E Title")
    }

    
    private var editorContent: some View {
        let _ = print("[HexEditorView editorContent (ObservedObject)] Evaluating - ABSURDLY SIMPLE")
        return Text("Hello, Detail View!")
            .font(.largeTitle)
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.cyan.opacity(0.5))
    }
}
