//
//  PersistenceManager.swift
//  GraphEditor
//
//  Created by handcart on 8/1/25.
//


// Models/PersistenceManager.swift
import Foundation

class PersistenceManager {
    private let nodesKey = "graphNodes"
    private let edgesKey = "graphEdges"
    
    func save(nodes: [Node], edges: [Edge]) {
        let encoder = JSONEncoder()
        if let nodeData = try? encoder.encode(nodes) {
            UserDefaults.standard.set(nodeData, forKey: nodesKey)
        }
        if let edgeData = try? encoder.encode(edges) {
            UserDefaults.standard.set(edgeData, forKey: edgesKey)
        }
    }
    
    func load() -> (nodes: [Node], edges: [Edge]) {
        let decoder = JSONDecoder()
        var loadedNodes: [Node] = []
        var loadedEdges: [Edge] = []
        if let nodeData = UserDefaults.standard.data(forKey: nodesKey),
           let decodedNodes = try? decoder.decode([Node].self, from: nodeData) {
            loadedNodes = decodedNodes
        }
        if let edgeData = UserDefaults.standard.data(forKey: edgesKey),
           let decodedEdges = try? decoder.decode([Edge].self, from: edgeData) {
            loadedEdges = decodedEdges
        }
        return (loadedNodes, loadedEdges)
    }
}