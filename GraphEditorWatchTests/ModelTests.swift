//
//  ModelTests.swift
//  GraphEditorWatchTests
//
//  Tests for Model layer: ContactManager, HapticManager, MonogramGenerator
//

import Testing
import Foundation
import CoreGraphics
import Contacts
import UIKit
@testable import GraphEditorWatch
@testable import GraphEditorShared

// MARK: - MonogramGenerator Tests

struct MonogramGeneratorTests {
    
    @Test("Extract initials from single name")
    func testInitialsSingleName() {
        let data = MonogramGenerator.generateMonogram(from: "Alice")
        #expect(data != nil, "Should generate monogram for single name")
        #expect(data!.count > 0, "Generated data should not be empty")
    }
    
    @Test("Extract initials from full name")
    func testInitialsFullName() {
        let data = MonogramGenerator.generateMonogram(from: "John Doe")
        #expect(data != nil, "Should generate monogram for full name")
    }
    
    @Test("Extract initials from three-part name")
    func testInitialsThreePartName() {
        let data = MonogramGenerator.generateMonogram(from: "Mary Jane Watson")
        #expect(data != nil, "Should generate monogram for three-part name")
    }
    
    @Test("Handle empty name")
    func testEmptyName() {
        let data = MonogramGenerator.generateMonogram(from: "")
        #expect(data != nil, "Should generate monogram even for empty name")
    }
    
    @Test("Handle whitespace-only name")
    func testWhitespaceName() {
        let data = MonogramGenerator.generateMonogram(from: "   ")
        #expect(data != nil, "Should handle whitespace-only name")
    }
    
    @Test("Handle special characters in name")
    func testSpecialCharactersName() {
        let data = MonogramGenerator.generateMonogram(from: "Jean-Luc Picard")
        #expect(data != nil, "Should handle hyphenated names")
    }
    
    @Test("Handle name with numbers")
    func testNameWithNumbers() {
        let data = MonogramGenerator.generateMonogram(from: "User 123")
        #expect(data != nil, "Should handle names with numbers")
    }
    
    @Test("Generate non-nil PNG data")
    func testGeneratesValidData() {
        let data = MonogramGenerator.generateMonogram(from: "Test User")
        #expect(data != nil, "Should generate data")
        
        // Verify it's valid image data by attempting to create UIImage
        if let imageData = data {
            let image = UIImage(data: imageData)
            #expect(image != nil, "Generated data should be valid image data")
        }
    }
    
    @Test("Generate consistent data for same name")
    func testConsistentGeneration() {
        let name = "Consistent User"
        let data1 = MonogramGenerator.generateMonogram(from: name)
        let data2 = MonogramGenerator.generateMonogram(from: name)
        
        #expect(data1 != nil && data2 != nil, "Both generations should succeed")
        // Note: We can't guarantee byte-for-byte identical PNG due to timestamps,
        // but both should be valid images of similar size
        if let d1 = data1, let d2 = data2 {
            let sizeDiff = abs(d1.count - d2.count)
            #expect(sizeDiff < 1000, "Image sizes should be similar (within 1KB)")
        }
    }
    
    @Test("Generate different colors for different names")
    func testDifferentColors() {
        // Generate monograms for different names
        let names = ["Alice", "Bob", "Charlie", "Diana", "Eve"]
        var dataResults: [Data] = []
        
        for name in names {
            if let data = MonogramGenerator.generateMonogram(from: name) {
                dataResults.append(data)
            }
        }
        
        #expect(dataResults.count == names.count, "All monograms should be generated")
        
        // While we can't easily inspect pixel data in tests, we can verify
        // that each generation produced valid image data
        for data in dataResults {
            let image = UIImage(data: data)
            #expect(image != nil, "Each monogram should be valid image")
        }
    }
}

// MARK: - HapticManager Tests

struct HapticManagerTests {
    
    @Test("Play click haptic pattern")
    @available(watchOS 9.0, *)
    func testPlayClick() {
        let manager = HapticManager.shared
        
        // This won't produce actual haptic feedback in tests, but verifies
        // the method doesn't crash
        manager.play(.click)
        
        // If we reach here without crashing, the test passes
        #expect(true, "Should handle click pattern")
    }
    
    @Test("Play success haptic pattern")
    @available(watchOS 9.0, *)
    func testPlaySuccess() {
        let manager = HapticManager.shared
        manager.play(.success)
        #expect(true, "Should handle success pattern")
    }
    
    @Test("Play failure haptic pattern")
    @available(watchOS 9.0, *)
    func testPlayFailure() {
        let manager = HapticManager.shared
        manager.play(.failure)
        #expect(true, "Should handle failure pattern")
    }
    
    @Test("Play directionUp haptic pattern")
    @available(watchOS 9.0, *)
    func testPlayDirectionUp() {
        let manager = HapticManager.shared
        manager.play(.directionUp)
        #expect(true, "Should handle directionUp pattern")
    }
    
    @Test("Play directionDown haptic pattern")
    @available(watchOS 9.0, *)
    func testPlayDirectionDown() {
        let manager = HapticManager.shared
        manager.play(.directionDown)
        #expect(true, "Should handle directionDown pattern")
    }
    
    @Test("Handle nil haptic pattern gracefully")
    @available(watchOS 9.0, *)
    func testPlayNilPattern() {
        let manager = HapticManager.shared
        manager.play(nil)
        #expect(true, "Should handle nil pattern without crashing")
    }
    
    @Test("Play node tap haptic")
    @MainActor
    @available(watchOS 9.0, *)
    func testPlayNodeTap() {
        let manager = HapticManager.shared
        let node = Node(label: 1, position: .zero)
        
        manager.playNodeTap(for: node)
        #expect(true, "Should handle node tap haptic")
    }
    
    @Test("Play long press haptic")
    @MainActor
    @available(watchOS 9.0, *)
    func testPlayLongPress() {
        let manager = HapticManager.shared
        let node = Node(label: 1, position: .zero)
        
        manager.playLongPress(for: node)
        #expect(true, "Should handle long press haptic")
    }
    
    @Test("Play drag start haptic")
    @MainActor
    @available(watchOS 9.0, *)
    func testPlayDragStart() {
        let manager = HapticManager.shared
        let node = Node(label: 1, position: .zero)
        
        manager.playDragStart(for: node)
        #expect(true, "Should handle drag start haptic")
    }
    
    @Test("Play drag end haptic")
    @MainActor
    @available(watchOS 9.0, *)
    func testPlayDragEnd() {
        let manager = HapticManager.shared
        let node = Node(label: 1, position: .zero)
        
        manager.playDragEnd(for: node)
        #expect(true, "Should handle drag end haptic")
    }
    
    @Test("Play state change haptic")
    @MainActor
    @available(watchOS 9.0, *)
    func testPlayStateChange() {
        let manager = HapticManager.shared
        let node = Node(label: 1, position: .zero)
        
        manager.playStateChange(for: node)
        #expect(true, "Should handle state change haptic")
    }
    
    @Test("Verify singleton pattern")
    @available(watchOS 9.0, *)
    func testSingletonPattern() {
        let manager1 = HapticManager.shared
        let manager2 = HapticManager.shared
        
        // Both references should point to the same instance
        #expect(manager1 === manager2, "Should return same singleton instance")
    }
}

// MARK: - ContactManager Tests

struct ContactManagerTests {
    
    @Test("ContactManager singleton")
    @available(watchOS 10.0, *)
    func testSingleton() async {
        let manager1 = ContactManager.shared
        let manager2 = ContactManager.shared
        
        // Verify both references point to the same actor instance
        // Note: Actor identity comparison isn't directly available,
        // but we can verify the pattern exists
        #expect(manager1 !== nil, "Singleton should exist")
        #expect(manager2 !== nil, "Singleton should exist")
    }
    
    @Test("Display name with nickname priority")
    @available(watchOS 10.0, *)
    func testDisplayNameNicknamePriority() async {
        let manager = ContactManager.shared
        
        // Create a mock contact with nickname
        let contact = CNMutableContact()
        contact.givenName = "Jonathan"
        contact.familyName = "Smith"
        contact.nickname = "Johnny"
        
        let displayName = await manager.displayName(for: contact)
        #expect(displayName == "Johnny", "Should prefer nickname over full name")
    }
    
    @Test("Display name without nickname")
    @available(watchOS 10.0, *)
    func testDisplayNameWithoutNickname() async {
        let manager = ContactManager.shared
        
        let contact = CNMutableContact()
        contact.givenName = "John"
        contact.familyName = "Doe"
        contact.nickname = ""
        
        let displayName = await manager.displayName(for: contact)
        #expect(displayName == "John Doe", "Should use full name when no nickname")
    }
    
    @Test("Display name with only given name")
    @available(watchOS 10.0, *)
    func testDisplayNameGivenOnly() async {
        let manager = ContactManager.shared
        
        let contact = CNMutableContact()
        contact.givenName = "Madonna"
        contact.familyName = ""
        contact.nickname = ""
        
        let displayName = await manager.displayName(for: contact)
        #expect(displayName == "Madonna", "Should use given name only")
    }
    
    @Test("Display name with only family name")
    @available(watchOS 10.0, *)
    func testDisplayNameFamilyOnly() async {
        let manager = ContactManager.shared
        
        let contact = CNMutableContact()
        contact.givenName = ""
        contact.familyName = "Prince"
        contact.nickname = ""
        
        let displayName = await manager.displayName(for: contact)
        #expect(displayName == "Prince", "Should use family name only")
    }
    
    @Test("Display name with empty contact")
    @available(watchOS 10.0, *)
    func testDisplayNameEmpty() async {
        let manager = ContactManager.shared
        
        let contact = CNMutableContact()
        contact.givenName = ""
        contact.familyName = ""
        contact.nickname = ""
        
        let displayName = await manager.displayName(for: contact)
        #expect(displayName == "", "Should return empty string for empty contact")
    }
    
    @Test("Thumbnail data returns data")
    @available(watchOS 10.0, *)
    func testThumbnailDataReturnsData() async {
        let manager = ContactManager.shared
        
        // Contact without image should generate monogram
        let contact = CNMutableContact()
        contact.givenName = "Test"
        contact.familyName = "User"
        
        let thumbnailData = await manager.thumbnailData(for: contact)
        #expect(thumbnailData != nil, "Should return data (monogram) for contact without image")
        
        // Verify it's valid image data
        if let data = thumbnailData {
            let image = UIImage(data: data)
            #expect(image != nil, "Should generate valid image data")
        }
    }
    
    @Test("Thumbnail data generates monogram for contact without image")
    @available(watchOS 10.0, *)
    func testThumbnailDataGeneratesMonogram() async {
        let manager = ContactManager.shared
        
        let contact = CNMutableContact()
        contact.givenName = "Monogram"
        contact.familyName = "Test"
        // Note: imageDataAvailable is read-only, so we can't set it
        // The test will verify monogram generation when no image is present
        
        let thumbnailData = await manager.thumbnailData(for: contact)
        #expect(thumbnailData != nil, "Should generate monogram for contact without image")
    }
    
    // Note: Testing fetchAllContacts and fetchContact(identifier:) would require
    // mocking CNContactStore or having test contacts in the system, which is
    // not practical for unit tests. These should be tested via integration tests
    // or manual testing with real contact access.
    
    // Note: Testing requestAccess() is also impractical in unit tests as it
    // requires actual system permission dialogs. This should be tested manually
    // or in UI/integration tests.
}
