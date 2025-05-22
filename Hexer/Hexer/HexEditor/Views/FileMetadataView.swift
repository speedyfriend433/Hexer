//
//  FileMetadataView.swift
//  Hexer
//
//  Created by 이지안 on 5/19/25.
//

import SwiftUI

struct FileMetadataView: View {
    let metadata: FileMetadata
    var onRefresh: () -> Void
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section("File Size") {
                    Text("\(metadata.size) bytes")
                }

                Section("Checksums") {
                    if metadata.isCalculatingChecksums && metadata.md5 == nil {
                        HStack {
                            Text("Calculating checksums...")
                                .foregroundColor(.secondary)
                            Spacer()
                            ProgressView()
                        }
                    } else {
                        InfoRow(label: "MD5", value: metadata.md5, isCalculating: metadata.isCalculatingChecksums && metadata.md5 == nil)
                        InfoRow(label: "SHA-1", value: metadata.sha1, isCalculating: metadata.isCalculatingChecksums && metadata.sha1 == nil)
                        InfoRow(label: "SHA-256", value: metadata.sha256, isCalculating: metadata.isCalculatingChecksums && metadata.sha256 == nil)
                    }
                }
            }
            .navigationTitle("File Information")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Refresh", action: onRefresh)
                        .disabled(metadata.isCalculatingChecksums)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct InfoRow: View {
    let label: String
    let value: String?
    var isCalculating: Bool = false

    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.gray)
            Spacer()
            if isCalculating {
                Text("Calculating...")
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.secondary)
            } else if let val = value, !val.isEmpty {
                Text(val)
                    .font(.system(.body, design: .monospaced))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Button {
                    UIPasteboard.general.string = val
                } label: {
                    Image(systemName: "doc.on.doc")
                }
                .buttonStyle(.borderless)
            } else {
                Text("N/A")
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct FileMetadataView_Previews: PreviewProvider {
    static var previews: some View {
        FileMetadataView(
            metadata: FileMetadata(
                size: 10240,
                md5: "d41d8cd98f00b204e9800998ecf8427e",
                sha1: nil,
                sha256: "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
                isCalculatingChecksums: true 
            ),
            onRefresh: { print("Refresh tapped") }
        )
    }
}
