// Models/PersistenceManager.swift
//
//  PersistenceManager.swift
//  GraphEditor
//
//  Created by handcart on 8/1/25.
//

import Foundation
import GraphEditorShared

public class PersistenceManager: GraphStorage {
    
    private let nodesFileName = "graphNodes.json"
    private let edgesFileName = "graphEdges.json"
    
    private var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    public init() {}
    
    public func save(nodes: [Node], edges: [GraphEdge]) {
        let encoder = JSONEncoder()
        do {
            let nodeData = try encoder.encode(nodes)
            let nodeURL = documentsDirectory.appendingPathComponent(nodesFileName)
            try nodeData.write(to: nodeURL)
            
            let edgeData = try encoder.encode(edges)
            let edgeURL = documentsDirectory.appendingPathComponent(edgesFileName)
            try edgeData.write(to: edgeURL)
        } catch {
            print("Error saving graph: \(error.localizedDescription)")
            // Future: Add UIAlert or flag for UI handling
        }
    }
    
    public func load() -> (nodes: [Node], edges: [GraphEdge]) {
        let decoder = JSONDecoder()
        var loadedNodes: [Node] = []
        var loadedEdges: [GraphEdge] = []
        
        let nodeURL = documentsDirectory.appendingPathComponent(nodesFileName)
        if let nodeData = try? Data(contentsOf: nodeURL),
           let decodedNodes = try? decoder.decode([Node].self, from: nodeData) {
            loadedNodes = decodedNodes
        }
        
        let edgeURL = documentsDirectory.appendingPathComponent(edgesFileName)
        if let edgeData = try? Data(contentsOf: edgeURL),
           let decodedEdges = try? decoder.decode([GraphEdge].self, from: edgeData) {
            loadedEdges = decodedEdges
        }
        
        return (loadedNodes, loadedEdges)
    }
}
