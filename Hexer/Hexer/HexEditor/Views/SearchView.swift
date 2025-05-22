//
//  SearchView.swift
//  Hexer
//
//  Created by 이지안 on 5/19/25.
//

import SwiftUI

struct SearchView: View {
    @ObservedObject var viewModel: HexEditorViewModel
    @Environment(\.dismiss) var dismiss
    @State private var localSearchQuery: String = ""
    @State private var searchAsHex: Bool = true

    var body: some View {
        NavigationView {
            Form {
                Section("Search Query") {
                    TextField(searchAsHex ? "Hex bytes (e.g., FF D8 FF)" : "Text string", text: $localSearchQuery)
                        .autocorrectionDisabled(true)
                        .textInputAutocapitalization(.never)
                    
                    Picker("Search Type", selection: $searchAsHex) {
                        Text("Hexadecimal Bytes").tag(true)
                        Text("Text (UTF-8)").tag(false)
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    Button("Find") {
                        viewModel.searchQuery = localSearchQuery
                        Task {
                            await viewModel.search(query: localSearchQuery, searchHex: searchAsHex)
                            if !viewModel.searchResults.isEmpty {
                                dismiss()
                            }
                        }
                    }
                    .disabled(localSearchQuery.isEmpty || viewModel.isSearching)
                    
                    if viewModel.isSearching {
                        HStack {
                            Text("Searching...")
                            ProgressView()
                        }
                    }
                }

                if !viewModel.searchResults.isEmpty {
                    Section("Results (\(viewModel.searchResults.count) found)") {
                        HStack {
                            Button("Previous") { viewModel.previousSearchResult() }
                                .disabled(viewModel.searchResults.count <= 1 || viewModel.currentSearchResultIndex == nil)
                            Spacer()
                            Text(viewModel.currentSearchResultIndex != nil ? "Result \(viewModel.currentSearchResultIndex! + 1) of \(viewModel.searchResults.count)" : "")
                                .font(.caption)
                            Spacer()
                            Button("Next") { viewModel.nextSearchResult() }
                                .disabled(viewModel.searchResults.count <= 1 || viewModel.currentSearchResultIndex == nil)
                        }
                    }
                } else if !viewModel.searchQuery.isEmpty && !viewModel.isSearching && viewModel.errorMessage == nil {
                     Text("No results found for '\(viewModel.searchQuery)'.")
                        .foregroundColor(.secondary)
                }
                
                if let errorMsg = viewModel.errorMessage, (errorMsg.contains("search query") || errorMsg.contains("not found")) {
                    Text(errorMsg).foregroundColor(.red).font(.caption)
                }
            }
            .navigationTitle("Search")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                localSearchQuery = viewModel.searchQuery
                viewModel.errorMessage = nil
            }
        }
    }
}

struct SearchView_Previews: PreviewProvider {
    static var previews: some View {
        let mockViewModel = HexEditorViewModel()
        // mockViewModel.searchResults = [0, 16, 32]
        // mockViewModel.currentSearchResultIndex = 0
        // mockViewModel.searchQuery = "Test"
        
        return SearchView(viewModel: mockViewModel)
    }
}
