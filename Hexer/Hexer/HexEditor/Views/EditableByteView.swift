//
//  EditableByteView.swift
//  Hexer
//
//  Created by 이지안 on 5/19/25.
//

import SwiftUI

struct EditableByteView: View {
    @Binding var text: String
    let isHex: Bool
    var onCommit: () -> Void
    var onCancel: () -> Void
    @FocusState private var isFocused: Bool

    var body: some View {
        TextField("", text: $text, onCommit: onCommit)
            .font(.system(.body, design: .monospaced))
            .textFieldStyle(.plain)
            .frame(width: isHex ? 30 : 20, height: 22)
            .padding(.horizontal, isHex ? 2 : 4)
            .padding(.vertical, 1)
            .background(Color.yellow.opacity(0.5))
            .cornerRadius(4)
            .focused($isFocused)
            .onChange(of: text) { newValue in
                if isHex {
                    text = String(newValue.uppercased().filter { "0123456789ABCDEF".contains($0) }.prefix(2))
                } else {
                    text = String(newValue.prefix(1))
                }
            }
            .onAppear {
                isFocused = true
            }
            .onSubmit { 
                onCommit()
            }
    }
}
