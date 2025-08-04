// Models/PersistenceManager.swift
//
//  PersistenceManager.swift
//  GraphEditor
//
//  Created by handcart on 8/1/25.
//
import os.log
private let logger = Logger(subsystem: "io.handcart.GraphEditor", category: "storage")

import Foundation
import GraphEditorShared

enum GraphStorageError: Error {
    case encodingFailed(Error)
    case writingFailed(Error)
    case loadingFailed(Error)
    case decodingFailed(Error)
}

public class PersistenceManager: GraphStorage {
    private let nodesFileName = "graphNodes.json"
    private let edgesFileName = "graphEdges.json"
    
    private let baseURL: URL
    
    public init() {
        self.baseURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    public init(baseURL: URL) {
        self.baseURL = baseURL
    }
    
    public func save(nodes: [Node], edges: [GraphEdge]) throws {
        let encoder = JSONEncoder()
        do {
            let nodeData = try encoder.encode(nodes)
            let nodeURL = baseURL.appendingPathComponent(nodesFileName)
            try nodeData.write(to: nodeURL)
            
            let edgeData = try encoder.encode(edges)
            let edgeURL = baseURL.appendingPathComponent(edgesFileName)
            try edgeData.write(to: edgeURL)
        } catch let encodingError as EncodingError {
            throw GraphStorageError.encodingFailed(encodingError)
        } catch let writingError as NSError {
            throw GraphStorageError.writingFailed(writingError)
        } catch {
            throw GraphStorageError.encodingFailed(error)
        }
    }
    
    public func load() -> (nodes: [Node], edges: [GraphEdge]) {
        let decoder = JSONDecoder()
        var loadedNodes: [Node] = []
        var loadedEdges: [GraphEdge] = []
        
        let nodeURL = baseURL.appendingPathComponent(nodesFileName)
        if let nodeData = try? Data(contentsOf: nodeURL) {
            do {
                loadedNodes = try decoder.decode([Node].self, from: nodeData)
            } catch {
                // Log and use defaults
                logger.error("Failed to decode nodes: \(error.localizedDescription)")
            }
        }
        
        let edgeURL = baseURL.appendingPathComponent(edgesFileName)
        if let edgeData = try? Data(contentsOf: edgeURL) {
            do {
                loadedEdges = try decoder.decode([GraphEdge].self, from: edgeData)
            } catch {
                logger.error("Failed to decode edges: \(error.localizedDescription)")
            }
        }
        
        return (loadedNodes, loadedEdges)
    }
}
