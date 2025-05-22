//
//  HexRowView.swift
//  Hexer
//
//  Created by 이지안 on 5/19/25.
//

import SwiftUI

struct HexRowView: View {
    @ObservedObject var viewModel: HexEditorViewModel
    let rowIndex: Int

    var body: some View {
        let _ = print("[HexRowView body - ULTRA SIMPLE] rowIndex: \(rowIndex)")

        return Text("Placeholder Row \(rowIndex)")
            .font(.system(.body, design: .monospaced))
            .padding(5)
            .frame(maxWidth: .infinity, minHeight: 20, alignment: .leading)
            .background(Color.orange.opacity(0.7))
            .border(Color.green, width: 1)
    }
}
