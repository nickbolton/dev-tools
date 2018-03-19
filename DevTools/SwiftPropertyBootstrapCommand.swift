//
//  SwiftPropertyBootstrapCommand.swift
//  DevTools
//
//  Created by Nick Bolton on 3/18/18.
//  Copyright © 2018 Pixelbleed LLC. All rights reserved.
//

import Foundation
import XcodeKit

class SwiftPropertyBootstrapCommand: NSObject, XCSourceEditorCommand {
    
    private let startMark = "    // MARK: Begin View Hierarchy Construction"
    private let endMark = "    // MARK: End View Hierarchy Construction"
    private let initializePlaceholder = "%INITIALIZE%"
    private let assemblePlaceholder = "%ASSEMBLE%"
    private let constrainPlaceholder = "%CONSTRAIN%"
    private let initializeViewDeclaration = "override func initializeViews() {"
    private let assembleViewDeclaration = "override func assembleViews() {"
    private let constrainViewDeclaration = "override func constrainViews() {"

    var originalSelections = [XCSourceTextRange]()
    
    func perform(with invocation: XCSourceEditorCommandInvocation, completionHandler: @escaping (Error?) -> Void ) -> Void {
        originalSelections = invocation.buffer.selections as! [XCSourceTextRange]
        let variables = findAffectedVariables(invocation.buffer)
        var targetVariables = [String]()
        for v in variables {
            if !isVariableMarkExists(v, buffer: invocation.buffer) {
                targetVariables.append(v)
            }
        }

        if invocation.buffer.completeBuffer.range(of: startMark) == nil {
            createViewHierarchyConstructionSection(invocation.buffer)
        }
        
        addPlaceholders(invocation.buffer)
        
        for v in targetVariables {
            addInitialization(v, buffer: invocation.buffer)
            addAssembly(v, buffer: invocation.buffer)
            addConstraints(v, buffer: invocation.buffer)
            createVariableSection(v, buffer: invocation.buffer)
        }

        removePlaceholderLines(invocation.buffer)
        
        completionHandler(nil)
    }
    
    private func addInitialization(_ name: String, buffer: XCSourceTextBuffer) {
        if let line = findFirstStringInLines(initializePlaceholder, buffer: buffer, in: NSMakeRange(0, buffer.completeBuffer.count)) {
            let string = "        initialize\(properName(name))()\n"
            prependLine(line, in: buffer, with: string)
        }
    }
    
    private func addAssembly(_ name: String, buffer: XCSourceTextBuffer) {
        if let line = findFirstStringInLines(assemblePlaceholder, buffer: buffer, in: NSMakeRange(0, buffer.completeBuffer.count)) {
            let string = "        addSubview(\(name))\n"
            prependLine(line, in: buffer, with: string)
        }
    }
    
    private func addConstraints(_ name: String, buffer: XCSourceTextBuffer) {
        if let line = findFirstStringInLines(constrainPlaceholder, buffer: buffer, in: NSMakeRange(0, buffer.completeBuffer.count)) {
            let string = "        constrain\(properName(name))()\n"
            prependLine(line, in: buffer, with: string)
        }
    }
    
    private func variableMark(_ name: String) -> String {
        // MARK: Centering Container
        var result = "    // MARK: "
        var idx = 0
        for c in name {
            if idx == 0 {
                result += String(c).uppercased()
            } else if String(c).range(of: "[A-Z]", options: .regularExpression) != nil {
                result += " "
                result += String(c)
            } else {
                result += String(c)
            }
            idx += 1
        }
        return result
    }
    
    private func properName(_ name: String) -> String {
        guard name.count > 1 else { return name.uppercased() }
        var result = ""
        result += ((name as NSString).substring(to: 1).uppercased() + (name as NSString).substring(from: 1)) as String
        return result
    }
    
    private func prependLine(_ targetLine: Int, in buffer: XCSourceTextBuffer, with string: String) {
        var completeBuffer = ""
        var lineNumber = 0
        for line in buffer.lines as! [String] {
            if lineNumber == targetLine {
                completeBuffer += string
            }
            completeBuffer += line
            lineNumber += 1
        }
        buffer.completeBuffer = completeBuffer
    }
    
    private func replaceLine(_ targetLine: Int, in buffer: XCSourceTextBuffer, with string: String) {
        var completeBuffer = ""
        var lineNumber = 0
        for line in buffer.lines as! [String] {
            if lineNumber == targetLine {
                completeBuffer += string
            } else {
                completeBuffer += line
            }
            lineNumber += 1
        }
        buffer.completeBuffer = completeBuffer
    }
    
    private func addPlaceholders(_ buffer: XCSourceTextBuffer) {
        addInitializePlaceholder(buffer)
        addAssemblePlaceholder(buffer)
        addConstrainPlaceholder(buffer)
    }
    
    private func addInitializePlaceholder(_ buffer: XCSourceTextBuffer) {
        guard let lastSelection = originalSelections.last else { return }
        guard let endLine = findClassClosingBraceLine(buffer) else { return }
        let range = NSMakeRange(lastSelection.end.line, endLine - lastSelection.end.line)
        if let startLine = findFirstStringInLines(initializeViewDeclaration, buffer: buffer, in: range) {
            if let closingBraceLine = findFunctionClosingBraceLine(buffer, startingAt: startLine) {
                prependLine(closingBraceLine, in: buffer, with: "        "+initializePlaceholder+"\n")
            }
        }
    }
    
    private func addAssemblePlaceholder(_ buffer: XCSourceTextBuffer) {
        guard let lastSelection = originalSelections.last else { return }
        guard let endLine = findClassClosingBraceLine(buffer) else { return }
        let range = NSMakeRange(lastSelection.end.line, endLine - lastSelection.end.line)
        if let startLine = findFirstStringInLines(assembleViewDeclaration, buffer: buffer, in: range) {
            if let closingBraceLine = findFunctionClosingBraceLine(buffer, startingAt: startLine) {
                prependLine(closingBraceLine, in: buffer, with: "        "+assemblePlaceholder+"\n")
            }
        }
    }
    
    private func addConstrainPlaceholder(_ buffer: XCSourceTextBuffer) {
        guard let lastSelection = originalSelections.last else { return }
        guard let endLine = findClassClosingBraceLine(buffer) else { return }
        let range = NSMakeRange(lastSelection.end.line, endLine - lastSelection.end.line)
        if let startLine = findFirstStringInLines(constrainViewDeclaration, buffer: buffer, in: range) {
            if let closingBraceLine = findFunctionClosingBraceLine(buffer, startingAt: startLine) {
                prependLine(closingBraceLine, in: buffer, with: "        "+constrainPlaceholder+"\n")
            }
        }
    }
    
    private func removePlaceholderLines(_ buffer: XCSourceTextBuffer) {
        removeInitializePlaceholder(buffer)
        removeAssemblePlaceholder(buffer)
        removeConstrainPlaceholder(buffer)
    }
    
    private func removeInitializePlaceholder(_ buffer: XCSourceTextBuffer) {
        if let line = findFirstStringInLines(initializePlaceholder, buffer: buffer, in: NSMakeRange(0, buffer.completeBuffer.count)) {
            replaceLine(line, in: buffer, with: "")
        }
    }
    
    private func removeAssemblePlaceholder(_ buffer: XCSourceTextBuffer) {
        if let line = findFirstStringInLines(assemblePlaceholder, buffer: buffer, in: NSMakeRange(0, buffer.completeBuffer.count)) {
            replaceLine(line, in: buffer, with: "")
        }
    }
    
    private func removeConstrainPlaceholder(_ buffer: XCSourceTextBuffer) {
        if let line = findFirstStringInLines(constrainPlaceholder, buffer: buffer, in: NSMakeRange(0, buffer.completeBuffer.count)) {
            replaceLine(line, in: buffer, with: "")
        }
    }
    
    private func findClassClosingBraceLine(_ buffer: XCSourceTextBuffer) -> Int? {
        if let lastSelection = originalSelections.last {
            let range = NSMakeRange(lastSelection.end.line, buffer.lines.count - lastSelection.end.line)
            return findFirstExpressionInLines("^\\}", buffer: buffer, in: range)
        }
        return nil
    }
    
    private func findEndMarkLine(_ buffer: XCSourceTextBuffer) -> Int? {
        let range = NSMakeRange(0, buffer.lines.count)
        return findFirstStringInLines(endMark, buffer: buffer, in: range)
    }
    
    private func findFunctionClosingBraceLine(_ buffer: XCSourceTextBuffer, startingAt start: Int) -> Int? {
        guard let endLine = findClassClosingBraceLine(buffer) else { return nil }
        let range = NSMakeRange(start, endLine - start)
        return findFirstExpressionInLines("^    \\}", buffer: buffer, in: range)
    }

    private func createVariableSection(_ name: String, buffer: XCSourceTextBuffer) {
        if let targetLine = findEndMarkLine(buffer) {
            let variableMark = self.variableMark(name)
            let initializeFunction = "    private func initialize\(properName(name))() {\n\n    }"
            let constrainFunction = "    private func constrain\(properName(name))() {\n\n    }"
            let insertion = "\(variableMark)\n\n\(initializeFunction)\n\n\(constrainFunction)\n\n"
            var isPreviousNewline = false
            var completeBuffer = ""
            var lineNumber = 0
            for line in buffer.lines as! [String] {
                if lineNumber == targetLine {
                    if !isPreviousNewline {
                        completeBuffer += "\n"
                    }
                    completeBuffer += insertion
                }
                completeBuffer += line
                isPreviousNewline = line.range(of: "^[ \t]*\n[ \t]*$", options: .regularExpression) != nil
                lineNumber += 1
            }
            buffer.completeBuffer = completeBuffer
        }
    }
    
    private func createViewHierarchyConstructionSection(_ buffer: XCSourceTextBuffer) {
        if let targetLine = findClassClosingBraceLine(buffer) {
            let insertion = "\(startMark)\n\n    override func initializeViews() {\n        super.initializeViews()\n    }\n\n    override func assembleViews() {\n        super.assembleViews()\n    }\n\n    override func constrainViews() {\n        super.constrainViews()\n    }\n\n\(endMark)\n"
            var isPreviousNewline = false
            var completeBuffer = ""
            var lineNumber = 0
            for line in buffer.lines as! [String] {
                if lineNumber == targetLine {
                    if !isPreviousNewline {
                        completeBuffer += "\n"
                    }
                    completeBuffer += insertion
                }
                completeBuffer += line
                isPreviousNewline = line.range(of: "^[ \t]*\n[ \t]*$", options: .regularExpression) != nil
                lineNumber += 1
            }
            buffer.completeBuffer = completeBuffer
        }
    }
    
    private func isVariableMarkExists(_ name: String, buffer: XCSourceTextBuffer) -> Bool {
        guard let targetLine = findClassClosingBraceLine(buffer) else { return false }
        guard let lastSelection = originalSelections.last else { return false }
        
        let range = NSMakeRange(lastSelection.end.line, targetLine - lastSelection.end.line)
        let variableMark = self.variableMark(name)
        return findFirstStringInLines(variableMark, buffer: buffer, in: range) != nil
    }
    
    private func findFirstExpressionInLines(_ exp: String, buffer: XCSourceTextBuffer, in range: NSRange) -> Int? {
        var bufferCount = 0
        var lineNumber = 0
        for line in buffer.lines as! [String] {
            if lineNumber >= range.location && lineNumber < range.location + range.length {
                let range = (line as NSString).range(of: exp, options: .regularExpression, range: NSMakeRange(0, line.count))
                if range.location != NSNotFound {
                    return lineNumber
                }
            }
            bufferCount += line.count
            lineNumber += 1
        }
        return nil
    }

    private func findFirstStringInLines(_ string: String, buffer: XCSourceTextBuffer, in range: NSRange) -> Int? {
        var bufferCount = 0
        var lineNumber = 0
        for line in buffer.lines as! [String] {
            if lineNumber >= range.location && lineNumber < range.location + range.length {
                let range = (line as NSString).range(of: string)
                if range.location != NSNotFound {
                    return lineNumber
                }
            }
            bufferCount += line.count
            lineNumber += 1
        }
        return nil
    }

    private func findFirstExpressionInBuffer(_ exp: String, buffer: XCSourceTextBuffer, in range: NSRange) -> NSRange? {
        var bufferCount = 0
        var lineNumber = 0
        for line in buffer.lines as! [String] {
            if lineNumber >= range.location && lineNumber < range.location + range.length {
                let range = (line as NSString).range(of: exp, options: .regularExpression, range: NSMakeRange(0, line.count))
                if range.location != NSNotFound {
                    return NSMakeRange(bufferCount + range.location, range.length)
                }
            }
            bufferCount += line.count
            lineNumber += 1
        }
        return nil
    }

    private func findAffectedVariables(_ buffer: XCSourceTextBuffer) -> [String] {
        var result = [String]()
        var lineCount = 0
        for line in buffer.lines {
            let string = line as! String
            if let name = isVariableDeclaration(string) {
                if isLineInSelectedRanges(lineCount, selections: originalSelections) {
                    result.append(name)
                }
            }
            lineCount += 1
        }
        return result
    }

    private func isLineInSelectedRanges(_ line: Int, selections: [XCSourceTextRange]) -> Bool {
        for selection in selections {
            if selection.start.line <= line && line <= selection.end.line {
                return true
            }
        }
        return false
    }
    
    private func isVariableDeclaration(_ string: String) -> String? {
        // let centeringContainer = UIView()
        let pattern = "(let|var) +([a-zA-Z0-9_]+) *= *[a-zA-Z]+\\(\\)"
        let regex = try! NSRegularExpression(pattern: pattern)
        let result = regex.matches(in:string, range:NSMakeRange(0, string.count))
        if result.count > 0 {
            let range = result[0].range(at: 2) // <-- !!
            return (string as NSString).substring(with: range) as String
        }
        return nil
    }
}
