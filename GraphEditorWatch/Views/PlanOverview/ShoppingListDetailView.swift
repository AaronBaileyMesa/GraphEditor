//
//  ShoppingListDetailView.swift
//  GraphEditorWatch
//
//  Scrollable shopping list with bought-state persistence.
//

import SwiftUI
import GraphEditorShared

struct ShoppingListDetailView: View {
    let planID: NodeID
    @ObservedObject var viewModel: GraphViewModel

    @State private var boughtItems: Set<String> = []
    @State private var shoppingList: [ShoppingItem] = []

    private var boughtKey: String { "bought_\(planID.uuidString)" }

    var remaining: [ShoppingItem] { shoppingList.filter { !boughtItems.contains($0.name) } }
    var bought: [ShoppingItem] { shoppingList.filter { boughtItems.contains($0.name) } }

    var body: some View {
        Group {
            if shoppingList.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "cart")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("Add tacos in Menu\nto generate list")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    if !remaining.isEmpty {
                        Section("To Buy (\(remaining.count))") {
                            ForEach(remaining) { item in
                                ShoppingItemRow(
                                    item: item,
                                    isBought: false,
                                    onToggle: { toggleBought(item.name) }
                                )
                            }
                        }
                    }

                    if !bought.isEmpty {
                        Section("Bought (\(bought.count))") {
                            ForEach(bought) { item in
                                ShoppingItemRow(
                                    item: item,
                                    isBought: true,
                                    onToggle: { toggleBought(item.name) }
                                )
                            }
                        }
                    }
                }
                .refreshable { refreshList() }
            }
        }
        .navigationTitle("Shopping")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            refreshList()
            loadBoughtItems()
        }
    }

    private func refreshList() {
        shoppingList = viewModel.model.generateTacoShoppingList(for: planID)
    }

    private func loadBoughtItems() {
        if let saved = UserDefaults.standard.stringArray(forKey: boughtKey) {
            boughtItems = Set(saved)
        }
    }

    private func toggleBought(_ name: String) {
        if boughtItems.contains(name) {
            boughtItems.remove(name)
        } else {
            boughtItems.insert(name)
        }
        UserDefaults.standard.set(Array(boughtItems), forKey: boughtKey)
    }
}

private struct ShoppingItemRow: View {
    let item: ShoppingItem
    let isBought: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 10) {
                Image(systemName: isBought ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isBought ? .green : .secondary)
                    .font(.title3)

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .strikethrough(isBought)
                        .foregroundStyle(isBought ? .secondary : .primary)
                    Text(item.quantityString)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
        }
        .buttonStyle(.plain)
    }
}
