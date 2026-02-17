//
//  ContactManager.swift
//  GraphEditor
//
//  Helper for managing contact access and fetching
//

import Foundation
import Contacts
import UIKit

@available(watchOS 10.0, *)
actor ContactManager {
    static let shared = ContactManager()
    
    private let store = CNContactStore()
    
    // Keys to fetch from contacts
    private let keysToFetch: [CNKeyDescriptor] = [
        CNContactGivenNameKey as CNKeyDescriptor,
        CNContactFamilyNameKey as CNKeyDescriptor,
        CNContactNicknameKey as CNKeyDescriptor,
        CNContactThumbnailImageDataKey as CNKeyDescriptor,
        CNContactImageDataKey as CNKeyDescriptor,  // Full-size image
        CNContactImageDataAvailableKey as CNKeyDescriptor,
        CNContactBirthdayKey as CNKeyDescriptor,
        CNContactIdentifierKey as CNKeyDescriptor
    ]
    
    // Request contact access
    func requestAccess() async throws -> Bool {
        return try await store.requestAccess(for: .contacts)
    }
    
    // Fetch all contacts
    func fetchAllContacts() async throws -> [CNContact] {
        let request = CNContactFetchRequest(keysToFetch: keysToFetch)
        var contacts: [CNContact] = []
        
        try store.enumerateContacts(with: request) { contact, _ in
            contacts.append(contact)
        }
        
        return contacts.sorted { contact1, contact2 in
            let name1 = "\(contact1.givenName) \(contact1.familyName)"
            let name2 = "\(contact2.givenName) \(contact2.familyName)"
            return name1 < name2
        }
    }
    
    // Fetch a specific contact by identifier
    func fetchContact(identifier: String) async throws -> CNContact? {
        let predicate = CNContact.predicateForContacts(withIdentifiers: [identifier])
        let contacts = try store.unifiedContacts(matching: predicate, keysToFetch: keysToFetch)
        return contacts.first
    }
    
    // Extract display name from contact
    func displayName(for contact: CNContact) -> String {
        if !contact.nickname.isEmpty {
            return contact.nickname
        }
        
        let components = [contact.givenName, contact.familyName].filter { !$0.isEmpty }
        return components.joined(separator: " ")
    }
    
    // Extract thumbnail or full image data, or generate a monogram
    func thumbnailData(for contact: CNContact) -> Data? {
        // Try thumbnail first (smaller, better for performance)
        if let thumbnailData = contact.thumbnailImageData {
            print("📷 Contact \(contact.givenName) \(contact.familyName): Using thumbnail (\(thumbnailData.count) bytes)")
            return thumbnailData
        }
        
        // Fall back to full-size image
        if contact.imageDataAvailable, let imageData = contact.imageData {
            print("📷 Contact \(contact.givenName) \(contact.familyName): Using full image (\(imageData.count) bytes), creating thumbnail...")
            
            // Resize to thumbnail size for better performance
            if let image = UIImage(data: imageData),
               let resizedData = resizeImage(image, targetSize: CGSize(width: 100, height: 100)) {
                print("   - Resized to thumbnail: \(resizedData.count) bytes")
                return resizedData
            }
            
            return imageData
        }
        
        // Generate a monogram if no photo is available
        print("📷 Contact \(contact.givenName) \(contact.familyName): No image available, generating monogram")
        let displayName = displayName(for: contact)
        return MonogramGenerator.generateMonogram(from: displayName)
    }

    
    // Helper to resize images (watchOS compatible)
    private func resizeImage(_ image: UIImage, targetSize: CGSize) -> Data? {
        // For watchOS, just compress the original image
        // The GPU will handle scaling during rendering
        return image.jpegData(compressionQuality: 0.7)
    }
}
