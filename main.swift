#!/usr/bin/swift

/**
 *  SwiftPlate
 *
 *  Copyright (c) 2016 John Sundell. Licensed under the MIT license, as follows:
 *
 *  Permission is hereby granted, free of charge, to any person obtaining a copy
 *  of this software and associated documentation files (the "Software"), to deal
 *  in the Software without restriction, including without limitation the rights
 *  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 *  copies of the Software, and to permit persons to whom the Software is
 *  furnished to do so, subject to the following conditions:
 *
 *  The above copyright notice and this permission notice shall be included in all
 *  copies or substantial portions of the Software.
 *
 *  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 *  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 *  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 *  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 *  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 *  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 *  SOFTWARE.
 */

import Foundation

// MARK: - Extensions

extension Pipe {
    var output: String? {
        let outputData = fileHandleForReading.readDataToEndOfFile()
        return String(data: outputData, encoding: .utf8)
    }
}

extension String {
    var nonEmpty: String? {
        guard characters.count > 0 else {
            return nil
        }
        
        return self
    }
}

extension FileManager {
    func isFolder(atPath path: String) -> Bool {
        var objCBool: ObjCBool = false
        
        guard fileExists(atPath: path, isDirectory: &objCBool) else {
            return false
        }
        
        return objCBool.boolValue
    }
}

extension Array {
    func element(after index: UInt) -> Element? {
        
        //: handles not only negative indices, but also index == self.count
        //: might be over-engineered, we only need to check for second condition
        let arrRange = [Int](0..<self.count)
        if arrRange.contains(Int(index) + 1) {
            return self[Int(index) + 1]
        } else {
            return nil
        }
    }
}

// MARK: - Types

class StringReplacer {
    private let projectName: String
    private let authorName: String
    private let authorEmail: String
    private let gitHubURL: String
    private let year: String
    private let organizationName: String
    
    init(projectName: String, authorName: String, authorEmail: String?, gitHubURL: String?, organizationName: String?) {
        self.projectName = projectName
        self.authorName = authorName
        self.authorEmail = authorEmail ?? ""
        self.gitHubURL = gitHubURL ?? ""
        self.organizationName = organizationName ?? projectName
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "YYYY"
        self.year = dateFormatter.string(from: Date())
    }
    
    func process(string: String) -> String {
        return string.replacingOccurrences(of: "{PROJECT}", with: projectName)
            .replacingOccurrences(of: "{AUTHOR}", with: authorName)
            .replacingOccurrences(of: "{EMAIL}", with: authorEmail)
            .replacingOccurrences(of: "{URL}", with: gitHubURL)
            .replacingOccurrences(of: "{YEAR}", with: year)
            .replacingOccurrences(of: "{ORGANIZATION}", with: organizationName)
    }
    
    func process(filesInFolderWithPath folderPath: String) throws {
        let fileManager = FileManager.default
        
        for itemName in try fileManager.contentsOfDirectory(atPath: folderPath) {
            if itemName.hasPrefix(".") {
                continue
            }
            
            let itemPath = folderPath + "/" + itemName
            let newItemPath = folderPath + "/" + process(string: itemName)
            
            if fileManager.isFolder(atPath: itemPath) {
                try process(filesInFolderWithPath: itemPath)
                try fileManager.moveItem(atPath: itemPath, toPath: newItemPath)
                continue
            }
            
            let fileContents = try String(contentsOfFile: itemPath)
            try process(string: fileContents).write(toFile: newItemPath, atomically: false, encoding: .utf8)
            
            if newItemPath != itemPath {
                try fileManager.removeItem(atPath: itemPath)
            }
        }
    }
}

// MARK: - Functions

func printError(_ message: String) {
    print("👮  \(message)")
}

func askForRequiredInfo(question: String, errorMessage errorMessageClosure: @autoclosure () -> String) -> String {
    print(question)
    
    guard let info = readLine()?.nonEmpty else {
        printError("\(errorMessageClosure()). Try again.")
        return askForRequiredInfo(question: question, errorMessage: errorMessageClosure)
    }
    
    return info
}

func askForOptionalInfo(question: String, questionSuffix: String = "You may leave this empty.") -> String? {
    print("\(question) \(questionSuffix)")
    return readLine()?.nonEmpty
}

func askForBooleanInfo(question: String) -> Bool {
    let errorMessage = "Please enter Y/y (yes) or N/n (no)"
    let answerString = askForRequiredInfo(question: "\(question) (Y/N)", errorMessage: errorMessage)
    
    switch answerString.lowercased() {
    case "y":
        return true
    case "n":
        return false
    default:
        printError("\(errorMessage). Try again.")
        return askForBooleanInfo(question: question)
    }
}

func askForDestination() -> String {
    let destination = askForOptionalInfo(
        question: "📦  Where would you like to generate a project?",
        questionSuffix: "(Leave empty to use current directory)"
    )
    
    let fileManager = FileManager.default
    
    if let destination = destination {
        guard fileManager.fileExists(atPath: destination) else {
            printError("That path doesn't exist. Try again.")
            return askForDestination()
        }
        
        return destination
    }
    
    return fileManager.currentDirectoryPath
}

func performGitClone(path: String) throws {
    let process = Process()
    process.launchPath = "/bin/bash"
    process.arguments = ["-c", "git clone https://github.com/JohnSundell/SwiftPlate.git '\(path)' -q"]
    process.launch()
    process.waitUntilExit()
}

func performCommand(description: String, command: () throws -> Void) rethrows {
    print("👉  \(description)...")
    try command()
    print("✅  Done")
}

//: This *could* just be a dictionary, but a struct felt cleaner. Also, we get type safety(and autocompletion) for free!!
struct Arguments {
    var destination: String?
    var projectName: String?
    var authorName: String?
    var authorEmail: String?
    var githubURL: String?
    var organizationName: String?
}

func processArguments() -> Arguments {
    var templateInfo = Arguments()
    
    let args = CommandLine.arguments
    
    for (index,argument) in args.enumerated() {
        //: Why lowercased() ? In case the user accidentally mistypes something.
        switch argument.lowercased() {
        case "--destination" :
            templateInfo.destination = args.element(after: UInt(index))
        case "--projectName" :
            templateInfo.projectName = args.element(after: UInt(index))
        case "--authorName" :
            templateInfo.authorName = args.element(after: UInt(index))
        case "--authorEmail" :
            templateInfo.authorEmail = args.element(after: UInt(index))
        case "--githubURL" :
            templateInfo.githubURL = args.element(after: UInt(index))
        case "--organizationName" :
            templateInfo.organizationName = args.element(after: UInt(index))
        default:
            //: We should probably put something to skip an argument value, but for now let's just continue on the loop ¯\_(ツ)_/¯
            break
        }
    }
    return templateInfo
}

// MARK: - Program

print("Welcome to the SwiftPlate project generator 🐣")

let templateFromArguments = processArguments()

let destination = templateFromArguments.destination ?? askForDestination()
let projectName = templateFromArguments.projectName ?? askForRequiredInfo(question: "📛  What's the name of your project?", errorMessage: "Project name cannot be empty")
let authorName = templateFromArguments.authorName ?? askForRequiredInfo(question: "👶  What's your name?", errorMessage: "Your name cannot be empty")
let authorEmail = templateFromArguments.authorEmail ?? askForOptionalInfo(question: "📫  What's your email address (for Podspec)?")
let gitHubURL = templateFromArguments.githubURL ?? askForOptionalInfo(question: "🌍  Any GitHub URL that you'll be hosting this project at (for Podspec)?")
let organizationName = templateFromArguments.organizationName ?? askForOptionalInfo(question: "🏢  What's your organization name?")

print("---------------------------------------------------------------------")
print("SwiftPlate will now generate a project with the following parameters:")
print("📦  Destination: \(destination)")
print("📛  Name: \(projectName)")
print("👶  Author: \(authorName)")

if let authorEmail = authorEmail {
    print("📫  Author email: \(authorEmail)")
}

if let gitHubURL = gitHubURL {
    print("🌍  GitHub URL: \(gitHubURL)")
}

if let organizationName = organizationName {
    print("🏢  Organization Name: \(organizationName)")
}

print("---------------------------------------------------------------------")

if !askForBooleanInfo(question: "Proceed? ✅") {
    exit(0)
}

print("🚀  Starting to generate project \(projectName)...")

do {
    let fileManager = FileManager.default
    let temporaryDirectoryPath = destination + "/swiftplate_temp"
    let gitClonePath = "\(temporaryDirectoryPath)/SwiftPlate"
    let templatePath = "\(gitClonePath)/Template"
    
    performCommand(description: "Removing any previous temporary folder") {
        try? fileManager.removeItem(atPath: temporaryDirectoryPath)
    }
    
    try performCommand(description: "Making temporary folder (\(temporaryDirectoryPath))") {
        try fileManager.createDirectory(atPath: temporaryDirectoryPath, withIntermediateDirectories: false, attributes: nil)
    }
    
    try performCommand(description: "Making a local clone of the SwiftPlate repo") {
        try performGitClone(path: gitClonePath)
    }
    
    try performCommand(description: "Copying template folder") {
        for itemName in try fileManager.contentsOfDirectory(atPath: templatePath) {
            let originPath = templatePath + "/" + itemName
            let destinationPath = destination + "/" + itemName
            try fileManager.copyItem(atPath: originPath, toPath: destinationPath)
        }
    }
    
    try performCommand(description: "Removing temporary folder") {
        try fileManager.removeItem(atPath: temporaryDirectoryPath)
    }
    
    try performCommand(description: "Filling in template") {
        let replacer = StringReplacer(
            projectName: projectName,
            authorName: authorName,
            authorEmail: authorEmail,
            gitHubURL: gitHubURL,
            organizationName: organizationName
        )
        
        try replacer.process(filesInFolderWithPath: destination)
    }
    
    print("All done! 🎉  Good luck with your project! 🚀")
} catch {
    print("An error was encountered 🙁")
    print("Error: \(error)")
}
