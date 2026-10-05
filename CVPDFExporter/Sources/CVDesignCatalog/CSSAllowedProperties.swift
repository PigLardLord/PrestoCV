import Foundation

/// The keywords each property accepts, in one place. markup-contract.md lists the same sets and a test compares
/// them (#83), so the policy cannot accept a keyword the page does not document.
let propertyKeywords: [String: Set<String>] = {
    let borderStyles: Set<String> = ["solid", "dashed", "dotted", "none"]
    return [
        "background-color": ["transparent"],
        "font-weight": ["normal", "bold"],
        "font-style": ["normal", "italic"],
        "line-height": ["normal"],
        "text-transform": ["none", "uppercase", "lowercase", "capitalize"],
        "text-align": ["left", "right", "center", "justify", "start", "end"],
        "text-decoration": ["none", "underline"],
        "border": borderStyles, "border-top": borderStyles, "border-bottom": borderStyles, "border-left": borderStyles, "border-right": borderStyles,
        "display": ["block", "inline", "inline-block", "flex", "inline-flex", "grid"],
        "flex-direction": ["row", "column"],
        "flex-wrap": ["wrap", "nowrap"],
        "justify-content": ["flex-start", "flex-end", "center", "space-between", "space-around", "start", "end"],
        "align-items": ["flex-start", "flex-end", "center", "baseline", "stretch", "start", "end"],
        "break-inside": ["auto", "avoid"], "page-break-inside": ["auto", "avoid"],
        "break-before": ["auto", "page", "avoid"], "break-after": ["auto", "page", "avoid"],
    ]
}()

private func keywordsOf(_ property: String) -> Set<String> { propertyKeywords[property, default: []] }

/// The allow-list. Properties not listed here are rejected, which excludes by construction everything
/// that can load resources, hide, move, reorder or inject content (position, transform, zoom, filter,
/// mask, clip, overflow, visibility, opacity, content, list-style, quotes, counters, direction, order…).
let allowedProperties: [String: CSSValue.Check] = [
    "color": CSSValue.paletteColor,
    "background-color": CSSValue.variable(["--color-background"], orKeywords: keywordsOf("background-color")),
    "border-color": CSSValue.paletteColor,
    "font-family": CSSValue.variable(["--font-body", "--font-heading"]),
    "font-size": CSSValue.lengths(LengthBounds.fontSize, count: 1...1),
    "font-weight": CSSValue.number(100...900, keywords: keywordsOf("font-weight")),
    "font-style": CSSValue.keyword(keywordsOf("font-style")),
    "line-height": CSSValue.number(1...3, keywords: keywordsOf("line-height")),
    "letter-spacing": CSSValue.lengths(LengthBounds.letterSpacing, count: 1...1),
    "text-transform": CSSValue.keyword(keywordsOf("text-transform")),
    "text-align": CSSValue.keyword(keywordsOf("text-align")),
    "text-decoration": CSSValue.keyword(keywordsOf("text-decoration")),
    "margin": CSSValue.lengths(LengthBounds.spacing, count: 1...4),
    "margin-top": CSSValue.lengths(LengthBounds.spacing, count: 1...1),
    "margin-bottom": CSSValue.lengths(LengthBounds.spacing, count: 1...1),
    "margin-left": CSSValue.lengths(LengthBounds.spacing, count: 1...1),
    "margin-right": CSSValue.lengths(LengthBounds.spacing, count: 1...1),
    "padding": CSSValue.lengths(LengthBounds.spacing, count: 1...4),
    "padding-top": CSSValue.lengths(LengthBounds.spacing, count: 1...1),
    "padding-bottom": CSSValue.lengths(LengthBounds.spacing, count: 1...1),
    "padding-left": CSSValue.lengths(LengthBounds.spacing, count: 1...1),
    "padding-right": CSSValue.lengths(LengthBounds.spacing, count: 1...1),
    "border": CSSValue.border(styles: keywordsOf("border")), "border-top": CSSValue.border(styles: keywordsOf("border-top")),
    "border-bottom": CSSValue.border(styles: keywordsOf("border-bottom")), "border-left": CSSValue.border(styles: keywordsOf("border-left")),
    "border-right": CSSValue.border(styles: keywordsOf("border-right")),
    "border-radius": CSSValue.lengths(LengthBounds.borderRadius, count: 1...1),
    "display": CSSValue.keyword(keywordsOf("display")),
    "flex-direction": CSSValue.keyword(keywordsOf("flex-direction")),
    "flex-wrap": CSSValue.keyword(keywordsOf("flex-wrap")),
    "flex": CSSValue.number(0...10),
    "justify-content": CSSValue.keyword(keywordsOf("justify-content")),
    "align-items": CSSValue.keyword(keywordsOf("align-items")),
    "gap": CSSValue.gap,
    "row-gap": CSSValue.lengths(LengthBounds.spacing, count: 1...1),
    "column-gap": CSSValue.lengths(LengthBounds.columnGap, count: 1...1),
    "grid-template-columns": CSSValue.gridColumns,
    "width": CSSValue.lengths(LengthBounds.extent, count: 1...1),
    "max-width": CSSValue.lengths(LengthBounds.extent, count: 1...1),
    "break-inside": CSSValue.keyword(keywordsOf("break-inside")),
    "page-break-inside": CSSValue.keyword(keywordsOf("page-break-inside")),
    "break-before": CSSValue.keyword(keywordsOf("break-before")),
    "break-after": CSSValue.keyword(keywordsOf("break-after")),
]
