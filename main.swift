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

extension Process {
    @discardableResult func launchBash(withCommand command: String) -> String? {
        launchPath = "/bin/bash"
        arguments = ["-c", command]
        
        let pipe = Pipe()
        standardOutput = pipe
        
        // Silent errors by assigning a dummy pipe to the error output
        standardError = Pipe()
        
        launch()
        waitUntilExit()
        
        let outputData = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: outputData, encoding: .utf8)?.nonEmpty
    }
    
    func gitConfigValue(forKey key: String) -> String? {
        return launchBash(withCommand: "git config --global --get \(key)")?.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

extension String {
    var nonEmpty: String? {
        guard characters.count > 0 else {
            return nil
        }
        
        return self
    }
    
    func withoutSuffix(_ suffix: String) -> String {
        guard hasSuffix(suffix) else {
            return self
        }
        
        let startIndex = index(endIndex, offsetBy: -suffix.characters.count)
        return replacingCharacters(in: startIndex..<endIndex, with: "")
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
    func element(after index: Int) -> Element? {
        guard index >= 0 && index < count else {
            return nil
        }
        
        return self[index + 1]
    }
}

// MARK: - Types

struct Arguments {
    var destination: String?
    var projectName: String?
    var authorName: String?
    var authorEmail: String?
    var githubURL: String?
    var organizationName: String?
    var repositoryURL: URL?
    var forceEnabled: Bool = false
    
    init(commandLineArguments arguments: [String]) {
        for (index, argument) in arguments.enumerated() {
            switch argument.lowercased() {
            case "--destination", "-d":
                destination = arguments.element(after: index)
            case "--project", "-p":
                projectName = arguments.element(after: index)
            case "--name", "-n":
                authorName = arguments.element(after: index)
            case "--email", "-e":
                authorEmail = arguments.element(after: index)
            case "--url", "-u":
                githubURL = arguments.element(after: index)
            case "--organization", "-o":
                organizationName = arguments.element(after: index)
            case "--repo", "-r":
                if let urlString = arguments.element(after: index) {
                    repositoryURL = URL(string: urlString)
                }
            case "--force", "-f":
                forceEnabled = true
            default:
                break
            }
        }
    }
}

class StringReplacer {
    private let projectName: String
    private let authorName: String
    private let authorEmail: String
    private let gitHubURL: String
    private let year: String
    private let today: String
    private let organizationName: String
    
    init(projectName: String, authorName: String, authorEmail: String?, gitHubURL: String?, organizationName: String?) {
        self.projectName = projectName
        self.authorName = authorName
        self.authorEmail = authorEmail ?? ""
        self.gitHubURL = gitHubURL ?? ""
        self.organizationName = organizationName ?? projectName
        

        let yearFormatter = DateFormatter()
        yearFormatter.dateFormat = "YYYY"
        self.year = yearFormatter.string(from: Date())

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        self.today = dateFormatter.string(from: Date())
    }
    
    private var dateString: String {
        return DateFormatter.localizedString(
            from: Date(),
            dateStyle: DateFormatter.Style.medium,
            timeStyle: DateFormatter.Style.none
        )
    }
    
    func process(string: String) -> String {
        return string.replacingOccurrences(of: "{PROJECT}", with: projectName)
                     .replacingOccurrences(of: "{AUTHOR}", with: authorName)
                     .replacingOccurrences(of: "{EMAIL}", with: authorEmail)
                     .replacingOccurrences(of: "{URL}", with: gitHubURL)
                     .replacingOccurrences(of: "{YEAR}", with: year)
                     .replacingOccurrences(of: "{TODAY}", with: today)
                     .replacingOccurrences(of: "{DATE}", with: dateString)
                     .replacingOccurrences(of: "{ORGANIZATION}", with: organizationName)
    }
    
    func process(filesInFolderWithPath folderPath: String) throws {
        let fileManager = FileManager.default
        let currentFileName = URL.init(fileURLWithPath: #file).lastPathComponent

        for itemName in try fileManager.contentsOfDirectory(atPath: folderPath) {
            if itemName.hasPrefix(".") || itemName == currentFileName {
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

func askForProjectName(destination: String) -> String {
    let projectFolderName = destination.withoutSuffix("/").components(separatedBy: "/").last!
    
    let projectName = askForOptionalInfo(
        question: "📛  What's the name of your project?",
        questionSuffix: "(Leave empty to use the name of the project folder: \(projectFolderName))"
    )
    
    return projectName ?? projectFolderName
}

func askForAuthorName() -> String {
    let gitName = Process().gitConfigValue(forKey: "user.name")
    let question = "👶  What's your name?"
    
    if let gitName = gitName {
        let authorName = askForOptionalInfo(question: question, questionSuffix: "(Leave empty to use your git config name: \(gitName))")
        return authorName ?? gitName
    }
    
    return askForRequiredInfo(question: question, errorMessage: "Your name cannot be empty")
}

func askForAuthorEmail() -> String? {
    let gitEmail = Process().gitConfigValue(forKey: "user.email")
    let question = "📫  What's your email address (for Podspec)?"
    
    if let gitEmail = gitEmail {
        let authorEmail = askForOptionalInfo(question: question, questionSuffix: "(Leave empty to use your git config email: \(gitEmail))")
        return authorEmail ?? gitEmail
    }
    
    return askForOptionalInfo(question: question)
}

func askForGitHubURL(destination: String) -> String? {
    let gitURL = Process().launchBash(withCommand: "cd \(destination) && git remote get-url origin")?
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .withoutSuffix(".git")
    
    let question = "🌍  Any GitHub URL that you'll be hosting this project at (for Podspec)?"
    
    if let gitURL = gitURL {
        let gitHubURL = askForOptionalInfo(question: question, questionSuffix: "(Leave empty to use the remote URL of your repo: \(gitURL))")
        return gitHubURL ?? gitURL
    }
    
    return askForOptionalInfo(question: question)
}

func performCommand(description: String, command: () throws -> Void) rethrows {
    print("👉  \(description)...")
    try command()
    print("✅  Done")
}

// MARK: - Program

print("Welcome to the SwiftPlate project generator 🐣")

let arguments = Arguments(commandLineArguments: CommandLine.arguments)
let destination = arguments.destination ?? askForDestination()
let projectName = arguments.projectName ?? askForProjectName(destination: destination)
let authorName = arguments.authorName ?? askForAuthorName()
let authorEmail = arguments.authorEmail ?? askForAuthorEmail()
let gitHubURL = arguments.githubURL ?? askForGitHubURL(destination: destination)
let organizationName = arguments.organizationName ?? askForOptionalInfo(question: "🏢  What's your organization name?")
let useCocoapods = askForBooleanInfo(question: "🛠  Use Cocoapods to develop and test your project?")
let useQuickAndNimble = askForBooleanInfo(question: "🔍  Use Quick and Nimble testing frameworks? (via Cocoapods)")
let installCocoapods = useCocoapods || useQuickAndNimble

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

if installCocoapods {
    if useQuickAndNimble {
        print("🔍  Using Quick and Nimble (via Cocoapods)")
    } else {
        print("🛠  Using Cocoapods")
    }    
}

print("---------------------------------------------------------------------")

if !arguments.forceEnabled {
    if !askForBooleanInfo(question: "Proceed? ✅") {
        exit(0)
    }
}

print("🚀  Starting to generate project \(projectName)...")

do {
    let fileManager = FileManager.default
    let temporaryDirectoryPath = destination + "/swiftplate_temp"
    let gitClonePath = "\(temporaryDirectoryPath)/SwiftPlate"
    let templatePath = "\(gitClonePath)/Template"
    let optionalItemsPath = templatePath + "/Optional"
    
    performCommand(description: "Removing any previous temporary folder") {
        try? fileManager.removeItem(atPath: temporaryDirectoryPath)
    }
    
    try performCommand(description: "Making temporary folder (\(temporaryDirectoryPath))") {
        try fileManager.createDirectory(atPath: temporaryDirectoryPath, withIntermediateDirectories: false, attributes: nil)
    }
    
    performCommand(description: "Making a local clone of the SwiftPlate repo") {
        let repositoryURL = arguments.repositoryURL ?? URL(string: "https://github.com/JohnSundell/SwiftPlate.git")!
        Process().launchBash(withCommand: "git clone \(repositoryURL.absoluteString) '\(gitClonePath)' -q")
    }
    
    try performCommand(description: "Copying template folder") {
        let ignorableItems: Set<String> = ["readme.md", "license"]
        var ignoredItems = try fileManager.contentsOfDirectory(atPath: destination).map {
            $0.lowercased()
        }.filter {
            ignorableItems.contains($0)
        }
        ignoredItems.append("optional")

        for itemName in try fileManager.contentsOfDirectory(atPath: templatePath) {
            let originPath = templatePath + "/" + itemName
            let destinationPath = destination + "/" + itemName

            let lowercasedItemName = itemName.lowercased()
            guard ignoredItems.contains(lowercasedItemName) == false else {
                continue
            }

            try fileManager.copyItem(atPath: originPath, toPath: destinationPath)
        }

        if useCocoapods && !useQuickAndNimble {
            let originPath = optionalItemsPath + "/" + "Podfile-blank"
            let destinationPath = destination + "/" + "Podfile"
            try fileManager.copyItem(atPath: originPath, toPath: destinationPath)
        }

        if useQuickAndNimble {
            let originPath = optionalItemsPath + "/" + "Podfile-quick+nimble"
            let destinationPath = destination + "/" + "Podfile"
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

    if installCocoapods {
        performCommand(description: "Setting up Cocoapods (running pod install)") {
            Process().launchBash(withCommand: "pod install")
        }
    }
    
    print("All done! 🎉  Good luck with your project! 🚀")
} catch {
    print("An error was encountered 🙁")
    print("Error: \(error)")
}
