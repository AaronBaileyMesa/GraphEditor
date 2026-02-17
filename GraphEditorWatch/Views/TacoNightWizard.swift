//
//  TacoNightWizard.swift
//  GraphEditor
//
//  Redesigned wizard for taco night planning with crown input and person reuse
//

import SwiftUI
import GraphEditorShared

// MARK: - Table Configuration
// Removed TableConfig struct - using simple state variables for single table

@available(watchOS 10.0, *)
struct TacoNightWizard: View {
    let viewModel: GraphViewModel
    let onDismiss: () -> Void
    
    // Wizard state
    @State private var currentStep: WizardStep = .guestCount
    @State private var isCreating: Bool = false
    
    // Step 1: Guest count
    @State private var guestCount: Int = 1
    
    // Step 2: Table configuration (single table, max 12 seats)
    @State private var selectedTableID: UUID?  // ID of existing table being reused
    @State private var needsNewTable: Bool = false
    @State private var tableShape: TableShape = .rectangle
    @State private var tableName: String = "Dining Table"
    @State private var tableCapacity: Int = 8  // Max 12

    // Table dimension editing
    @State private var showingDimensionEditor: Bool = false
    @State private var editingWidth: Double = 40  // Width in inches
    @State private var editingLength: Double = 90 // Length in inches
    @State private var hasCustomDimensions: Bool = false  // Track if user set custom dimensions
    @State private var editingDimension: DimensionType = .length  // Which dimension is being adjusted
    
    // Step 3: Person selection
    @State private var selectedPersonIDs: Set<UUID> = []
    
    // Step 4: Person preferences (if editing)
    @State private var editingPersonIndex: Int = 0
    @State private var personPreferences: [PersonPreferences] = []
    @State private var currentPepperLevel: Int = 0  // For spice stepper
    
    // Step 5: Meal time
    @State private var dinnerTime: Date = {
        let calendar = Calendar.current
        return calendar.date(bySettingHour: 18, minute: 30, second: 0, of: Date()) ?? Date()
    }()
    
    // MARK: - Computed Properties
    
    /// Enforce 12-seat maximum
    private var cappedTableCapacity: Int {
        min(tableCapacity, 12)
    }
    
    /// Calculate head/side seats based on shape and capacity
    private var headSeats: Int {
        tableShape == .rectangle ? 2 : 0
    }
    
    private var sideSeats: Int {
        if tableShape == .rectangle {
            let remainingSeats = max(0, cappedTableCapacity - 4)
            return 1 + (remainingSeats / 2)
        } else {
            return max(1, cappedTableCapacity / 2)
        }
    }
    
    private var totalSeats: Int {
        headSeats * 2 + sideSeats * 2
    }
    
    /// Minimum seats needed for current guest count
    private var minimumSeatsForGuests: Int {
        min(guestCount, 12)
    }
    
    var body: some View {
        NavigationStack {
            Group {
                switch currentStep {
                case .guestCount:
                    guestCountView
                case .tableSelection:
                    tableSelectionView
                case .tableShape:
                    tableShapeView
                case .tableDimensions:
                    tableDimensionsView
                case .personSelection:
                    personSelectionView
                case .personName:
                    personNameView
                case .personProtein:
                    personProteinView
                case .personSpice:
                    personSpiceView
                case .personShell:
                    personShellView
                case .mealTime:
                    mealTimeView
                case .review:
                    reviewView
                }
            }
            .navigationTitle(currentStep == .guestCount ? "" : currentStep.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onDismiss()
                    }
                }
            }
        }
    }
    
    // MARK: - Step 1: Guest Count
    
    private var guestCountView: some View {
        VStack(spacing: 0) {
            Spacer()
            
            Text("🌮 for?")
                .font(.title3)
                .padding(.bottom, 20)
            
            Text("\(guestCount)")
                .font(.system(size: 80, weight: .bold))
                .foregroundColor(.green)
                .focusable(true)
                .digitalCrownRotation(
                    Binding(
                        get: { Double(guestCount) },
                        set: { guestCount = max(1, min(20, Int($0.rounded()))) }
                    ),
                    from: 1,
                    through: 20,
                    by: 1,
                    sensitivity: .high,
                    isContinuous: false
                )
            
            Text(guestCount == 1 ? "person" : "people")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 8)
            
            Spacer()
            
            Button {
                advanceFromGuestCount()
            } label: {
                HStack {
                    Text("Next")
                    Image(systemName: "chevron.right")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal)
            .padding(.bottom)
        }
    }
    
    // MARK: - Step 2: Table Selection
    
    private var tableSelectionView: some View {
        VStack(spacing: 12) {
            // Back button
            HStack {
                Button {
                    currentStep = .guestCount
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.caption2)
                        Text("Back")
                            .font(.caption2)
                    }
                }
                .buttonStyle(.plain)
                .foregroundColor(.blue)
                
                Spacer()
            }
            
            Text("Select or create a table")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Existing tables
            let existingTableNodes = existingTables
            if !existingTableNodes.isEmpty {
                ForEach(existingTableNodes, id: \.id) { table in
                    Button {
                        // Select existing table and skip to person selection
                        selectedTableID = table.id
                        currentStep = .personSelection
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(table.name)
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                Text("\(table.totalSeats) seats")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            if selectedTableID == table.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            }
                        }
                        .padding(8)
                    }
                    .buttonStyle(.bordered)
                }
            }

            // Create new table
            Button {
                needsNewTable = true
                currentStep = .tableShape
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Create New Table")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            
            Spacer()
        }
        .padding()
    }
    
    // MARK: - Step 3a: Table Shape
    
    private var tableShapeView: some View {
        VStack(spacing: 0) {
            Spacer()
            
            VStack(spacing: 4) {
                Text("What shape is")
                    .font(.title3)
                Text("your table?")
                    .font(.title3)
            }
            .multilineTextAlignment(.center)
            .padding(.bottom, 30)
            .padding(.horizontal)
            
            HStack(spacing: 12) {
                ForEach([TableShape.rectangle, TableShape.square, TableShape.circle], id: \.self) { shape in
                    Button {
                        selectTableShape(shape)
                    } label: {
                        VStack(spacing: 4) {
                            Spacer()
                            
                            Image(systemName: shape.icon)
                                .font(.system(size: 40))
                            
                            if tableShape == shape {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            } else {
                                // Spacer to maintain consistent height
                                Image(systemName: "circle")
                                    .font(.caption)
                                    .foregroundColor(.clear)
                            }
                            
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, minHeight: 80)
                    }
                    .buttonStyle(.bordered)
                    .tint(tableShape == shape ? .blue : .gray)
                }
            }
            .padding(.horizontal)
            
            Spacer()
            
            HStack(spacing: 8) {
                Button {
                    currentStep = .tableSelection
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button {
                    currentStep = .tableDimensions
                } label: {
                    HStack {
                        Text("Next")
                        Image(systemName: "chevron.right")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
    }
    
    // MARK: - Step 3b: Visual Table Layout
    
    private var tableDimensionsView: some View {
        VStack(spacing: 8) {
            // Back button
            HStack {
                Button {
                    currentStep = .tableShape
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.caption2)
                        Text("Back")
                            .font(.caption2)
                    }
                }
                .buttonStyle(.plain)
                .foregroundColor(.blue)

                Spacer()
            }
            .padding(.bottom, 4)

            // Visual table with seats
            GeometryReader { geometry in
                let containerWidth = geometry.size.width
                let containerHeight = geometry.size.height
                let tableX = (containerWidth - tableWidth) / 2
                let tableY = (containerHeight - tableHeight) / 2
                    
                    ZStack(alignment: .topLeading) {
                    // Table shape
                    Group {
                        if tableShape == .rectangle {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.brown.opacity(0.3))
                                .frame(width: tableWidth, height: tableHeight)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.brown, lineWidth: 2)
                                )
                                .overlay(
                                    Text(tableDimensionsText)
                                        .font(.system(size: 8))
                                        .foregroundColor(.white)
                                )
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    editingWidth = tableWidthInches
                                    editingLength = tableLengthInches
                                    editingDimension = .length  // Default to length
                                    showingDimensionEditor = true
                                }
                        } else if tableShape == .square {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.brown.opacity(0.3))
                                .frame(width: tableWidth, height: tableWidth)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.brown, lineWidth: 2)
                                )
                                .overlay(
                                    Text(tableDimensionsText)
                                        .font(.system(size: 8))
                                        .foregroundColor(.white)
                                )
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    editingWidth = squareSizeInches
                                    editingLength = squareSizeInches
                                    showingDimensionEditor = true
                                }
                        } else {
                            Circle()
                                .fill(Color.brown.opacity(0.3))
                                .frame(width: tableWidth, height: tableWidth)
                                .overlay(
                                    Circle()
                                        .stroke(Color.brown, lineWidth: 2)
                                )
                                .overlay(
                                    Text(tableDimensionsText)
                                        .font(.system(size: 8))
                                        .foregroundColor(.white)
                                )
                                .contentShape(Circle())
                                .onTapGesture {
                                    editingWidth = circleDiameterInches
                                    editingLength = circleDiameterInches
                                    showingDimensionEditor = true
                                }
                        }
                    }
                    .position(x: tableX + tableWidth / 2, y: tableY + tableHeight / 2)
                    
                    // Place settings
                    ForEach(0..<(tableShape == .circle ? min(guestCount, tableCapacity) : tableCapacity), id: \.self) { index in
                        let seatPos = seatPosition(for: index)
                        let isUsed = tableShape == .circle ? true : (index < guestCount)
                        Circle()
                            .fill(isUsed ? Color.white : Color.clear)
                            .frame(width: plateSize, height: plateSize)
                            .overlay(
                                Circle()
                                    .stroke(Color.gray, lineWidth: 1)
                            )
                            .position(x: tableX + seatPos.x, y: tableY + seatPos.y)
                    }
                    
                    // Overflow indicator for round and square tables
                    if (tableShape == .circle || tableShape == .square) && guestCount > tableCapacity {
                        Text("\(guestCount - tableCapacity) 🪑😔")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.red)
                            .position(x: containerWidth / 2, y: containerHeight - 10)
                    }
                }
            }
            .frame(height: 140)
            
            Spacer()
                .frame(height: 4)

            Button {
                currentStep = .personSelection
            } label: {
                HStack {
                    Text("Next")
                    Image(systemName: "chevron.right")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .padding(.bottom, 8)
        }
        .padding(.horizontal)
        .padding(.top)
        .onAppear {
            // Initialize capacity to minimum needed for guests (unless custom dimensions set)
            if !hasCustomDimensions {
                tableCapacity = minimumSeatsForGuests
            }
        }
        .sheet(isPresented: $showingDimensionEditor) {
            tableDimensionEditorSheet
        }
    }
    
    // MARK: - Step 4: Person Selection
    
    private var personSelectionView: some View {
        VStack(spacing: 8) {
            // Back button
            HStack {
                Button {
                    currentStep = .tableDimensions
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.caption2)
                        Text("Back")
                            .font(.caption2)
                    }
                }
                .buttonStyle(.plain)
                .foregroundColor(.blue)

                Spacer()

                Text("\(selectedPersonIDs.count)/\(guestCount)")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(selectedPersonIDs.count == guestCount ? .green : .secondary)
            }

            Text("Who's coming?")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Scrollable list showing all existing persons
            ScrollView {
                VStack(spacing: 6) {
                    // Show all existing persons
                    ForEach(existingPersons, id: \.id) { person in
                        personCheckboxRow(person: person)
                    }

                    // Add new person button
                    Button {
                        addNewPerson()
                    } label: {
                        HStack {
                            Image(systemName: "person.badge.plus")
                                .font(.caption2)
                            Text("Add Guest")
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }

            Spacer()

            Button {
                preparePersonPreferences()
                currentStep = .personName
            } label: {
                HStack {
                    Text("Next")
                    Image(systemName: "chevron.right")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
    
    private func personCheckboxRow(person: PersonNode) -> some View {
        Button {
            if selectedPersonIDs.contains(person.id) {
                selectedPersonIDs.remove(person.id)
            } else if selectedPersonIDs.count < guestCount {
                selectedPersonIDs.insert(person.id)
            }
        } label: {
            HStack {
                Image(systemName: selectedPersonIDs.contains(person.id) ? "checkmark.square.fill" : "square")
                    .foregroundColor(selectedPersonIDs.contains(person.id) ? .green : .gray)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(person.name)
                        .font(.caption)
                        .fontWeight(.semibold)
                    
                    if let protein = person.proteinPreference, 
                       let spice = person.defaultSpiceLevel,
                       let shell = person.shellPreference {
                        Text("\(protein.rawValue.capitalized), \(spice.capitalized), \(shell.displayName)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
            }
            .padding(8)
        }
        .buttonStyle(.bordered)
    }
    
    // MARK: - Step 5: Person Name
    
    private var personNameView: some View {
        VStack(spacing: 16) {
            if editingPersonIndex < personPreferences.count {
                Spacer()
                
                Text("Guest \(editingPersonIndex + 1) of \(personPreferences.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                TextField("Name", text: Binding(
                    get: { personPreferences[editingPersonIndex].name },
                    set: { personPreferences[editingPersonIndex].name = $0 }
                ))
                .font(.body)
                .multilineTextAlignment(.center)
                
                Spacer()
                
                // Navigation
                HStack {
                    Button {
                        goBackFromPersonPreferences()
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                    .buttonStyle(.bordered)
                    
                    Spacer()
                    
                    Button {
                        currentStep = .personProtein
                    } label: {
                        HStack {
                            Text("Next")
                            Image(systemName: "chevron.right")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding()
    }
    
    // MARK: - Step 6: Person Protein
    
    private var personProteinView: some View {
        VStack(spacing: 16) {
            if editingPersonIndex < personPreferences.count {
                Spacer()
                
                Text(personPreferences[editingPersonIndex].name)
                    .font(.headline)
                
                Text("What protein?")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                VStack(spacing: 12) {
                    ForEach([
                        ("Beef", ProteinType.beef, "🥩"),
                        ("Chicken", ProteinType.chicken, "🍗")
                    ], id: \.1) { label, type, emoji in
                        Button {
                            personPreferences[editingPersonIndex].protein = type
                        } label: {
                            HStack {
                                Text(emoji)
                                Text(label)
                                    .font(.body)
                                Spacer()
                                if personPreferences[editingPersonIndex].protein == type {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                }
                            }
                            .padding()
                            .background(
                                personPreferences[editingPersonIndex].protein == type 
                                    ? Color.blue.opacity(0.2) 
                                    : Color.gray.opacity(0.1)
                            )
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                Spacer()
                
                // Navigation
                HStack {
                    Button {
                        currentStep = .personName
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                    .buttonStyle(.bordered)
                    
                    Spacer()
                    
                    Button {
                        currentStep = .personSpice
                    } label: {
                        HStack {
                            Text("Next")
                            Image(systemName: "chevron.right")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding()
    }
    
    // MARK: - Step 7: Person Spice
    
    private var personSpiceView: some View {
        VStack(spacing: 16) {
            if editingPersonIndex < personPreferences.count {
                Spacer()
                
                Text(personPreferences[editingPersonIndex].name)
                    .font(.headline)
                
                Text("How spicy?")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                // Display current pepper level
                HStack(spacing: 0) {
                    Text(pepperEmoji(for: currentPepperLevel))
                        .font(.system(size: 38))
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                        .fixedSize()
                }
                .frame(height: 50)
                .padding(.vertical, 8)
                
                // Stepper
                HStack {
                    Button {
                        if currentPepperLevel > 0 {
                            currentPepperLevel -= 1
                            personPreferences[editingPersonIndex].spiceLevel = spiceLevelString(for: currentPepperLevel)
                        }
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.title)
                    }
                    .buttonStyle(.plain)
                    .disabled(currentPepperLevel == 0)
                    
                    Spacer()
                    
                    Text("\(currentPepperLevel)")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .frame(minWidth: 40)
                    
                    Spacer()
                    
                    Button {
                        if currentPepperLevel < 5 {
                            currentPepperLevel += 1
                            personPreferences[editingPersonIndex].spiceLevel = spiceLevelString(for: currentPepperLevel)
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title)
                    }
                    .buttonStyle(.plain)
                    .disabled(currentPepperLevel == 5)
                }
                .padding()
                
                Spacer()
                
                // Navigation
                HStack {
                    Button {
                        currentStep = .personProtein
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                    .buttonStyle(.bordered)
                    
                    Spacer()
                    
                    Button {
                        currentStep = .personShell
                    } label: {
                        HStack {
                            Text("Next")
                            Image(systemName: "chevron.right")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding()
        .onAppear {
            // Initialize pepper level from current preference
            currentPepperLevel = pepperCount(for: personPreferences[editingPersonIndex].spiceLevel)
        }
    }
    
    // Helper to convert pepper count to spice level string
    private func spiceLevelString(for pepperCount: Int) -> String {
        switch pepperCount {
        case 0: return "none"
        case 1: return "mild"
        case 2: return "mild-medium"
        case 3: return "medium"
        case 4: return "medium-hot"
        case 5: return "hot"
        default: return "medium"
        }
    }
    
    // Helper to convert spice level string to pepper count
    private func pepperCount(for spiceLevel: String) -> Int {
        switch spiceLevel {
        case "none": return 0
        case "mild": return 1
        case "mild-medium": return 2
        case "medium": return 3
        case "medium-hot": return 4
        case "hot": return 5
        default: return 3
        }
    }
    
    // Helper to get the emoji display for pepper level
    private func pepperEmoji(for count: Int) -> String {
        if count == 0 {
            return "🚫🌶️"
        } else {
            return String(repeating: "🌶️", count: count)
        }
    }
    
    // MARK: - Step 8: Person Shell
    
    private var personShellView: some View {
        VStack(spacing: 16) {
            if editingPersonIndex < personPreferences.count {
                Spacer()
                
                Text(personPreferences[editingPersonIndex].name)
                    .font(.headline)
                
                Text("Hard or soft shell?")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                VStack(spacing: 12) {
                    ForEach([
                        ("Crunchy", ShellType.crunchy, "🌮"),
                        ("Soft Flour", ShellType.softFlour, "🌯"),
                        ("Soft Corn", ShellType.softCorn, "🫔")
                    ], id: \.1) { label, type, emoji in
                        Button {
                            personPreferences[editingPersonIndex].shell = type
                        } label: {
                            HStack {
                                Text(emoji)
                                Text(label)
                                    .font(.body)
                                Spacer()
                                if personPreferences[editingPersonIndex].shell == type {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                }
                            }
                            .padding()
                            .background(
                                personPreferences[editingPersonIndex].shell == type 
                                    ? Color.blue.opacity(0.2) 
                                    : Color.gray.opacity(0.1)
                            )
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                Spacer()
                
                // Navigation
                HStack {
                    Button {
                        currentStep = .personSpice
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                    .buttonStyle(.bordered)
                    
                    Spacer()
                    
                    if editingPersonIndex < personPreferences.count - 1 {
                        Button {
                            editingPersonIndex += 1
                            currentStep = .personName
                        } label: {
                            HStack {
                                Text("Next Guest")
                                Image(systemName: "chevron.right")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    } else {
                        Button {
                            currentStep = .mealTime
                        } label: {
                            HStack {
                                Text("Done")
                                Image(systemName: "checkmark")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
        }
        .padding()
    }
    
    // Helper to go back from person preferences
    private func goBackFromPersonPreferences() {
        if editingPersonIndex > 0 {
            editingPersonIndex -= 1
            currentStep = .personShell  // Go to previous person's last step
        } else {
            currentStep = .personSelection
        }
    }

    
    // MARK: - Step 6: Meal Time
    
    private var mealTimeView: some View {
        VStack(spacing: 20) {
            Text("When's dinner?")
                .font(.headline)
            
            NavigationLink {
                TimePickerView(time: $dinnerTime)
            } label: {
                VStack(spacing: 8) {
                    Text(timeString)
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(.orange)
                    
                    Text("Dinner Time")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            }
            .buttonStyle(.bordered)
            
            Spacer()
            
            Button {
                currentStep = .review
            } label: {
                HStack {
                    Text("Next")
                    Image(systemName: "chevron.right")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
    
    // MARK: - Step 7: Review
    
    private var reviewView: some View {
        ScrollView {
            VStack(spacing: 12) {
                Text("Review & Create")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                // Guest count
                summaryRow(icon: "person.2.fill", title: "Guests", value: "\(guestCount)")
                
                // Table
                if guestCount >= 2 {
                    if let tableID = selectedTableID,
                       let table = viewModel.model.nodes.first(where: { $0.id == tableID })?.unwrapped as? TableNode {
                        summaryRow(icon: "table.furniture", title: "Table", value: table.name)
                    } else if needsNewTable {
                        summaryRow(icon: "table.furniture", title: "Table", value: "\(tableName) (\(tableCapacity) seats)")
                    }
                }
                
                // Time
                summaryRow(icon: "clock.fill", title: "Time", value: timeString)
                
                // Tasks
                summaryRow(icon: "list.bullet", title: "Tasks", value: "17 tasks with assembly workflow")
                
                Spacer()
                
                Button {
                    createTacoNight()
                } label: {
                    if isCreating {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .frame(maxWidth: .infinity)
                    } else {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Create Taco Night")
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isCreating)
            }
            .padding()
        }
    }
    
    private func summaryRow(icon: String, title: String, value: String) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.blue)
                .frame(width: 20)

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer()

            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
        }
        .padding(8)
        .background(Color.gray.opacity(0.2))
        .cornerRadius(8)
    }

    // MARK: - Dimension Editor Sheet

    private var tableDimensionEditorSheet: some View {
        VStack(spacing: 8) {
            // Dimension toggle button (only for rectangles)
            if tableShape == .rectangle {
                HStack {
                    Spacer()

                    Button {
                        editingDimension = editingDimension == .length ? .width : .length
                    } label: {
                        Image(systemName: editingDimension.icon)
                            .font(.title3)
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.bottom, 4)
            }

            // Visual table with seats (reusing same layout)
            GeometryReader { geometry in
                let containerWidth = geometry.size.width
                let containerHeight = geometry.size.height
                
                // Calculate table dimensions based on shape
                let tableWidth: CGFloat = {
                    if tableShape == .circle {
                        return editingWidth * inchToPoint
                    } else if tableShape == .square {
                        return editingWidth * inchToPoint
                    } else {
                        return editingWidth * inchToPoint
                    }
                }()
                
                let tableHeight: CGFloat = {
                    if tableShape == .circle {
                        return editingWidth * inchToPoint
                    } else if tableShape == .square {
                        return editingWidth * inchToPoint
                    } else {
                        return editingLength * inchToPoint
                    }
                }()
                let tableX = (containerWidth - tableWidth) / 2
                let tableY = (containerHeight - tableHeight) / 2
                let editingCapacity = calculatedCapacity(width: editingWidth, length: tableShape == .square ? editingWidth : editingLength)

                ZStack(alignment: .topLeading) {
                    // Table shape
                    Group {
                        if tableShape == .circle {
                            Circle()
                                .fill(Color.brown.opacity(0.3))
                                .frame(width: tableWidth, height: tableWidth)
                                .overlay(
                                    Circle()
                                        .stroke(Color.brown, lineWidth: 2)
                                )
                                .overlay(
                                    Text("\(Int(editingWidth))\"\nø")
                                        .font(.system(size: 8))
                                        .foregroundColor(.white)
                                        .multilineTextAlignment(.center)
                                )
                                .contentShape(Circle())
                        } else {
                            RoundedRectangle(cornerRadius: 8)
                        .fill(Color.brown.opacity(0.3))
                        .frame(width: tableWidth, height: tableHeight)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.brown, lineWidth: 2)
                        )
                        .overlay(
                            Text(tableShape == .square ? "\(Int(editingWidth))\"\nsq" : "\(Int(editingWidth))\"\n×\n\(Int(editingLength))\"")
                                .font(.system(size: 8))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                        )
                        .contentShape(Rectangle())
                        }
                    }
                    .onTapGesture {
                        // Exit editor mode
                        applyCustomDimensions()
                        showingDimensionEditor = false
                    }
                    .position(x: tableX + tableWidth / 2, y: tableY + tableHeight / 2)
                    
                    // Place settings
                    ForEach(0..<(tableShape == .circle ? min(guestCount, editingCapacity) : editingCapacity), id: \.self) { index in
                        let seatPos = calculateSeatPosition(
                            for: index,
                            tableWidth: tableWidth,
                            tableHeight: tableHeight,
                            capacity: tableShape == .circle ? min(guestCount, editingCapacity) : editingCapacity
                        )
                        let isUsed = tableShape == .circle ? true : (index < guestCount)
                        Circle()
                            .fill(isUsed ? Color.white : Color.clear)
                            .frame(width: plateSize, height: plateSize)
                            .overlay(
                                Circle()
                                    .stroke(Color.gray, lineWidth: 1)
                            )
                            .position(x: tableX + seatPos.x, y: tableY + seatPos.y)
                    }
                    
                    // Overflow indicator for round and square tables
                    if (tableShape == .circle || tableShape == .square) && guestCount > editingCapacity {
                        Text("\(guestCount - editingCapacity) 🪑😔")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.red)
                            .position(x: containerWidth / 2, y: containerHeight - 10)
                    }
                }
            }
            .frame(height: 140)
            .focusable(true)
            .digitalCrownRotation(
                Binding(
                    get: {
                        if tableShape == .circle || tableShape == .square {
                            return editingWidth  // Circle and square use one dimension
                        } else {
                            return editingDimension == .length ? editingLength : editingWidth
                        }
                    },
                    set: { newValue in
                        if tableShape == .circle {
                            // Circle: snap to discrete diameters [36, 44, 48, 54, 60, 72]
                            let circleSizes: [Double] = [36, 44, 48, 54, 60, 72]
                            let closest = circleSizes.min(by: { abs($0 - newValue) < abs($1 - newValue) }) ?? 48
                            editingWidth = closest
                            editingLength = closest  // Keep them in sync
                        } else if tableShape == .square {
                            // Square: snap to discrete sizes [36, 48, 60]
                            let squareSizes: [Double] = [36, 48, 60]
                            let closest = squareSizes.min(by: { abs($0 - newValue) < abs($1 - newValue) }) ?? 48
                            editingWidth = closest
                            editingLength = closest  // Keep them in sync
                        } else if editingDimension == .length {
                            // Rectangle length: snap to 12" increments (whole feet)
                            let snapped = round(newValue / 12.0) * 12.0
                            editingLength = max(48, min(144, snapped))
                        } else {
                            // Rectangle width: snap to common widths (36, 40, 42, 48)
                            let commonWidths: [Double] = [36, 40, 42, 48]
                            let closest = commonWidths.min(by: { abs($0 - newValue) < abs($1 - newValue) }) ?? 40
                            editingWidth = closest
                        }
                        // Live update
                        hasCustomDimensions = true
                        let effectiveLength: Double
                        if tableShape == .circle || tableShape == .square {
                            effectiveLength = editingWidth
                        } else {
                            effectiveLength = editingLength
                        }
                        tableCapacity = calculatedCapacity(width: editingWidth, length: effectiveLength)
                    }
                ),
                from: tableShape == .circle ? 36 : (tableShape == .square ? 36 : (editingDimension == .length ? 48 : 36)),
                through: tableShape == .circle ? 72 : (tableShape == .square ? 60 : (editingDimension == .length ? 144 : 48)),
                by: tableShape == .circle ? 6 : (tableShape == .square ? 12 : (editingDimension == .length ? 12 : 1)),
                sensitivity: .high,
                isContinuous: false
            )
            
            Spacer()
                .frame(height: 12)
        }
        .padding(.horizontal)
        .padding(.top)
    }

    // Calculate capacity from custom dimensions
    private func calculatedCapacity(width: Double, length: Double) -> Int {
        switch tableShape {
        case .rectangle:
            // Realistic rectangular table capacity calculation
            // - 1 person at each head (short ends) = 2 total
            // - People on each long side, 24" per person, then multiply by 2 for both sides

            let headSeats = 2  // One at each end
            let seatsPerSide = Int(length / 24.0)  // Seats on ONE side
            let totalSideSeats = seatsPerSide * 2  // Both sides

            return headSeats + totalSideSeats

        case .square:
            // Square table capacity: realistic seating at side midpoints
            // Corners reduce usable space, so capacity is less than perimeter/24
            // 36" square: 4 seats (1 per side)
            // 48" square: 6 seats (1-2 per side, balanced)
            // 60" square: 8 seats (2 per side)
            switch Int(width) {
            case ..<42:  // 36" square
                return 4
            case 42..<54:  // 48" square
                return 6
            default:  // 60"+ square
                return 8
            }

        case .circle:
            // Round table capacity: discrete sizes with realistic seating
            // Even spacing around circumference
            // 36" diameter: 4 seats
            // 44" diameter: 5 seats
            // 48" diameter: 6 seats
            // 54" diameter: 7 seats
            // 60" diameter: 8 seats
            // 72" diameter: 10 seats
            switch Int(width) {
            case ..<40:  // 36" round
                return 4
            case 40..<46:  // 44" round
                return 5
            case 46..<51:  // 48" round
                return 6
            case 51..<57:  // 54" round
                return 7
            case 57..<66:  // 60" round
                return 8
            default:  // 72"+ round
                return 10
            }
        }
    }

    // Apply custom dimensions (called when exiting editor)
    private func applyCustomDimensions() {
        // Already applied live during editing
    }

    // MARK: - Helpers
    
    // Visual dimensions for table rendering (in points, scaled from inches)
    // Scale: 1 inch = 0.8 points for watch display (scaled to fit 12-seater)
    private let inchToPoint: CGFloat = 0.8

    // Table width in inches
    private var tableWidthInches: CGFloat {
        if hasCustomDimensions {
            return editingWidth
        }
        return 40  // Standard dining table width (36-42" typical)
    }

    // Real-world dining table lengths (Average column from standard sizing)
    // Based on ~24" per person with 2 head seats + side seats
    private var tableLengthInches: CGFloat {
        if hasCustomDimensions {
            return editingLength
        }

        switch tableCapacity {
        case 2: return 48   // Small 2-seater
        case 3...4: return 60   // 48-60" for 4 people (average)
        case 5...6: return 72   // 60-72" for 6 people (average)
        case 7...8: return 90   // 80-96" for 8 people (average: 90")
        case 9...10: return 102  // 96-108" for 10 people (average: 102")
        case 11...12: return 126 // 120-132" for 12 people (average: 126")
        default: return 144      // 12'+ extension table
        }
    }
    
    // Square table size in inches (discrete sizes: 36", 48", 60")
    private var squareSizeInches: CGFloat {
        if hasCustomDimensions {
            return editingWidth  // For square, width = height
        }

        // Pick smallest square that fits guest count
        // 36" square: 4 seats (1 per side)
        // 48" square: 6 seats (balanced across sides)
        // 60" square: 8 seats (2 per side)

        switch tableCapacity {
        case ...4: return 36
        case 5...6: return 48
        default: return 60
        }
    }

    // Round table diameter in inches (discrete sizes with realistic capacities)
    private var circleDiameterInches: CGFloat {
        if hasCustomDimensions {
            return editingWidth  // For circle, width = diameter
        }

        // Pick smallest round table that fits guest count
        // Even spacing around circumference
        // 36" diameter: 4 seats
        // 44" diameter: 5 seats
        // 48" diameter: 6 seats
        // 54" diameter: 7 seats
        // 60" diameter: 8 seats
        // 72" diameter: 10 seats

        switch tableCapacity {
        case ...4: return 36
        case 5: return 44
        case 6: return 48
        case 7: return 54
        case 8: return 60
        default: return 72
        }
    }
    
    private var tableWidth: CGFloat {
        switch tableShape {
        case .rectangle:
            return tableWidthInches * inchToPoint
        case .square:
            return squareSizeInches * inchToPoint
        case .circle:
            return circleDiameterInches * inchToPoint
        }
    }
    
    private var tableHeight: CGFloat {
        switch tableShape {
        case .rectangle:
            // Use real-world dining table dimensions
            return tableLengthInches * inchToPoint
        case .square:
            return tableWidth  // Square
        case .circle:
            return tableWidth  // Circle diameter
        }
    }
    
    private var plateSize: CGFloat {
        10 * inchToPoint  // 10" dinner plate = 8pt at 0.8 scale
    }
    
    private var tableDimensionsText: String {
        switch tableShape {
        case .rectangle:
            return "\(Int(tableWidthInches))\"\n×\n\(Int(tableLengthInches))\""
        case .square:
            return "\(Int(squareSizeInches))\"\nsq"
        case .circle:
            return "\(Int(circleDiameterInches))\""
        }
    }

    // Calculate dining space per person in inches
    private var spacePerPerson: CGFloat {
        guard guestCount > 0 else { return 0 }

        switch tableShape {
        case .rectangle:
            // Perimeter available for seating (both long sides + both short ends)
            let longSidesTotal = tableLengthInches * 2
            let shortSidesTotal = tableWidthInches * 2
            let totalPerimeter = longSidesTotal + shortSidesTotal
            return totalPerimeter / CGFloat(guestCount)

        case .square:
            // All 4 sides available
            let perimeterInches = CGFloat(tableCapacity) * 24
            return perimeterInches / CGFloat(guestCount)

        case .circle:
            // Full circumference available
            let circumferenceInches = CGFloat(tableCapacity) * 24
            return circumferenceInches / CGFloat(guestCount)
        }
    }

    // Crowding assessment based on space per person
    private var crowdingLevel: String {
        let space = spacePerPerson

        // Industry standards:
        // - 24"+ per person: Comfortable
        // - 20-24": Average
        // - 15-20": Tight/Cozy
        // - <15": Crowded

        switch space {
        case 24...:
            return "Comfortable"
        case 20..<24:
            return "Average"
        case 15..<20:
            return "Cozy"
        default:
            return "Tight"
        }
    }

    // Color indicator for crowding level
    private var crowdingColor: Color {
        let space = spacePerPerson

        switch space {
        case 24...:
            return .green
        case 20..<24:
            return .blue
        case 15..<20:
            return .orange
        default:
            return .red
        }
    }

    // Calculate position for seat at given index
    // Seating priority: Head (0), Sides (1...n-1), Foot (n) - foot filled last
    private func seatPosition(for index: Int) -> CGPoint {
        let centerX = tableWidth / 2
        let centerY = tableHeight / 2
        let offset = plateSize / 2 + 4  // Offset from table edge (plate edge to table edge)
        
        switch tableShape {
        case .rectangle:
            // Rectangular table seating priority:
            // 1. Head seat (top) - index 0
            // 2. Side seats - indices 1 through (capacity-2)
            // 3. Foot seat (bottom) - index (capacity-1), filled last
            
            if index == 0 {
                // Head seat (top) - always first
                return CGPoint(x: centerX, y: -offset)
            } else if index == tableCapacity - 1 && tableCapacity >= 2 {
                // Foot seat (bottom) - always last
                return CGPoint(x: centerX, y: tableHeight + offset)
            } else {
                // Side seats - indices 1 through (capacity-2)
                let sideIndex = index - 1
                let isLeftSide = sideIndex % 2 == 0  // Even indices on left, odd on right
                let positionOnSide = sideIndex / 2
                
                let sideSeatsTotal = max(0, tableCapacity - 2)
                let seatsPerSide = (sideSeatsTotal + 1) / 2  // Left side gets extra if odd
                
                if isLeftSide {
                    // Left side
                    let yPos = tableHeight * CGFloat(positionOnSide + 1) / CGFloat(seatsPerSide + 1)
                    return CGPoint(x: -offset, y: yPos)
                } else {
                    // Right side - aligned across from left
                    let yPos = tableHeight * CGFloat(positionOnSide + 1) / CGFloat(seatsPerSide + 1)
                    return CGPoint(x: tableWidth + offset, y: yPos)
                }
            }
            
        case .square:
            // Square tables: seats on side midpoints (not corners)
            // Distribute across 4 sides: top, right, bottom, left
            switch tableCapacity {
            case 4:
                // 1 per side: top, right, bottom, left
                switch index {
                case 0: return CGPoint(x: centerX, y: -offset)  // Top
                case 1: return CGPoint(x: tableWidth + offset, y: centerY)  // Right
                case 2: return CGPoint(x: centerX, y: tableHeight + offset)  // Bottom
                case 3: return CGPoint(x: -offset, y: centerY)  // Left
                default: return CGPoint(x: centerX, y: centerY)
                }
            case 6:
                // 2 on long sides (top/bottom), 1 on short sides (left/right)
                // Order: top-left, top-right, right, bottom-right, bottom-left, left
                switch index {
                case 0: return CGPoint(x: centerX - tableWidth/4, y: -offset)  // Top-left
                case 1: return CGPoint(x: centerX + tableWidth/4, y: -offset)  // Top-right
                case 2: return CGPoint(x: tableWidth + offset, y: centerY)  // Right
                case 3: return CGPoint(x: centerX + tableWidth/4, y: tableHeight + offset)  // Bottom-right
                case 4: return CGPoint(x: centerX - tableWidth/4, y: tableHeight + offset)  // Bottom-left
                case 5: return CGPoint(x: -offset, y: centerY)  // Left
                default: return CGPoint(x: centerX, y: centerY)
                }
            case 8:
                // 2 per side
                switch index {
                case 0: return CGPoint(x: centerX - tableWidth/4, y: -offset)  // Top-left
                case 1: return CGPoint(x: centerX + tableWidth/4, y: -offset)  // Top-right
                case 2: return CGPoint(x: tableWidth + offset, y: centerY - tableHeight/4)  // Right-top
                case 3: return CGPoint(x: tableWidth + offset, y: centerY + tableHeight/4)  // Right-bottom
                case 4: return CGPoint(x: centerX + tableWidth/4, y: tableHeight + offset)  // Bottom-right
                case 5: return CGPoint(x: centerX - tableWidth/4, y: tableHeight + offset)  // Bottom-left
                case 6: return CGPoint(x: -offset, y: centerY + tableHeight/4)  // Left-bottom
                case 7: return CGPoint(x: -offset, y: centerY - tableHeight/4)  // Left-top
                default: return CGPoint(x: centerX, y: centerY)
                }
            default:
                // Fallback to radial for other capacities
                let radius = (tableWidth / 2) + offset
                let angle = (2 * .pi * CGFloat(index)) / CGFloat(tableCapacity) - (.pi / 2)
                let x = centerX + cos(angle) * radius
                let y = centerY + sin(angle) * radius
                return CGPoint(x: x, y: y)
            }

        case .circle:
            // Round tables: distribute seated guests evenly around perimeter (capped at capacity)
            let seatedCount = min(guestCount, tableCapacity)
            let radius = (tableWidth / 2) + offset
            let angle = (2 * .pi * CGFloat(index)) / CGFloat(seatedCount) - (.pi / 2)  // Start at top
            let x = centerX + cos(angle) * radius
            let y = centerY + sin(angle) * radius
            return CGPoint(x: x, y: y)
        }
    }
    
    // Calculate seat position with custom dimensions (for editor)
    private func calculateSeatPosition(
        for index: Int,
        tableWidth: CGFloat,
        tableHeight: CGFloat,
        capacity: Int
    ) -> CGPoint {
        let centerX = tableWidth / 2
        let centerY = tableHeight / 2
        let offset = plateSize / 2 + 4

        switch tableShape {
        case .rectangle:
            // Rectangle seating priority: head, sides, foot (last)
            if index == 0 {
                // Head seat (top) - always first
                return CGPoint(x: centerX, y: -offset)
            } else if index == capacity - 1 && capacity >= 2 {
                // Foot seat (bottom) - always last
                return CGPoint(x: centerX, y: tableHeight + offset)
            } else {
                // Side seats
                let sideIndex = index - 1
                let isLeftSide = sideIndex % 2 == 0
                let positionOnSide = sideIndex / 2

                let sideSeatsTotal = max(0, capacity - 2)
                let seatsPerSide = (sideSeatsTotal + 1) / 2

                if isLeftSide {
                    let yPos = tableHeight * CGFloat(positionOnSide + 1) / CGFloat(seatsPerSide + 1)
                    return CGPoint(x: -offset, y: yPos)
                } else {
                    let yPos = tableHeight * CGFloat(positionOnSide + 1) / CGFloat(seatsPerSide + 1)
                    return CGPoint(x: tableWidth + offset, y: yPos)
                }
            }

        case .square:
            // Square tables: seats on side midpoints (not corners)
            switch capacity {
            case 4:
                switch index {
                case 0: return CGPoint(x: centerX, y: -offset)
                case 1: return CGPoint(x: tableWidth + offset, y: centerY)
                case 2: return CGPoint(x: centerX, y: tableHeight + offset)
                case 3: return CGPoint(x: -offset, y: centerY)
                default: return CGPoint(x: centerX, y: centerY)
                }
            case 6:
                switch index {
                case 0: return CGPoint(x: centerX - tableWidth/4, y: -offset)
                case 1: return CGPoint(x: centerX + tableWidth/4, y: -offset)
                case 2: return CGPoint(x: tableWidth + offset, y: centerY)
                case 3: return CGPoint(x: centerX + tableWidth/4, y: tableHeight + offset)
                case 4: return CGPoint(x: centerX - tableWidth/4, y: tableHeight + offset)
                case 5: return CGPoint(x: -offset, y: centerY)
                default: return CGPoint(x: centerX, y: centerY)
                }
            case 8:
                switch index {
                case 0: return CGPoint(x: centerX - tableWidth/4, y: -offset)
                case 1: return CGPoint(x: centerX + tableWidth/4, y: -offset)
                case 2: return CGPoint(x: tableWidth + offset, y: centerY - tableHeight/4)
                case 3: return CGPoint(x: tableWidth + offset, y: centerY + tableHeight/4)
                case 4: return CGPoint(x: centerX + tableWidth/4, y: tableHeight + offset)
                case 5: return CGPoint(x: centerX - tableWidth/4, y: tableHeight + offset)
                case 6: return CGPoint(x: -offset, y: centerY + tableHeight/4)
                case 7: return CGPoint(x: -offset, y: centerY - tableHeight/4)
                default: return CGPoint(x: centerX, y: centerY)
                }
            default:
                let radius = (tableWidth / 2) + offset
                let angle = (2 * .pi * CGFloat(index)) / CGFloat(capacity) - (.pi / 2)
                let x = centerX + cos(angle) * radius
                let y = centerY + sin(angle) * radius
                return CGPoint(x: x, y: y)
            }

        case .circle:
            // Radial distribution around perimeter
            let radius = (tableWidth / 2) + offset
            let angle = (2 * .pi * CGFloat(index)) / CGFloat(capacity) - (.pi / 2)  // Start at top
            let x = centerX + cos(angle) * radius
            let y = centerY + sin(angle) * radius
            return CGPoint(x: x, y: y)
        }
    }
    
    private var timeString: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: dinnerTime)
    }
    
    private var existingTables: [TableNode] {
        viewModel.model.nodes.compactMap { $0.unwrapped as? TableNode }
    }
    
    private var existingPersons: [PersonNode] {
        viewModel.model.nodes.compactMap { $0.unwrapped as? PersonNode }
    }
    
    private func advanceFromGuestCount() {
        if guestCount >= 2 {
            // Check if tables exist
            if existingTables.isEmpty {
                needsNewTable = true
                currentStep = .tableShape
            } else {
                currentStep = .tableSelection
            }
        } else {
            // Bachelor mode - skip table and person selection, go directly to preferences
            preparePersonPreferences()
            currentStep = .personName
        }
    }
    
    private func selectTableShape(_ shape: TableShape) {
        tableShape = shape
        tableCapacity = min(guestCount, 12)  // Auto-size to guest count, max 12
        currentStep = .tableDimensions
    }
    
    private func addNewPerson() {
        // Create temporary person preference
        let newPref = PersonPreferences(
            id: nil,
            name: "Guest \(selectedPersonIDs.count + 1)",
            protein: .beef,
            spiceLevel: "medium",
            shell: .softFlour,
            toppings: [],
            restrictions: []
        )
        
        // Add to selection (use temporary UUID)
        let tempID = UUID()
        selectedPersonIDs.insert(tempID)
        
        // Store for later creation
        personPreferences.append(newPref)
    }
    
    private func preparePersonPreferences() {
        // Load preferences for selected persons
        personPreferences = []
        
        for personID in selectedPersonIDs {
            if let person = viewModel.model.nodes.first(where: { $0.id == personID })?.unwrapped as? PersonNode {
                // Existing person - load their preferences
                personPreferences.append(PersonPreferences(
                    id: person.id,
                    name: person.name,
                    protein: person.proteinPreference ?? .beef,
                    spiceLevel: person.defaultSpiceLevel ?? "medium",
                    shell: person.shellPreference ?? .softFlour,
                    toppings: person.toppingPreferences,
                    restrictions: person.dietaryRestrictions
                ))
            }
        }
        
        // Auto-create blank guests for remaining slots
        let needed = guestCount - selectedPersonIDs.count
        for i in 0..<needed {
            personPreferences.append(PersonPreferences(
                id: UUID(),
                name: "Guest \(selectedPersonIDs.count + i + 1)",
                protein: .beef,
                spiceLevel: "medium",
                shell: .softFlour,
                toppings: [],
                restrictions: []
            ))
        }
        
        editingPersonIndex = 0
    }
    
    private func createTacoNight() {
        isCreating = true
        
        Task { @MainActor in
            let centerX: CGFloat = 102.5
            let centerY: CGFloat = 125.0

            var tableID: UUID? = nil

            // 1. Create table if needed (single table, max 12 seats)
            if guestCount >= 2 {
                if needsNewTable {
                    // Create new table with single-table properties
                    let table = await viewModel.model.addTable(
                        name: tableName,
                        headSeats: headSeats,
                        sideSeats: sideSeats,
                        at: CGPoint(x: centerX, y: centerY - 60)
                    )
                    tableID = table.id

                    // Set table segment config (horizontal layout for persons around table)
                    viewModel.model.setSegmentConfig(
                        rootNodeID: table.id,
                        direction: .horizontal,
                        strength: 2.0,
                        nodeSpacing: 50.0
                    )
                } else if let existingTableID = selectedTableID {
                    // Using existing table
                    tableID = existingTableID
                }
            }
            
            // 2. Create persons with preferences
            var personIDs: [UUID] = []
            for pref in personPreferences {
                if let existingID = pref.id {
                    // Reusing existing person
                    personIDs.append(existingID)
                } else {
                    // Create new person
                    let person = await viewModel.model.addPerson(
                        name: pref.name,
                        defaultSpiceLevel: pref.spiceLevel,
                        dietaryRestrictions: pref.restrictions,
                        proteinPreference: pref.protein,
                        shellPreference: pref.shell,
                        toppingPreferences: pref.toppings,
                        at: CGPoint(x: centerX, y: centerY)
                    )
                    personIDs.append(person.id)
                }
            }
            
            // 3. Assign persons to single table if applicable (max 12 seats)
            if guestCount >= 2, let tableID = tableID {
                let maxSeats = min(guestCount, 12)  // Cap at 12 seats

                for (index, personID) in personIDs.prefix(maxSeats).enumerated() {
                    await viewModel.model.assignPersonToTable(
                        personID: personID,
                        tableID: tableID,
                        seatIndex: index
                    )
                }
            }
            
            // 4. Create meal with task hierarchy
            // For now, use first person's protein preference (TODO: aggregate preferences)
            let primaryProtein = personPreferences.first?.protein ?? .beef
            
            _ = await TacoTemplateBuilder.buildGraph(
                in: viewModel.model,
                guests: guestCount,
                dinnerTime: dinnerTime,
                protein: primaryProtein,
                at: CGPoint(x: 20, y: centerY + 60)
            )
            
            // 5. Start simulation
            await viewModel.model.startSimulation()
            
            isCreating = false
            onDismiss()
        }
    }
    
}

// MARK: - Supporting Types

enum WizardStep: Int, CaseIterable {
    case guestCount = 0
    case tableSelection = 1
    case tableShape = 2
    case tableDimensions = 3
    case personSelection = 4
    case personName = 5
    case personProtein = 6
    case personSpice = 7
    case personShell = 8
    case mealTime = 9
    case review = 10
    
    var title: String {
        switch self {
        case .guestCount: return "Guest Count"
        case .tableSelection: return "Select Table"
        case .tableShape: return "Table Shape"
        case .tableDimensions: return "Table Size"
        case .personSelection: return "Guests"
        case .personName: return "Name"
        case .personProtein: return "Protein"
        case .personSpice: return "Spice Level"
        case .personShell: return "Shell Type"
        case .mealTime: return "Meal Time"
        case .review: return "Review"
        }
    }
}

enum TableShape: String {
    case rectangle
    case square
    case circle
    
    var icon: String {
        switch self {
        case .rectangle: return "rectangle"
        case .square: return "square"
        case .circle: return "circle"
        }
    }
}

enum DimensionType {
    case width
    case length
    
    var icon: String {
        switch self {
        case .width: return "arrow.left.and.right"
        case .length: return "arrow.up.and.down"
        }
    }
}

struct PersonPreferences {
    var id: UUID?  // nil for new persons
    var name: String
    var protein: ProteinType
    var spiceLevel: String
    var shell: ShellType
    var toppings: [String]
    var restrictions: [String]
}

// MARK: - Preview Helper

@available(watchOS 10.0, *)
struct TableLayoutPreview: View {
    @State private var guestCount: Int = 7
    @State private var tableCapacity: Int = 7
    @State private var tableShape: TableShape = .rectangle
    
    // Realistic dimensions
    private let inchToPoint: CGFloat = 0.8  // Scaled down for preview
    private let tableWidthInches: CGFloat = 40  // Standard dining table width
    
    private var tableLengthInches: CGFloat {
        switch tableCapacity {
        case 2: return 48
        case 3...4: return 60
        case 5...6: return 72
        case 7...8: return 90
        case 9...10: return 102
        case 11...12: return 126
        default: return 144
        }
    }
    
    private var squareSizeInches: CGFloat {
        // Square table discrete sizes (matching main view logic)
        switch tableCapacity {
        case ...4: return 36
        case 5...6: return 48
        default: return 60
        }
    }
    
    private var tableWidth: CGFloat {
        switch tableShape {
        case .rectangle:
            return tableWidthInches * inchToPoint
        case .square:
            return squareSizeInches * inchToPoint
        case .circle:
            let circumferenceInches = CGFloat(tableCapacity) * 24
            let diameter = circumferenceInches / .pi
            return diameter * inchToPoint
        }
    }
    
    private var tableHeight: CGFloat {
        switch tableShape {
        case .rectangle:
            return tableLengthInches * inchToPoint
        case .square:
            return tableWidth
        case .circle:
            return tableWidth
        }
    }
    
    private var personNodeSize: CGFloat {
        10 * inchToPoint  // 10" dinner plate
    }

    private var tableDimensionsText: String {
        switch tableShape {
        case .rectangle:
            return "\(Int(tableWidthInches))\"\n×\n\(Int(tableLengthInches))\""
        case .square:
            return "\(Int(squareSizeInches))\"\nsq"
        case .circle:
            let circumferenceInches = CGFloat(tableCapacity) * 24
            let diameter = circumferenceInches / .pi
            return "\(Int(diameter))\""
        }
    }

    private var spacePerPerson: CGFloat {
        guard guestCount > 0 else { return 0 }
        switch tableShape {
        case .rectangle:
            let longSidesTotal = tableLengthInches * 2
            let shortSidesTotal = tableWidthInches * 2
            let totalPerimeter = longSidesTotal + shortSidesTotal
            return totalPerimeter / CGFloat(guestCount)
        case .square:
            let perimeterInches = CGFloat(tableCapacity) * 24
            return perimeterInches / CGFloat(guestCount)
        case .circle:
            let circumferenceInches = CGFloat(tableCapacity) * 24
            return circumferenceInches / CGFloat(guestCount)
        }
    }

    private func seatPosition(for index: Int) -> CGPoint {
        let centerX = tableWidth / 2
        let centerY = tableHeight / 2
        let offset = personNodeSize / 2 + 4
        
        switch tableShape {
        case .rectangle:
            // 1 seat at each head, rest on sides
            if index == 0 && tableCapacity >= 1 {
                return CGPoint(x: centerX, y: -offset)
            } else if index == 1 && tableCapacity >= 2 {
                return CGPoint(x: centerX, y: tableHeight + offset)
            } else {
                let sideSeatsTotal = max(0, tableCapacity - 2)
                let seatsPerSide = sideSeatsTotal / 2
                let extraSeat = sideSeatsTotal % 2
                
                let sideIndex = index - 2
                
                if sideIndex < seatsPerSide {
                    // Left side
                    let yPos = tableHeight * CGFloat(sideIndex + 1) / CGFloat(seatsPerSide + 1)
                    return CGPoint(x: -offset, y: yPos)
                } else {
                    // Right side
                    let rightIndex = sideIndex - seatsPerSide
                    let rightSeats = seatsPerSide + extraSeat
                    let yPos = tableHeight * CGFloat(rightIndex + 1) / CGFloat(rightSeats + 1)
                    return CGPoint(x: tableWidth + offset, y: yPos)
                }
            }
            
        case .square, .circle:
            let radius = (tableWidth / 2) + offset
            let angle = (2 * .pi * CGFloat(index)) / CGFloat(tableCapacity) - (.pi / 2)
            let x = centerX + cos(angle) * radius
            let y = centerY + sin(angle) * radius
            return CGPoint(x: x, y: y)
        }
    }
    
    var body: some View {
        VStack(spacing: 12) {
            Text("Table: \(Int(tableWidth))×\(Int(tableHeight))pt")
                .font(.caption2)
            
            Text("Plate: \(Int(personNodeSize))pt (10\" dinner)")
                .font(.caption2)
            
            GeometryReader { geometry in
                let containerWidth = geometry.size.width
                let containerHeight = geometry.size.height
                let tableX = (containerWidth - tableWidth) / 2
                let tableY = (containerHeight - tableHeight) / 2
                
                ZStack(alignment: .topLeading) {
                    // Table
                    Group {
                        if tableShape == .rectangle {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.brown.opacity(0.3))
                                .frame(width: tableWidth, height: tableHeight)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .stroke(Color.brown, lineWidth: 2)
                                )
                                .overlay(
                                    Text(tableDimensionsText)
                                        .font(.system(size: 8))
                                        .foregroundColor(.white)
                                )
                        } else if tableShape == .square {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.brown.opacity(0.3))
                                .frame(width: tableWidth, height: tableWidth)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .stroke(Color.brown, lineWidth: 2)
                                )
                                .overlay(
                                    Text(tableDimensionsText)
                                        .font(.system(size: 8))
                                        .foregroundColor(.white)
                                )
                        } else {
                            Circle()
                                .fill(Color.brown.opacity(0.3))
                                .frame(width: tableWidth, height: tableWidth)
                                .overlay(
                                    Circle()
                                        .stroke(Color.brown, lineWidth: 2)
                                )
                                .overlay(
                                    Text(tableDimensionsText)
                                        .font(.system(size: 8))
                                        .foregroundColor(.white)
                                )
                        }
                    }
                    .position(x: tableX + tableWidth / 2, y: tableY + tableHeight / 2)
                    
                    // All possible place settings (outlines)
                    ForEach(0..<tableCapacity, id: \.self) { index in
                        let seatPos = seatPosition(for: index)
                        let isUsed = index < guestCount
                        Circle()
                            .fill(isUsed ? Color.white : Color.clear)
                            .frame(width: personNodeSize, height: personNodeSize)
                            .overlay(
                                Circle()
                                    .stroke(Color.gray, lineWidth: 1)
                            )
                            .position(x: tableX + seatPos.x, y: tableY + seatPos.y)
                    }
                }
            }
            .frame(height: 150)
            .border(Color.gray.opacity(0.3))
            
            HStack {
                Button("-") { if tableCapacity > 2 { tableCapacity -= 1 } }
                Text("\(tableCapacity) seats")
                    .font(.caption)
                Button("+") { if tableCapacity < 20 { tableCapacity += 1 } }
            }
        }
        .padding()
    }
}

#Preview("Table Layout - 7 guests") {
    TableLayoutPreview()
}
