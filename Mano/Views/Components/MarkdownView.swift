//
//  MarkdownView.swift
//  Mano
//
//  Created by Claude on 03/09/2025.
//

import SwiftUI

struct MarkdownView: View {
    let content: String
    let isUserMessage: Bool
    
    var body: some View {
        VStack(alignment: isUserMessage ? .trailing : .leading, spacing: 6) {
            ForEach(parseMarkdown(content), id: \.id) { element in
                renderElement(element)
            }
        }
    }
    
    private func renderElement(_ element: MarkdownElement) -> some View {
        Group {
            switch element.type {
            case .paragraph:
                renderParagraph(element)
            case .heading:
                renderHeading(element)
            case .bulletList:
                renderBulletList(element)
            case .numberedList:
                renderNumberedList(element)
            case .codeBlock:
                renderCodeBlock(element)
            case .blockquote:
                renderBlockquote(element)
            }
        }
    }
    
    private func renderParagraph(_ element: MarkdownElement) -> some View {
        parseInlineMarkdown(element.content)
            .multilineTextAlignment(isUserMessage ? .trailing : .leading)
            .fixedSize(horizontal: false, vertical: true)
    }
    
    private func renderHeading(_ element: MarkdownElement) -> some View {
        let level = element.level ?? 1
        let fontSize: CGFloat = max(18 - CGFloat(level - 1) * 2, 14)
        
        return Text(element.content.trimmingCharacters(in: .whitespaces))
            .font(.system(size: fontSize, weight: .bold))
            .multilineTextAlignment(isUserMessage ? .trailing : .leading)
            .padding(.top, 4)
            .fixedSize(horizontal: false, vertical: true)
    }
    
    private func renderBulletList(_ element: MarkdownElement) -> some View {
        VStack(alignment: isUserMessage ? .trailing : .leading, spacing: 2) {
            ForEach(element.items ?? [], id: \.self) { item in
                HStack(alignment: .top, spacing: 6) {
                    if !isUserMessage {
                        Text("•")
                            .font(.system(size: 14))
                        parseInlineMarkdown(item)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    } else {
                        Spacer(minLength: 0)
                        parseInlineMarkdown(item)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("•")
                            .font(.system(size: 14))
                    }
                }
            }
        }
    }
    
    private func renderNumberedList(_ element: MarkdownElement) -> some View {
        VStack(alignment: isUserMessage ? .trailing : .leading, spacing: 2) {
            ForEach(Array((element.items ?? []).enumerated()), id: \.offset) { index, item in
                HStack(alignment: .top, spacing: 6) {
                    if !isUserMessage {
                        Text(String(index + 1) + ".")
                            .font(.system(size: 14))
                            .monospacedDigit()
                        parseInlineMarkdown(item)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    } else {
                        Spacer(minLength: 0)
                        parseInlineMarkdown(item)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(String(index + 1) + ".")
                            .font(.system(size: 14))
                            .monospacedDigit()
                    }
                }
            }
        }
    }
    
    private func renderCodeBlock(_ element: MarkdownElement) -> some View {
        Text(element.content)
            .font(.system(.body, design: .monospaced))
            .padding(8)
            .background(Color.gray.opacity(0.2))
            .cornerRadius(6)
            .frame(maxWidth: .infinity, alignment: isUserMessage ? .trailing : .leading)
    }
    
    private func renderBlockquote(_ element: MarkdownElement) -> some View {
        HStack(alignment: .top, spacing: 8) {
            if !isUserMessage {
                Rectangle()
                    .fill(Color.gray.opacity(0.6))
                    .frame(width: 3)
                parseInlineMarkdown(element.content)
                    .italic()
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            } else {
                Spacer(minLength: 0)
                parseInlineMarkdown(element.content)
                    .italic()
                    .fixedSize(horizontal: false, vertical: true)
                Rectangle()
                    .fill(Color.gray.opacity(0.6))
                    .frame(width: 3)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func parseInlineMarkdown(_ text: String) -> Text {
        // Simple markdown parsing for bold, italic, and code
        let components = parseInlineComponents(text)
        
        return components.reduce(Text("")) { result, component in
            switch component.type {
            case .plain:
                return result + Text(component.text)
            case .bold:
                return result + Text(component.text).bold()
            case .italic:
                return result + Text(component.text).italic()
            case .code:
                return result + Text(component.text)
                    .font(.system(.body, design: .monospaced))
            }
        }
    }
    
    private func parseInlineComponents(_ text: String) -> [InlineComponent] {
        var components: [InlineComponent] = []
        var remainingText = text
        
        while !remainingText.isEmpty {
            // Look for bold text (**text**)
            if let range = findPattern(in: remainingText, pattern: "**") {
                // Add text before the pattern
                let beforePattern = String(remainingText[..<range.start])
                if !beforePattern.isEmpty {
                    components.append(InlineComponent(type: .plain, text: beforePattern))
                }
                
                // Add the formatted text
                components.append(InlineComponent(type: .bold, text: range.content))
                
                // Continue with remaining text
                remainingText = String(remainingText[range.end...])
                continue
            }
            
            // Look for italic text (*text*)
            if let range = findPattern(in: remainingText, pattern: "*") {
                let beforePattern = String(remainingText[..<range.start])
                if !beforePattern.isEmpty {
                    components.append(InlineComponent(type: .plain, text: beforePattern))
                }
                
                components.append(InlineComponent(type: .italic, text: range.content))
                remainingText = String(remainingText[range.end...])
                continue
            }
            
            // Look for code (`text`)
            if let range = findPattern(in: remainingText, pattern: "`") {
                let beforePattern = String(remainingText[..<range.start])
                if !beforePattern.isEmpty {
                    components.append(InlineComponent(type: .plain, text: beforePattern))
                }
                
                components.append(InlineComponent(type: .code, text: range.content))
                remainingText = String(remainingText[range.end...])
                continue
            }
            
            // No patterns found, add remaining text
            components.append(InlineComponent(type: .plain, text: remainingText))
            break
        }
        
        return components
    }
    
    private func findPattern(in text: String, pattern: String) -> (start: String.Index, content: String, end: String.Index)? {
        guard let startIndex = text.range(of: pattern)?.lowerBound else { return nil }
        let afterStart = text.index(startIndex, offsetBy: pattern.count)
        
        guard let endRange = text[afterStart...].range(of: pattern) else { return nil }
        let content = String(text[afterStart..<endRange.lowerBound])
        let endIndex = endRange.upperBound
        
        return (start: startIndex, content: content, end: endIndex)
    }
}

struct InlineComponent {
    let type: InlineComponentType
    let text: String
}

enum InlineComponentType {
    case plain
    case bold
    case italic
    case code
}

// MARK: - Markdown Parsing

struct MarkdownElement {
    let id = UUID()
    let type: MarkdownElementType
    let content: String
    let level: Int?
    let items: [String]?
    
    init(type: MarkdownElementType, content: String, level: Int? = nil, items: [String]? = nil) {
        self.type = type
        self.content = content
        self.level = level
        self.items = items
    }
}

enum MarkdownElementType {
    case paragraph
    case heading
    case bulletList
    case numberedList
    case codeBlock
    case blockquote
}

private func parseMarkdown(_ markdown: String) -> [MarkdownElement] {
    let lines = markdown.components(separatedBy: .newlines)
    var elements: [MarkdownElement] = []
    var currentParagraph = ""
    var currentCodeBlock = ""
    var inCodeBlock = false
    var currentListItems: [String] = []
    var currentListType: MarkdownElementType?
    
    func flushParagraph() {
        if !currentParagraph.isEmpty {
            elements.append(MarkdownElement(type: .paragraph, content: currentParagraph.trimmingCharacters(in: .whitespaces)))
            currentParagraph = ""
        }
    }
    
    func flushList() {
        if !currentListItems.isEmpty, let listType = currentListType {
            elements.append(MarkdownElement(type: listType, content: "", items: currentListItems))
            currentListItems = []
            currentListType = nil
        }
    }
    
    for line in lines {
        let trimmedLine = line.trimmingCharacters(in: .whitespaces)
        
        // Code blocks
        if trimmedLine.hasPrefix("```") {
            if inCodeBlock {
                elements.append(MarkdownElement(type: .codeBlock, content: currentCodeBlock))
                currentCodeBlock = ""
                inCodeBlock = false
            } else {
                flushParagraph()
                flushList()
                inCodeBlock = true
            }
            continue
        }
        
        if inCodeBlock {
            currentCodeBlock += line + "\n"
            continue
        }
        
        // Headings
        if trimmedLine.hasPrefix("#") {
            flushParagraph()
            flushList()
            let level = trimmedLine.prefix(while: { $0 == "#" }).count
            let content = String(trimmedLine.dropFirst(level)).trimmingCharacters(in: .whitespaces)
            elements.append(MarkdownElement(type: .heading, content: content, level: level))
            continue
        }
        
        // Bullet lists
        if trimmedLine.hasPrefix("- ") || trimmedLine.hasPrefix("* ") || trimmedLine.hasPrefix("+ ") {
            flushParagraph()
            if currentListType != .bulletList {
                flushList()
                currentListType = .bulletList
            }
            let content = String(trimmedLine.dropFirst(2)).trimmingCharacters(in: .whitespaces)
            currentListItems.append(content)
            continue
        }
        
        // Numbered lists (simple check for "1. ", "2. ", etc.)
        if let match = trimmedLine.firstMatch(of: /^(\d+)\.\s+(.*)$/) {
            flushParagraph()
            if currentListType != .numberedList {
                flushList()
                currentListType = .numberedList
            }
            currentListItems.append(String(match.output.2))
            continue
        }
        
        // Blockquotes
        if trimmedLine.hasPrefix("> ") {
            flushParagraph()
            flushList()
            let content = String(trimmedLine.dropFirst(2)).trimmingCharacters(in: .whitespaces)
            elements.append(MarkdownElement(type: .blockquote, content: content))
            continue
        }
        
        // Empty lines
        if trimmedLine.isEmpty {
            flushParagraph()
            flushList()
            continue
        }
        
        // Regular paragraph text
        flushList()
        if !currentParagraph.isEmpty {
            currentParagraph += " "
        }
        currentParagraph += trimmedLine
    }
    
    // Flush remaining content
    flushParagraph()
    flushList()
    if inCodeBlock && !currentCodeBlock.isEmpty {
        elements.append(MarkdownElement(type: .codeBlock, content: currentCodeBlock))
    }
    
    return elements
}

#Preview {
    let sampleMarkdown = """
# Sample Heading

This is a **bold** paragraph with *italic* text and `inline code`.

## Subheading

Here's a bullet list:
- First item with **bold** text
- Second item with *italic* text
- Third item with `code`

And a numbered list:
1. First numbered item
2. Second numbered item
3. Third numbered item

> This is a blockquote with some important information.

```swift
func example() {
    print("Hello, World!")
}
```

Final paragraph with mixed formatting.
"""
    
    VStack(spacing: 20) {
        MarkdownView(content: sampleMarkdown, isUserMessage: false)
            .padding()
            .background(Color.gray.opacity(0.2))
            .cornerRadius(12)
        
        MarkdownView(content: "This is a **user message** with *formatting*!", isUserMessage: true)
            .padding()
            .background(Color.blue)
            .foregroundStyle(.white)
            .cornerRadius(12)
    }
    .padding()
}