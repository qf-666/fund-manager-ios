import SwiftUI

struct EditHoldingSheet: View {
    let original: StoredHolding
    let onSave: (StoredHolding) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var sharesText: String
    @State private var costText: String
    @State private var notes: String
    @State private var isPinned: Bool

    init(holding: StoredHolding, onSave: @escaping (StoredHolding) -> Void) {
        self.original = holding
        self.onSave = onSave
        _sharesText = State(initialValue: DisplayFormatter.decimalInput(holding.shares))
        _costText = State(initialValue: DisplayFormatter.decimalInput(holding.costPerUnit))
        _notes = State(initialValue: holding.notes)
        _isPinned = State(initialValue: holding.isPinned)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("基金") {
                    LabeledContent("名称", value: original.name)
                    LabeledContent("代码", value: original.code)
                }

                Section("持仓") {
                    TextField("持有份额", text: $sharesText)
                        .keyboardType(.decimalPad)
                    TextField("成本价", text: $costText)
                        .keyboardType(.decimalPad)
                    Text("份额或成本留空时按 0 处理，适合仅观察不持仓的基金。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("附加信息") {
                    Toggle("置顶显示", isOn: $isPinned)
                    TextField("备注（可选）", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("编辑持仓")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存") {
                        save()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private func save() {
        var updated = original
        updated.shares = Double(sharesText) ?? 0
        updated.costPerUnit = Double(costText) ?? 0
        updated.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.isPinned = isPinned
        onSave(updated)
        dismiss()
    }
}
