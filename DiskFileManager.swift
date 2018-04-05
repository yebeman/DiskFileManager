//
//  FileManager.swift
//
//  Created by Yebeltal Asseged on 7/5/17.
// keeps track of all files and manages them

// terminology
// eg: [[A,B,C], [D]] >> 0,1- index    A,B,C - subindex

/// Create a Container first, then create Contents
/// directroy will be removed after usage


import UIKit


internal class DiskFileManager : NSObject{
    
    private(set) internal var container : URL!    // would be parrent folder
    private(set) internal var subContainers : [String]?  // would be folder name
    
    private(set) internal var contents : [[URL]]?   // would be files
    private(set) internal var isContentInUse : [[Bool]]?
    
    
    //////////////////////////////
    // Mark - main
    
    convenience init(directory container : String){
        self.init()
        
        DispatchQueue.main.async {
            self.contents = [[]]
            self.isContentInUse = [[]]
            self.subContainers = []
            self.createContainer(named: container)
        }
    }
    
    deinit {
        let _ = clean(container.absoluteString)
    }
    
    
    /////////////////////////////////
    // Mark - Remove
    
    // remove item at a path
    private  func clean(_ path: String)  -> Bool{
        let filemanager = FileManager.default
        if filemanager.fileExists(atPath: path) {
            do {
                try filemanager.removeItem(atPath: path)
                return true
            }catch { return false}
        }else{ return false}
    }
    
    
    //////////////////////////////////////////////////////////////
    // Mark - Main Container Managment
    
    // create container -- folder/dir name
    private func createContainer(named containerName: String) {
        if let path = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).last {
            
            let unifiedPath : String = path + "/\(containerName)"
            
            // clean
            let _ = self.clean(unifiedPath)
    
            container = URL(fileURLWithPath: unifiedPath, isDirectory: true)
        }
    }
    
    
    ///////////////////////////////////////////////////////////
    // Mark - Sub Container Managment
    
    /// remove all files under subContainer -- folder/dir
    private func cleanContainer(named containerName: String) {
        let fileManager = FileManager.default
        do {
            let filePaths = try fileManager.contentsOfDirectory(atPath: containerName)
            for filePath in filePaths {
                try fileManager.removeItem(atPath: containerName + filePath)
            }
        } catch {
            //("cleanError")
            return
        }
    }
    
    // ...containerName/subContainer_1/file.*  ...containerName/subContainer_2/file.*
    /// creates and appends the url for later use
    internal  func createSubContainer(named containerName : String){
        
        guard let _subContainers = self.subContainers, let subContainerIndex = _subContainers.index(of: containerName) else{
            
            let unifiedPath : String = self.container.absoluteString + "/\(containerName)"
            let _ = self.clean(unifiedPath) // cleaning on disk
            
            let _ = URL(fileURLWithPath: unifiedPath, isDirectory: true)
            
            self.subContainers?.append(containerName) // creating empty folders
            self.contents?.append([])     // setting empty headers
            self.isContentInUse?.append([])
            return
        }
        
        // cleaning on disk
        let unifiedPath : String = self.container.absoluteString + "/\(containerName)"
        let _ = self.cleanContainer(named: unifiedPath)
        
        self.subContainers?.remove(at: subContainerIndex)
        self.contents?[subContainerIndex].removeAll()
        self.isContentInUse?[subContainerIndex].removeAll()
    }
    
    /// returns sub name
    internal  func getSubContainer(at index : Int) -> String?{
        
        guard let subContainer = self.subContainers?[index] else{
            return nil
        }
        
        return subContainer
    }
    

    
    
    //////////////////////////////////////////////////////
    // Mark - Content Managment
    
    ///  creates and appends to contents ->  | |*,*,*|, |*|,.. |
    /// async
    internal func createContent(atIndex index : Int, fileName name: String, fileType type: String, content: @escaping ((_ address : URL?, _ index : Int) -> Void)) {
        
            guard let path = self.subContainers?[index], let url =  URL(string: path) else {
                return
            }
            
            let file : URL = url.appendingPathComponent(name).appendingPathExtension(type)
            let _ = URL(fileURLWithPath: file.absoluteString, isDirectory: false)
            
            
            let _count : Int = self.contents?.count ?? -1
            
            if _count > index && _count > 0{
                self.contents?[index].append(file)
                self.isContentInUse?[index].append(false)
                content(file, index)
            }else{
                self.contents?.append([file])
                self.isContentInUse?.append([false])
                content(file, 0)
            
        }
    }
    
    /// creates content in container
    private func createContent(inSubContainer container : String, fileName name: String, fileType type: String, content: @escaping ((_ url : URL?, _ index : Int) -> Void)){
        
        guard let index = subContainers?.index(of: container) else{
            return
        }
        
        createContent(atIndex: index, fileName: name, fileType: type){ url, index in
            content(url, index)
        }
    }
    
    // returns contents in subdirectory
    internal  func getContents(inSubDirectory directory: String) -> [URL]?{
        guard let index = subContainers?.index(of: directory) else{
            return nil
        }
        
        return getContents(at: index)
    }
    
    // returns contents in subdirectory
    internal  func getContents(at index : Int) -> [URL]?{
        
        guard let contents = contents?[index] else{
            return nil
        }
        
        return contents
    }
    
    // returns available file in directory if any
    internal func getAvailableContent(inSubContainer container: String, withType type : String , content: @escaping ((_ url : URL?) -> Void)) {
        
        guard let index = subContainers?.index(of: container),
            let contents = getContents(at: index),
            let contentStatus = isContentInUse?[index],
            let subIndex = contentStatus.index(of: false) else{
               
                // if none - create
                let tempFileName = UUID().uuidString
                createContent(inSubContainer: container, fileName: tempFileName, fileType: type){ url, index in
                    
                    // update to true
                    // easier
                    self.isContentInUse?[index].removeLast()
                    self.isContentInUse?[index].append(true)
                    
                    content(url)
                }
                return
        }
        
        isContentInUse?[index][subIndex] = true
        content(contents[subIndex])
    }
    
    
    /// resets url file
    /// async
    internal func reset(content url : URL, reseted : @escaping (_ success : Bool)->Void) {
        DispatchQueue.main.async { [url=url] in
            
            // rather than cycling and increasing BigO
            // better to use  logic
            
            var content : String = url.absoluteString
            let container = self.container.absoluteString
            
            if content.hasPrefix(container), let subContainers = self.subContainers, let contents = self.contents, self.clean(content){
                
                // recreate file
                let _ = URL(fileURLWithPath: content, isDirectory: false)
                
                // memory cleaning
                content.removeSubrange(content.range(of: container)!)
                
                let subContainer : String = content.split(separator: "/").map(String.init).first!
                let subContainerIndex : Int = subContainers.index(of: subContainer)!
                let contentSubIndex : Int = contents[subContainerIndex].index(of: url)!
                
                self.isContentInUse?[subContainerIndex][contentSubIndex] = false
                
                reseted(true)
            }else{
                
                // unable to reset
                reseted(false)
            }
        }
    }
}

