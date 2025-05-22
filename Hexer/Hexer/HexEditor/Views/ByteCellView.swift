//
//  ByteCellView.swift
//  Hexer
//
//  Created by 이지안 on 5/19/25.
//

import SwiftUI

enum ByteCellType {
    case hex
    case ascii
}

struct ByteCellView: View {
    let byte: UInt8?
    let offset: Int
    let type: ByteCellType
    let isSelected: Bool
    let isChanged: Bool
    let isEditingThisCell: Bool

    var onSelect: () -> Void
    var onStartEdit: () -> Void

    private var displayValue: String {
        guard let byte = byte else { return type == .hex ? "  " : " " }
        switch type {
        case .hex:
            return String(format: "%02X", byte)
        case .ascii:
            return (isprint(Int32(byte)) != 0) ? String(UnicodeScalar(byte)) : "."
        }
    }

    var body: some View {
        Text(displayValue)
            .font(.system(.body, design: .monospaced))
            .frame(minWidth: type == .hex ? 25 : 15, alignment: .leading)
            .padding(.vertical, 2)
            .padding(.horizontal, 2)
            .background(backgroundMaterial)
            .foregroundColor(foregroundColor)
            .cornerRadius(4)
            .onTapGesture {
                onSelect()
            }
            .onLongPressGesture {
                onStartEdit()
            }
    }
    
    @ViewBuilder
    private var backgroundMaterial: some View {
        if isEditingThisCell {
            Color.yellow.opacity(0.4)
        } else if isSelected {
            Color.accentColor.opacity(0.8)
        } else if isChanged {
            Color.blue.opacity(0.35)
        } else {
            Color.clear
        }
    }

    private var foregroundColor: Color {
        isSelected && !isEditingThisCell ? .white : .primary
    }
}
