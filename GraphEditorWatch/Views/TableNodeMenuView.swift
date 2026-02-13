//
//  TableNodeMenuView.swift
//  GraphEditorWatch
//
//  Menu view for TableNode with seating management
//

import SwiftUI
import GraphEditorShared

@available(watchOS 10.0, *)
struct TableNodeMenuView: View {
    let viewModel: GraphViewModel
    let onDismiss: () -> Void
    @Binding var selectedNodeID: NodeID?

    @State private var tableNode: TableNode?
    @State private var selectedSeat: SeatPosition?
    @State private var showPersonPicker = false
    @State private var showEditSheet = false
    @State private var editedName = ""
    @State private var editedHeadSeats = 1
    @State private var editedSideSeats = 3
    @State private var editedLength: Double = 48.0  // Table length in current unit
    @State private var editedWidth: Double = 30.0   // Table width in current unit
    @State private var useInches = true   // true = inches, false = cm
    @State private var allPersons: [PersonNode] = []

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                if let table = tableNode {
                    // Table Info Section
                    Text(table.name)
                        .font(.headline)
                        .multilineTextAlignment(.center)
                        .padding(.bottom, 4)

                    infoSection(table: table)

                    // Seating Section
                    Text("Seating Arrangement")
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 8)

                    seatingList(table: table)

                    // Actions Section
                    Text("Actions")
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 8)

                    actionButton("Edit Table", icon: "pencil.circle.fill", color: .orange) {
                        prepareEdit()
                        showEditSheet = true
                    }

                    actionButton("Arrange All", icon: "arrow.triangle.2.circlepath", color: .blue) {
                        arrangeAll()
                    }

                    actionButton("Close", icon: "xmark.circle.fill", color: .gray) {
                        onDismiss()
                    }
                }
            }
            .padding(8)
        }
        .onAppear {
            loadTable()
        }
        .sheet(isPresented: $showPersonPicker) {
            if let seat = selectedSeat {
                personPickerSheet(for: seat)
            }
        }
        .sheet(isPresented: $showEditSheet) {
            editTableSheet()
        }
    }

    // MARK: - Info Section

    @ViewBuilder
    private func infoSection(table: TableNode) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Total Seats:")
                    .font(.caption2)
                    .foregroundColor(.gray)
                Spacer()
                Text("\(table.totalSeats)")
                    .font(.caption)
                    .fontWeight(.semibold)
            }

            HStack {
                Text("Occupied:")
                    .font(.caption2)
                    .foregroundColor(.gray)
                Spacer()
                Text("\(table.seatingAssignments.count)")
                    .font(.caption)
                    .fontWeight(.semibold)
            }
        }
        .padding(8)
        .background(Color.brown.opacity(0.1))
        .cornerRadius(6)
    }

    // MARK: - Seating List

    @ViewBuilder
    private func seatingList(table: TableNode) -> some View {
        VStack(spacing: 4) {
            ForEach(SeatPosition.allCases, id: \.self) { position in
                seatRow(table: table, position: position)
            }
        }
    }

    @ViewBuilder
    private func seatRow(table: TableNode, position: SeatPosition) -> some View {
        HStack {
            Text(position.label)
                .font(.caption)
                .foregroundColor(.gray)

            Spacer()

            if let personID = table.seatingAssignments[position],
               let person = allPersons.first(where: { $0.id == personID }) {
                Text(person.name)
                    .font(.caption)
                    .fontWeight(.semibold)

                Button(action: {
                    removePerson(personID: personID, from: position)
                }, label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.red)
                })
                .buttonStyle(.plain)
            } else {
                Button(action: {
                    selectedSeat = position
                    showPersonPicker = true
                }, label: {
                    Text("Assign")
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.2))
                        .cornerRadius(4)
                })
                .buttonStyle(.plain)
            }
        }
        .padding(6)
        .background(table.seatingAssignments[position] != nil ? Color.blue.opacity(0.1) : Color.clear)
        .cornerRadius(6)
    }

    // MARK: - Person Picker Sheet

    @ViewBuilder
    private func personPickerSheet(for seat: SeatPosition) -> some View {
        NavigationView {
            List {
                Section("Available People") {
                    ForEach(unseatedPersons, id: \.id) { person in
                        Button(action: {
                            assignPerson(person, to: seat)
                            showPersonPicker = false
                            selectedSeat = nil
                        }, label: {
                            HStack {
                                Text(person.name)
                                    .font(.body)

                                Spacer()

                                Text("[\(person.label)]")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        })
                    }
                }
            }
            .navigationTitle("Select Person")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showPersonPicker = false
                        selectedSeat = nil
                    }
                }
            }
        }
    }

    // MARK: - Helper Views

    @ViewBuilder
    private func actionButton(_ title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.body)
                .padding(10)
                .frame(maxWidth: .infinity)
                .background(color.opacity(0.2))
                .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Computed Properties

    private var unseatedPersons: [PersonNode] {
        guard let table = tableNode else { return [] }
        let assignedIDs = Set(table.seatingAssignments.values)
        return allPersons.filter { !assignedIDs.contains($0.id) }
    }

    // MARK: - Data Loading

    private func loadTable() {
        guard let nodeID = selectedNodeID,
              let node = viewModel.model.nodes.first(where: { $0.id == nodeID }),
              let table = node.unwrapped as? TableNode else {
            return
        }

        tableNode = table

        // Load all persons
        allPersons = viewModel.model.nodes.compactMap { $0.unwrapped as? PersonNode }
    }

    private func assignPerson(_ person: PersonNode, to position: SeatPosition) {
        guard let tableID = selectedNodeID else { return }

        Task {
            await viewModel.model.assignPersonToTable(
                personID: person.id,
                tableID: tableID,
                seatPosition: position
            )

            // Reload
            await MainActor.run {
                loadTable()
            }
        }
    }

    private func removePerson(personID: NodeID, from position: SeatPosition) {
        guard let tableID = selectedNodeID else { return }

        Task {
            await viewModel.model.removePersonFromTable(
                personID: personID,
                tableID: tableID
            )

            // Reload
            await MainActor.run {
                loadTable()
            }
        }
    }

    private func arrangeAll() {
        guard let tableID = selectedNodeID else { return }
        viewModel.model.arrangePersonsAroundTable(tableID: tableID)
    }

    // MARK: - Edit Table Sheet

    @ViewBuilder
    private func editTableSheet() -> some View {
        NavigationView {
            Form {
                Section("Table Name") {
                    TextField("Name", text: $editedName)
                }

                Section("Table Dimensions") {
                    Picker("Units", selection: $useInches) {
                        Text("Inches").tag(true)
                        Text("cm").tag(false)
                    }
                    
                    NavigationLink(destination: SimpleCrownNumberInput(value: $editedLength, minimumValue: 12)) {
                        HStack {
                            Text("Length:")
                            Spacer()
                            Text("\(formattedDimension(editedLength)) \(useInches ? "in" : "cm")")
                                .foregroundColor(.gray)
                        }
                    }
                    
                    NavigationLink(destination: SimpleCrownNumberInput(value: $editedWidth, minimumValue: 12)) {
                        HStack {
                            Text("Width:")
                            Spacer()
                            Text("\(formattedDimension(editedWidth)) \(useInches ? "in" : "cm")")
                                .foregroundColor(.gray)
                        }
                    }
                    
                    if let seats = calculateSeatsFromDimensions() {
                        Text("Capacity: \(seats) seats")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            }
            .navigationTitle("Edit Table")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showEditSheet = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveTableChanges()
                        showEditSheet = false
                    }
                }
            }
        }
    }

    private func prepareEdit() {
        guard let table = tableNode else { return }
        editedName = table.name
        editedHeadSeats = table.headSeats
        editedSideSeats = table.sideSeats
        
        // Convert table dimensions (points) to inches using 1pt = 1 inch scale
        editedLength = Double(table.tableLength)
        editedWidth = Double(table.tableWidth)
        useInches = true
    }
    
    private func formattedDimension(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", value)
        } else {
            return String(format: "%.1f", value)
        }
    }
    
    /// Calculate seat counts from physical dimensions
    /// Standard spacing: 24 inches (60cm) per person
    private func calculateSeatsFromDimensions() -> Int? {
        guard editedLength > 0, editedWidth > 0 else {
            return nil
        }
        
        // Convert to inches if needed
        let lengthInches = useInches ? editedLength : editedLength / 2.54
        let widthInches = useInches ? editedWidth : editedWidth / 2.54
        
        // Standard spacing: 24 inches per person
        let spacingInches = 24.0
        
        // Calculate side seats (along length)
        let calculatedSideSeats = max(0, Int((lengthInches - 12) / spacingInches))  // Leave room at ends
        
        // Calculate head seats (0, 1, or 2 based on width)
        let calculatedHeadSeats: Int
        if widthInches < 24 {
            calculatedHeadSeats = 0  // Too narrow for head seats
        } else if widthInches < 48 {
            calculatedHeadSeats = 1  // One seat at each end
        } else {
            calculatedHeadSeats = 2  // Two seats at each end
        }
        
        // Update the seat counts for saving
        editedSideSeats = min(6, calculatedSideSeats)  // Cap at 6
        editedHeadSeats = calculatedHeadSeats
        
        return editedHeadSeats * 2 + editedSideSeats * 2
    }

    private func saveTableChanges() {
        guard let tableID = selectedNodeID,
              let tableIndex = viewModel.model.nodes.firstIndex(where: { $0.id == tableID }),
              let table = viewModel.model.nodes[tableIndex].unwrapped as? TableNode else {
            return
        }

        // Recalculate seat counts from dimensions
        _ = calculateSeatsFromDimensions()

        // Convert dimensions from inches/cm to points (1pt = 1 inch)
        let lengthInches = useInches ? editedLength : editedLength / 2.54
        let widthInches = useInches ? editedWidth : editedWidth / 2.54
        
        // Create updated table with new properties
        let updatedTable = TableNode(
            id: table.id,
            label: table.label,
            position: table.position,
            velocity: table.velocity,
            radius: table.radius,
            name: editedName,
            headSeats: editedHeadSeats,
            sideSeats: editedSideSeats,
            tableLength: CGFloat(lengthInches),  // 1pt = 1 inch
            tableWidth: CGFloat(widthInches),    // 1pt = 1 inch
            seatingAssignments: table.seatingAssignments
        )

        viewModel.model.nodes[tableIndex] = AnyNode(updatedTable)

        Task {
            try? await viewModel.model.saveGraph()
            await MainActor.run {
                loadTable()
            }
        }
    }
}
