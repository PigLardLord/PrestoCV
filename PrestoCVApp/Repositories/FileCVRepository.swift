//
//  FileCVRepository.swift
//  PrestoCVApp
//
//  Created by Giovanni Trovato on 22/03/2020.
//  Copyright © 2020 PigLardLord. All rights reserved.
//

import Foundation

class FileCVRepository: CVRepository {
    
    private var baseDirectory: URL
    
    init(searchPathDir: FileManager.SearchPathDirectory) {
    
        guard let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            fatalError("Could not create URL for specified directory!")
        }
        
        baseDirectory = dir
    }
    
    init(baseDirectory: URL) {
        self.baseDirectory = baseDirectory
    }
    
    
    
    private func getFilePath(for id: UUID) -> String {
        
        let dataPath = baseDirectory.appendingPathComponent("CVs")
        
        if !FileManager.default.fileExists(atPath: dataPath.path) {
            do {
                try FileManager.default.createDirectory(atPath: dataPath.path, withIntermediateDirectories: true, attributes: nil)
            } catch {
                print(error.localizedDescription);
            }
        }
        
        let fileURL = dataPath.appendingPathComponent(id.uuidString, isDirectory: false)
        
        return fileURL.path
    }
    
    private func save(cv: CV){
        let filePath = getFilePath(for: cv.id)
        
        let encoder = JSONEncoder()
        do {
            let data = try encoder.encode(cv)
            if FileManager.default.fileExists(atPath: filePath) {
                try FileManager.default.removeItem(atPath: filePath)
            }
            FileManager.default.createFile(atPath: filePath, contents: data, attributes: nil)
        } catch {
            fatalError(error.localizedDescription)
        }
    }
    
    private func delete(for id: UUID) {
        let filePath = getFilePath(for: id)
        if FileManager.default.fileExists(atPath: filePath) {
            do {
                try FileManager.default.removeItem(atPath: filePath)
            } catch {
                fatalError(error.localizedDescription)
            }
        }
    }
    
    private func load(by id: UUID) -> CV {
        let filePath = getFilePath(for: id)
        
        if !FileManager.default.fileExists(atPath: filePath) {
            fatalError("File at path \(filePath) does not exist!")
        }
        
        if let data = FileManager.default.contents(atPath: filePath) {
            let decoder = JSONDecoder()
            do {
                let model = try decoder.decode(CV.self, from: data)
                return model
            } catch {
                fatalError(error.localizedDescription)
            }
        } else {
            fatalError("No data at \(filePath)!")
        }
    }
    
    func getAll() -> [CV] {
        
        var result = Array<CV>()
        do {
            // Get the directory contents urls (including subfolders urls)
            let directoryContents = try FileManager.default.contentsOfDirectory(atPath: "")
            
            result = directoryContents.map { (element) -> CV in
                guard let id = UUID(uuidString: element) else {
                    fatalError("directory contains not valid CV")
                }
                return load(by: id)
            }
            
        } catch {
            print(error)
        }
        return result
    }
    
    func get(with id: UUID) -> CV {
        let cv = load(by: id)
        return cv
    }
    
    func add(curriculum: CV) {
        save(cv: curriculum)
    }
    
    func update(curriculum: CV) {
        save(cv: curriculum)
    }
    
}
