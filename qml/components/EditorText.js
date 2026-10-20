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

function isBlank(ch) { return ch === ' ' || ch === '\t' }

function firstContent(text, offset) {
    while (offset < text.length && isBlank(text.charAt(offset)))
        ++offset
    return offset
}

function lineStartOf(text, position) {
    return position > 0 ? text.lastIndexOf("\n", position - 1) + 1 : 0
}

function lineEndOf(text, position) {
    var end = text.indexOf("\n", position)
    return end < 0 ? text.length : end
}

// ── Indentation model ────────────────────────────────────────────────────
// Indentation is a visual column, not a character string. Every edit computes
// the target column and rewrites the line's leading whitespace in the
// configured style, so mixed tabs/spaces converge instead of accumulating.
// A tab advances to the next multiple of `width`, also after spaces.

// Visual column reached at `to`, for text starting at column 0 at `from`.
function columnsBetween(text, from, to, width) {
    var column = 0
    for (var i = from; i < to; ++i)
        column += text.charAt(i) === "\t" ? width - column % width : 1
    return column
}

function leadingColumns(text, lineStart, width) {
    return columnsBetween(text, lineStart, firstContent(text, lineStart), width)
}

// Whitespace for `columns` in the configured style: tabs fill whole stops and
// spaces only the remainder (an off-grid indent stays exactly where it is).
function indentString(columns, width, useTabs) {
    if (columns <= 0) return ""
    if (!useTabs) return spaces(columns)
    return Array(Math.floor(columns / width) + 1).join("\t") + spaces(columns % width)
}

function nextStop(columns, width) { return (Math.floor(columns / width) + 1) * width }
function previousStop(columns, width) {
    return columns % width ? columns - columns % width : Math.max(0, columns - width)
}

// Indent guides sit at every stop strictly left of the line's text, i.e. under
// the parent's brackets (as in VS Code). A whitespace-only line continues the
// deeper of its non-blank neighbours, so guides do not break on empty lines.
function guideCount(text, starts, line, width) {
    var columns = contentColumns(text, starts, line, width)
    return columns > 0 ? Math.ceil(columns / width) : 0
}

function contentColumns(text, starts, line, width) {
    var start = starts[line]
    if (firstContent(text, start) < lineEndOf(text, start))
        return leadingColumns(text, start, width)
    var limit = 500 // Bound the neighbour scan for huge blank runs.
    var above = 0, below = 0
    for (var up = line - 1; up >= 0 && up >= line - limit; --up) {
        var s = starts[up]
        if (firstContent(text, s) < lineEndOf(text, s)) { above = leadingColumns(text, s, width); break }
    }
    for (var down = line + 1; down < starts.length && down <= line + limit; ++down) {
        var d = starts[down]
        if (firstContent(text, d) < lineEndOf(text, d)) { below = leadingColumns(text, d, width); break }
    }
    return Math.max(above, below)
}

// Leading-whitespace columns of the line holding the bracket matched with the
// closer at `closer`, or -1 when it is unmatched.
function matchingLineColumns(text, closer, width) {
    var open = analyze(text).pairs[closer]
    if (open === undefined) return -1
    return leadingColumns(text, lineStartOf(text, open), width)
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

// All edit functions return { from, to, text, cursor }: replace [from, to)
// with `text`, then put the caret at `cursor`. The editor applies it as one
// Undo step. `null` means "no special handling, let the TextArea do it".

// Enter. Indentation comes from the visual columns before the caret (never
// the whole line), trailing/leading blanks around the split are dropped, a
// level is added after `{`/`[`, and a closer moved down aligns with its pair.
function newlineEdit(text, position, width, useTabs) {
    var start = lineStartOf(text, position)
    var end = lineEndOf(text, position)
    var content = Math.min(firstContent(text, start), end)
    var base = columnsBetween(text, start, content, width)
    if (position <= content) {
        // Caret inside the indentation: leave an empty line above and keep
        // this line's own indentation below.
        var keep = indentString(base, width, useTabs)
        return { from: start, to: content, text: "\n" + keep, cursor: start + 1 + keep.length }
    }
    var from = position
    while (from > content && isBlank(text.charAt(from - 1))) --from
    var to = position
    while (to < end && isBlank(text.charAt(to))) ++to
    var before = text.charAt(from - 1)
    var after = to < end ? text.charAt(to) : ""
    var opens = before === '{' || before === '['
    var closes = after === '}' || after === ']'
    var inner = indentString(base + (opens ? width : 0), width, useTabs)
    if (opens && closes) {
        // Expand a pair: caret on its own line, closer back at the opener's level.
        var tail = "\n" + inner + "\n" + indentString(base, width, useTabs)
        return { from: from, to: to, text: tail, cursor: from + 1 + inner.length }
    }
    if (closes) {
        var closing = matchingLineColumns(text, to, width)
        var outer = "\n" + indentString(closing >= 0 ? closing : previousStop(base, width), width, useTabs)
        return { from: from, to: to, text: outer, cursor: from + outer.length }
    }
    return { from: from, to: to, text: "\n" + inner, cursor: from + 1 + inner.length }
}

// Tab without a selection. Inside the indentation it moves the text to the
// next stop (rewriting the indentation); after text it pads to the next stop.
function tabEdit(text, position, width, useTabs) {
    var start = lineStartOf(text, position)
    var columns = columnsBetween(text, start, position, width)
    if (firstContent(text, start) >= position) {
        var indent = indentString(nextStop(columns, width), width, useTabs)
        return { from: start, to: position, text: indent, cursor: start + indent.length }
    }
    var insertion = useTabs ? "\t" : spaces(width - columns % width)
    return { from: position, to: position, text: insertion, cursor: position + insertion.length }
}

// Backspace with only whitespace before the caret removes back to the
// previous indent stop instead of a single character.
function backspaceEdit(text, position, width, useTabs) {
    var start = lineStartOf(text, position)
    if (position === start || firstContent(text, start) < position) return null
    var indent = indentString(previousStop(columnsBetween(text, start, position, width), width),
                              width, useTabs)
    return { from: start, to: position, text: indent, cursor: start + indent.length }
}

// Left/Right inside the indentation jump a whole indent stop, so spaces behave
// like tabs (sticky tab stops, as VS Code's editor.stickyTabStops). Moving
// right stops at the text. Returns the new caret offset, or -1 for the
// TextArea's ordinary one-character move.
function indentCaretMove(text, position, width, forward) {
    var start = lineStartOf(text, position)
    var content = Math.min(firstContent(text, start), lineEndOf(text, position))
    if (position > content || position === (forward ? content : start)) return -1
    var column = columnsBetween(text, start, position, width)
    var target = forward ? Math.min(nextStop(column, width), columnsBetween(text, start, content, width))
                         : previousStop(column, width)
    var offset = offsetAtColumn(text, start, content, target, width)
    return offset !== position ? offset : -1
}

// A mouse placement inside the indentation snaps to the nearest indent stop
// (or the start of the text), the same positions the arrows step through.
// A tie goes to the left stop. Positions outside the indentation are kept.
function snapToIndentStop(text, position, width) {
    var start = lineStartOf(text, position)
    var content = Math.min(firstContent(text, start), lineEndOf(text, position))
    if (position <= start || position >= content) return position
    var column = columnsBetween(text, start, position, width)
    var below = column - column % width
    var above = Math.min(below + width, columnsBetween(text, start, content, width))
    var offset = offsetAtColumn(text, start, content, column - below <= above - column ? below : above, width)
    return offset < 0 ? position : offset
}

// Offset in [start, content] whose visual column is exactly `column`, or -1
// when a tab straddles it (then the character boundary already is a stop).
function offsetAtColumn(text, start, content, column, width) {
    var offset = start, at = 0
    while (offset < content && at < column) {
        at += text.charAt(offset) === "\t" ? width - at % width : 1
        ++offset
    }
    return at === column ? offset : -1
}

// Typing `}`/`]` with only whitespace before the caret aligns the line with
// the line of the matching opener. `null` when nothing needs to change.
function closingBracketEdit(text, position, closer, width, useTabs) {
    var start = lineStartOf(text, position)
    if (firstContent(text, start) < position) return null
    var probe = text.slice(0, position) + closer + text.slice(position)
    var columns = matchingLineColumns(probe, position, width)
    if (columns < 0) return null
    var indent = indentString(columns, width, useTabs)
    if (indent === text.slice(start, position)) return null
    return { from: start, to: position, text: indent + closer, cursor: start + indent.length + 1 }
}

// Shift the logical lines touched by a selection, excluding an end at column 0.
// Indent moves to the next stop, outdent to the previous one; the whole
// leading whitespace is rewritten in the configured style. Empty and
// whitespace-only lines are not indented (no trailing whitespace).
// Return one replacement plus adjusted selection bounds; preserve all other text.
function blockIndentEdit(text, selectionStart, selectionEnd, width, useTabs, backwards) {
    var start = Math.min(selectionStart, selectionEnd)
    var end = Math.max(selectionStart, selectionEnd)
    var selected = start !== end
    var from = lineStartOf(text, start)
    var last = selected ? end - 1 : end
    var to = text.indexOf("\n", last)
    if (to < 0) to = text.length
    var lines = text.slice(from, to).split("\n")
    var edits = []
    var position = from
    for (var i = 0; i < lines.length; ++i) {
        var line = lines[i]
        var content = firstContent(line, 0)
        var blank = content === line.length
        if (!(blank && !backwards)) {
            var columns = columnsBetween(line, 0, content, width)
            var target = backwards ? previousStop(columns, width) : nextStop(columns, width)
            var oldIndent = line.slice(0, content)
            var newIndent = indentString(target, width, useTabs)
            if (oldIndent !== newIndent) {
                // Record the change at the line start, keeping the common
                // suffix, so carets inside the indent keep their distance to text.
                var same = 0
                while (same < oldIndent.length && same < newIndent.length
                       && oldIndent.charAt(oldIndent.length - 1 - same)
                          === newIndent.charAt(newIndent.length - 1 - same))
                    ++same
                edits.push({ position: position, removed: oldIndent.length - same,
                             added: newIndent.length - same })
                lines[i] = newIndent + line.slice(content)
            }
        }
        position += line.length + 1
    }
    function adjusted(point, keepStart) {
        var delta = 0
        for (var i = 0; i < edits.length; ++i) {
            var edit = edits[i]
            if (point < edit.position || (point === edit.position && keepStart)) break
            delta += edit.added - Math.min(edit.removed, point - edit.position)
        }
        return point + delta
    }
    return {
        from: from, to: to, text: lines.join("\n"), changed: edits.length > 0,
        selectionStart: adjusted(start, selected), selectionEnd: adjusted(end, false)
    }
}
