import Foundation
import Markdown

/// Turns Markdown text into a complete, print-ready HTML document.
enum MarkdownHTML {
    /// Builds the HTML page for a Markdown file.
    /// - Parameters:
    ///   - markdown: The Markdown source.
    ///   - title: Used for the `<title>` element.
    ///   - baseURL: The folder of the source file, so relative image paths resolve.
    static func document(from markdown: String, title: String, baseURL: URL) -> String {
        var escaper = HTMLEscaper()
        let document = escaper.visit(Document(parsing: markdown)) ?? Document()
        let body = HTMLFormatter.format(document)
        return """
        <!doctype html>
        <html>
        <head>
        <meta charset="utf-8">
        <base href="\(escapeAttribute(baseURL.absoluteString))">
        <title>\(escapeText(title))</title>
        <style>\(stylesheet)</style>
        </head>
        <body>
        <article class="markdown-body">
        \(body)
        </article>
        </body>
        </html>
        """
    }

    static func escapeText(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    static func escapeAttribute(_ value: String) -> String {
        escapeText(value).replacingOccurrences(of: "\"", with: "&quot;")
    }

    /// A GitHub-like stylesheet tuned for paper.
    static let stylesheet = """
    * { box-sizing: border-box; }
    html { -webkit-print-color-adjust: exact; print-color-adjust: exact; }
    body {
      margin: 0;
      font-family: -apple-system, "Helvetica Neue", Helvetica, Arial, sans-serif;
      font-size: 11pt;
      line-height: 1.55;
      color: #1f2328;
      background: #ffffff;
      word-wrap: break-word;
    }
    .markdown-body > *:first-child { margin-top: 0 !important; }
    h1, h2, h3, h4, h5, h6 {
      margin: 1.4em 0 0.6em;
      font-weight: 600;
      line-height: 1.25;
      page-break-after: avoid;
      break-after: avoid;
    }
    h1 { font-size: 2em; padding-bottom: 0.3em; border-bottom: 1px solid #d1d9e0; }
    h2 { font-size: 1.5em; padding-bottom: 0.3em; border-bottom: 1px solid #d1d9e0; }
    h3 { font-size: 1.25em; }
    h4 { font-size: 1em; }
    h5 { font-size: 0.875em; }
    h6 { font-size: 0.85em; color: #59636e; }
    p, blockquote, ul, ol, dl, table, pre { margin: 0 0 1em; }
    a { color: #0969da; text-decoration: none; }
    strong { font-weight: 600; }
    hr { height: 0.25em; margin: 1.5em 0; padding: 0; background: #d1d9e0; border: 0; }
    ul, ol { padding-left: 2em; }
    li + li { margin-top: 0.25em; }
    li > p { margin: 0; }
    li > p + p { margin-top: 0.5em; }
    li > ul, li > ol { margin: 0.25em 0 0; }
    li > input[type="checkbox"] { margin: 0 0.4em 0 -1.4em; vertical-align: middle; }
    li > input[type="checkbox"] + p { display: inline; }
    ul:has(> li > input[type="checkbox"]) { list-style: none; }
    blockquote {
      margin-left: 0;
      padding: 0 1em;
      color: #59636e;
      border-left: 0.25em solid #d1d9e0;
    }
    code, pre {
      font-family: "SF Mono", Menlo, Monaco, Consolas, monospace;
      font-size: 0.85em;
    }
    code {
      padding: 0.2em 0.4em;
      background: #eff1f3;
      border-radius: 6px;
    }
    pre {
      padding: 1em;
      overflow: hidden;
      line-height: 1.45;
      background: #f6f8fa;
      border-radius: 6px;
      white-space: pre-wrap;
      page-break-inside: avoid;
      break-inside: avoid;
    }
    pre code { padding: 0; background: transparent; border-radius: 0; font-size: 1em; }
    table {
      display: table;
      width: auto;
      max-width: 100%;
      border-spacing: 0;
      border-collapse: collapse;
      page-break-inside: auto;
    }
    tr { page-break-inside: avoid; break-inside: avoid; }
    th, td { padding: 6px 13px; border: 1px solid #d1d9e0; }
    th { font-weight: 600; background: #f6f8fa; }
    tr:nth-child(2n) td { background: #f6f8fa; }
    img { max-width: 100%; page-break-inside: avoid; break-inside: avoid; }
    """
}
