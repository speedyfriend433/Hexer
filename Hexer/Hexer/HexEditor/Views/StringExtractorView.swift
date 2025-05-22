//
//  StringExtractorView.swift
//  Hexer
//
//  Created by 이지안 on 5/19/25.
//

import SwiftUI

struct StringExtractorView: View {
    @ObservedObject var viewModel: HexEditorViewModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            VStack {
                HStack {
                    Text("Min Length:")
                    Picker("Min Length", selection: $viewModel.minStringLength) {
                        ForEach(2..<11) { len in
                            Text("\(len)").tag(len)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.trailing)
                    
                    Button("Extract") {
                        Task {
                            await viewModel.extractStrings()
                        }
                    }
                    .disabled(viewModel.isExtractingStrings)
                }
                .padding()

                if viewModel.isExtractingStrings {
                    ProgressView("Extracting strings...")
                    Spacer()
                } else if viewModel.extractedStrings.isEmpty {
                    Text("No strings found (or extraction not run).")
                        .foregroundColor(.secondary)
                    Spacer()
                } else {
                    List {
                        ForEach(viewModel.extractedStrings) { info in
                            HStack {
                                Text(viewModel.formatOffset(info.offset))
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(.gray)
                                Text(info.string)
                                Spacer()
                                Button {
                                    viewModel.selectedOffset = info.offset
                                    dismiss()
                                } label: {
                                    Image(systemName: "arrow.right.to.line.alt")
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("String Extractor")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                if viewModel.extractedStrings.isEmpty && viewModel.fileBuffer != nil {
                    Task { await viewModel.extractStrings() }
                }
            }
        }
    }
}
