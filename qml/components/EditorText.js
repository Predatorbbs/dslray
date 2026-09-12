.pragma library

// Pure text operations shared by the editor and its regression tests.
function lineStarts(text) {
    var starts = [0]
    for (var i = 0; i < text.length; ++i)
        if (text.charCodeAt(i) === 10) starts.push(i + 1)
    return starts
}

// The newline itself belongs to the preceding logical line. Looking up a
// cursor/viewport position must not copy or rescan the document prefix.
function lineAt(starts, position) {
    var low = 0
    var high = starts.length
    while (low + 1 < high) {
        var middle = Math.floor((low + high) / 2)
        if (starts[middle] <= position) low = middle
        else high = middle
    }
    return low
}

function analyze(text) {
    var pairs = ({})
    var errors = []
    var stack = []
    var inStr = false, esc = false, strStart = -1
    for (var i = 0; i < text.length; ++i) {
        var ch = text.charAt(i)
        if (inStr) {
            if (esc) { esc = false; continue }
            if (ch === '\\') { esc = true; continue }
            if (ch === '"') inStr = false
            continue
        }
        if (ch === '"') { inStr = true; strStart = i; continue }
        if (ch === '{' || ch === '[') {
            stack.push(i)
        } else if (ch === '}' || ch === ']') {
            if (stack.length === 0) {
                errors.push(i)
            } else {
                var open = stack.pop()
                var oc = text.charAt(open)
                if ((oc === '{' && ch === '}') || (oc === '[' && ch === ']')) {
                    pairs[open] = i
                    pairs[i] = open
                } else {
                    errors.push(i); errors.push(open)
                }
            }
        }
    }
    for (var s = 0; s < stack.length; ++s)
        errors.push(stack[s])
    if (inStr && strStart >= 0)
        errors.push(strStart)
    return { pairs: pairs, errors: errors }
}

function spaces(count) { return count > 0 ? Array(count + 1).join(" ") : "" }
function indentUnit(width, useTabs) { return useTabs ? "\t" : spaces(width) }

function firstContent(text, offset) {
    while (offset < text.length) {
        var ch = text.charAt(offset)
        if (ch !== ' ' && ch !== '\t') break
        ++offset
    }
    return offset
}

function indentStops(text, offset, width) {
    var columns = 0
    for (var i = offset; i < text.length; ++i) {
        var ch = text.charAt(i)
        if (ch === ' ') columns++
        else if (ch === '\t') columns += width
        else break
    }
    return Math.floor(columns / width)
}

// Preserve the original line-local string handling, including while the user
// is editing incomplete JSON. Formatting changes whitespace only.
function reindent(text, width, useTabs) {
    var unit = indentUnit(width, useTabs)
    var lines = text.split("\n")
    var depth = 0
    var result = []
    for (var li = 0; li < lines.length; ++li) {
        var content = lines[li].replace(/^[ \t]+/, "").replace(/[ \t]+$/, "")
        if (content.length === 0) { result.push(""); continue }
        var lead = content.charAt(0)
        var lineDepth = (lead === '}' || lead === ']') ? Math.max(0, depth - 1) : depth
        result.push(Array(lineDepth + 1).join(unit) + content)
        var inStr = false, esc = false
        for (var ci = 0; ci < content.length; ++ci) {
            var ch = content.charAt(ci)
            if (inStr) {
                if (esc) esc = false
                else if (ch === '\\') esc = true
                else if (ch === '"') inStr = false
                continue
            }
            if (ch === '"') { inStr = true; continue }
            if (ch === '{' || ch === '[') depth++
            else if (ch === '}' || ch === ']') depth = Math.max(0, depth - 1)
        }
    }
    return result.join("\n")
}

// Describe the insertion; TextArea performs it itself to retain undo support.
function newlineEdit(text, position, width, useTabs) {
    var start = position > 0 ? text.lastIndexOf("\n", position - 1) + 1 : 0
    var indent = text.slice(start, firstContent(text, start))
    var before = position > 0 ? text.charAt(position - 1) : ''
    var after = text.charAt(position)
    var opens = before === '{' || before === '['
    var inner = indent + (opens ? indentUnit(width, useTabs) : "")
    var insertion = "\n" + inner
    var cursor = position + insertion.length
    if ((before === '{' && after === '}') || (before === '[' && after === ']'))
        insertion += "\n" + indent
    return { text: insertion, cursor: cursor }
}

function tabText(text, position, width, useTabs) {
    if (useTabs) return "\t"
    var start = position > 0 ? text.lastIndexOf("\n", position - 1) + 1 : 0
    return spaces(width - ((position - start) % width))
}
