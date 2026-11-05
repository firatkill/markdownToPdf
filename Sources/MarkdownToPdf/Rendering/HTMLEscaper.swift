import Markdown

/// swift-markdown's `HTMLFormatter` writes text, code and link targets verbatim.
/// This rewriter escapes them first, so `a < b` or `<div>` inside a code block
/// show up as text instead of being treated as HTML. Raw HTML blocks are left alone.
struct HTMLEscaper: MarkupRewriter {
    mutating func visitText(_ text: Text) -> Markup? {
        var text = text
        text.string = MarkdownHTML.escapeText(text.string)
        return text
    }

    mutating func visitInlineCode(_ inlineCode: InlineCode) -> Markup? {
        var inlineCode = inlineCode
        inlineCode.code = MarkdownHTML.escapeText(inlineCode.code)
        return inlineCode
    }

    mutating func visitCodeBlock(_ codeBlock: CodeBlock) -> Markup? {
        var codeBlock = codeBlock
        codeBlock.code = MarkdownHTML.escapeText(codeBlock.code)
        if let language = codeBlock.language {
            codeBlock.language = MarkdownHTML.escapeAttribute(language)
        }
        return codeBlock
    }

    mutating func visitLink(_ link: Link) -> Markup? {
        var link = link
        if let destination = link.destination {
            link.destination = MarkdownHTML.escapeAttribute(destination)
        }
        return defaultVisit(link)
    }

    mutating func visitImage(_ image: Image) -> Markup? {
        var image = image
        if let source = image.source {
            image.source = MarkdownHTML.escapeAttribute(source)
        }
        if let title = image.title {
            image.title = MarkdownHTML.escapeAttribute(title)
        }
        return image
    }
}
