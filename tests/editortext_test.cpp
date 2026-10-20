#include "editortext_test.h"
#include <QFile>
#include <QJSEngine>
#include <QJsonDocument>
#include <QTest>

QJSValue EditorTextTest::call(const char *name, const QJSValueList &arguments)
{
    return m_engine.globalObject().property(QString::fromLatin1(name)).call(arguments);
}

void EditorTextTest::initTestCase()
{
    QFile source(QString::fromUtf8(EDITOR_TEXT_SOURCE_PATH));
    QVERIFY2(source.open(QIODevice::ReadOnly), qPrintable(source.errorString()));
    QString script = QString::fromUtf8(source.readAll());
    QVERIFY(script.startsWith(QStringLiteral(".pragma library")));
    // QML's library directive is not JavaScript; evaluate the same source
    // using Qt's JS engine after dropping just that first line.
    script.remove(0, script.indexOf(QLatin1Char('\n')) + 1);
    const auto loaded = m_engine.evaluate(script, source.fileName());
    QVERIFY2(!loaded.isError(), qPrintable(loaded.toString()));
}

void EditorTextTest::logicalLines_data()
{
    QTest::addColumn<QString>("text");
    QTest::newRow("empty") << QString();
    QTest::newRow("trailing-newline") << QStringLiteral("one\ntwo\n");
    QTest::newRow("empty-lines") << QStringLiteral("\n\ntext\n\n");
    QTest::newRow("crlf") << QStringLiteral("a\r\nb\r\n");
    QTest::newRow("utf16") << QString::fromUtf8("α\n🙂x\nёж");
}

void EditorTextTest::logicalLines()
{
    QFETCH(QString, text);
    const auto starts = call("lineStarts", {text});
    QVERIFY(!starts.isError());
    QCOMPARE(starts.property(0).toInt(), 0);
    QCOMPARE(starts.property("length").toInt(), text.count(QLatin1Char('\n')) + 1);
    // Every cursor position, including the newline and EOF boundaries,
    // must select the same logical line as the original editor did.
    for (int position = 0; position <= text.size(); ++position) {
        const auto line = call("lineAt", {starts, position});
        QCOMPARE(line.toInt(), text.left(position).count(QLatin1Char('\n')));
    }
}

void EditorTextTest::lineLookupIsLogarithmic()
{
    // Count index reads rather than use a timing threshold: scrolling near
    // the end of a large file must not traverse all preceding lines.

    const auto result = m_engine.evaluate(QStringLiteral(R"JS(
        (function() {
            var reads = 0;
            var starts = { length: 65536 };
            for (var i = 0; i < starts.length; ++i) {
                (function(index) {
                    Object.defineProperty(starts, index, {
                        get: function() { ++reads; return index * 10; }
                    });
                })(i);
            }
            var line = lineAt(starts, 655359);
            return { line: line, reads: reads };
        })()
    )JS"));

    QVERIFY2(!result.isError(), qPrintable(result.toString()));
    QCOMPARE(result.property("line").toInt(), 65535);
    QVERIFY(result.property("reads").toInt() <= 16);
}

void EditorTextTest::escapedStringsDoNotProduceBrackets()
{

    const QString text = QString::fromUtf8(R"JSON({"s":"[\"\\]", "tail":"\\", "a":[{}]})JSON");

    QVERIFY(!QJsonDocument::fromJson(text.toUtf8()).isNull());
    const auto result = call("analyze", {text});
    QVERIFY(!result.isError());
    QCOMPARE(result.property("errors").property("length").toInt(), 0);
    const auto pairs = result.property("pairs").toVariant().toMap();
    QCOMPARE(pairs.size(), 6);
    QCOMPARE(pairs.value(QStringLiteral("0")).toInt(), text.size() - 1);
    const int array = text.indexOf(QStringLiteral("[{}]"));
    QCOMPARE(pairs.value(QString::number(array)).toInt(), array + 3);
    QCOMPARE(pairs.value(QString::number(array + 3)).toInt(), array);
    QCOMPARE(pairs.value(QString::number(array + 1)).toInt(), array + 2);
    QCOMPARE(pairs.value(QString::number(array + 2)).toInt(), array + 1);
}

void EditorTextTest::bracketErrors_data()
{
    QTest::addColumn<QString>("text");
    QTest::addColumn<QVariantList>("errors");
    QTest::newRow("mismatched") << QStringLiteral("{[}]") << QVariantList({2, 1, 3, 0});
    QTest::newRow("unmatched") << QStringLiteral("]{") << QVariantList({0, 1});
    QTest::newRow("unterminated-string") << QStringLiteral("{\"key\":\"value") << QVariantList({0, 7});
    QTest::newRow("trailing-escape") << QStringLiteral("\"value\\") << QVariantList({0});
    QTest::newRow("empty") << QString() << QVariantList();
}

void EditorTextTest::bracketErrors()
{
    QFETCH(QString, text);
    QFETCH(QVariantList, errors);
    const auto result = call("analyze", {text});
    QVERIFY(!result.isError());
    QCOMPARE(result.property("errors").toVariant().toList(), errors);
    QVERIFY(result.property("pairs").toVariant().toMap().isEmpty());
}

void EditorTextTest::formattingPreservesJsonAndIsIdempotent()
{
    const QString input = QString::fromUtf8("{\n\"value\": \"[\\\"\\\\]\",  \n\"nested\": [\n{}  \n]\n}\n");
    const QString expected = QString::fromUtf8("{\n  \"value\": \"[\\\"\\\\]\",\n  \"nested\": [\n    {}\n  ]\n}\n");
    const auto originalJson = QJsonDocument::fromJson(input.toUtf8());
    QVERIFY(!originalJson.isNull());
    for (bool useTabs : {false, true}) {
        const auto result = call("reindent", {input, 2, useTabs});
        QVERIFY(!result.isError());
        const QString formatted = result.toString();
        QString expectedIndent = expected;
        if (useTabs) expectedIndent.replace(QStringLiteral("  "), QStringLiteral("\t"));
        QCOMPARE(formatted, expectedIndent);
        QCOMPARE(QJsonDocument::fromJson(formatted.toUtf8()), originalJson);
        QCOMPARE(call("reindent", {formatted, 2, useTabs}).toString(), formatted);
    }
}

// Apply an EditorText edit ({from, to, text, cursor}) and return the result.
// A null edit leaves the text unchanged and the caret at `position`.
static QString applied(const QString &text, const QJSValue &edit, int position, int *cursor)
{
    if (edit.isNull()) {
        *cursor = position;
        return text;
    }
    const int from = edit.property("from").toInt();
    QString result = text;
    result.replace(from, edit.property("to").toInt() - from, edit.property("text").toString());
    *cursor = edit.property("cursor").toInt();
    return result;
}

void EditorTextTest::newlineInsertion_data()
{
    QTest::addColumn<QString>("text");
    QTest::addColumn<int>("position");
    QTest::addColumn<int>("width");
    QTest::addColumn<bool>("useTabs");
    QTest::addColumn<QString>("expected");
    QTest::addColumn<int>("cursor");
    QTest::newRow("pair") << QStringLiteral("  {}") << 3 << 2 << false
        << QStringLiteral("  {\n    \n  }") << 8;
    QTest::newRow("tab-pair") << QStringLiteral("\t[]") << 2 << 2 << true
        << QStringLiteral("\t[\n\t\t\n\t]") << 5;
    QTest::newRow("opening") << QStringLiteral("  [") << 3 << 2 << false << QStringLiteral("  [\n    ") << 8;
    QTest::newRow("plain") << QStringLiteral("  value") << 7 << 2 << false << QStringLiteral("  value\n  ") << 10;
    QTest::newRow("start-before-newline") << QStringLiteral("\n  next") << 0 << 2 << false
        << QStringLiteral("\n\n  next") << 1;
    QTest::newRow("empty") << QString() << 0 << 2 << false << QStringLiteral("\n") << 1;
    // The indentation never doubles when the caret is at or inside it.
    QTest::newRow("caret-at-line-start") << QStringLiteral("{\n    \"a\": 1\n}") << 2 << 4 << false
        << QStringLiteral("{\n\n    \"a\": 1\n}") << 7;
    QTest::newRow("caret-inside-indent") << QStringLiteral("{\n    \"a\": 1\n}") << 4 << 4 << false
        << QStringLiteral("{\n\n    \"a\": 1\n}") << 7;
    // Mixed tab+spaces converge to the configured style instead of growing.
    QTest::newRow("mixed-to-spaces") << QStringLiteral("[\n\t  {") << 6 << 4 << false
        << QStringLiteral("[\n\t  {\n") + QString(10, ' ') << 17;
    QTest::newRow("mixed-to-tabs") << QStringLiteral("[\n  \t{") << 6 << 4 << true
        << QStringLiteral("[\n  \t{\n\t\t") << 9;
    // Blanks around the split are dropped; `{ ` still opens a level.
    QTest::newRow("opening-with-trailing-space") << QStringLiteral("\"o\": { ") << 7 << 4 << false
        << QStringLiteral("\"o\": {\n    ") << 11;
    QTest::newRow("trailing-blanks") << QStringLiteral("  \"a\": 1   ") << 11 << 2 << false
        << QStringLiteral("  \"a\": 1\n  ") << 11;
    QTest::newRow("leading-blanks-of-moved-text") << QStringLiteral("  [   1]") << 3 << 2 << false
        << QStringLiteral("  [\n    1]") << 8;
    // A closer moved to the next line aligns with the line of its opener.
    QTest::newRow("closer-aligns-with-opener") << QStringLiteral("{\n    \"a\": 1}") << 12 << 4 << false
        << QStringLiteral("{\n    \"a\": 1\n}") << 13;
    QTest::newRow("unmatched-closer") << QStringLiteral("    \"a\": 1]") << 10 << 4 << false
        << QStringLiteral("    \"a\": 1\n]") << 11;
}

void EditorTextTest::newlineInsertion()
{
    QFETCH(QString, text);
    QFETCH(int, position);
    QFETCH(int, width);
    QFETCH(bool, useTabs);
    QFETCH(QString, expected);
    QFETCH(int, cursor);
    const auto result = call("newlineEdit", {text, position, width, useTabs});
    QVERIFY2(!result.isError(), qPrintable(result.toString()));
    int actualCursor = -1;
    QCOMPARE(applied(text, result, position, &actualCursor), expected);
    QCOMPARE(actualCursor, cursor);
}

void EditorTextTest::tabAndGuides()
{
    const auto tab = [this](const QString &text, int position, int width, bool tabs, int *cursor) {
        return applied(text, call("tabEdit", {text, position, width, tabs}), position, cursor);
    };
    int cursor = -1;
    // After text: pad to the next stop at the caret.
    QCOMPARE(tab("abc", 3, 4, false, &cursor), QStringLiteral("abc "));
    QCOMPARE(tab("abcd", 4, 4, false, &cursor), QStringLiteral("abcd    "));
    QCOMPARE(tab("a\nb", 3, 4, false, &cursor), QStringLiteral("a\nb   "));
    QCOMPARE(tab("\t x", 3, 4, false, &cursor), QStringLiteral("\t x  "));
    QCOMPARE(tab("x", 1, 4, true, &cursor), QStringLiteral("x\t"));
    // In the indentation: the whole indent moves to the next stop, normalised.
    QCOMPARE(tab("\ntext", 0, 4, false, &cursor), QStringLiteral("    \ntext"));
    QCOMPARE(cursor, 4);
    QCOMPARE(tab("\t", 1, 4, false, &cursor), QStringLiteral("        "));
    QCOMPARE(tab("x\n \t", 4, 4, false, &cursor), QStringLiteral("x\n        "));
    QCOMPARE(tab("  value", 2, 4, true, &cursor), QStringLiteral("\tvalue"));
    QCOMPARE(cursor, 1);

    QCOMPARE(call("columnsBetween", {QStringLiteral(" \t   value"), 0, 5, 4}).toInt(), 7);
    QCOMPARE(call("indentString", {7, 4, false}).toString(), QStringLiteral("       "));
    QCOMPARE(call("indentString", {7, 4, true}).toString(), QStringLiteral("\t   "));
    QCOMPARE(call("firstContent", {QStringLiteral("x\n\t    value"), 2}).toInt(), 7);
    QCOMPARE(call("firstContent", {QStringLiteral("  \nnext"), 0}).toInt(), 2);

    // Guides: every stop strictly left of the text, from column 0; blank
    // lines continue the deeper neighbour.
    const QString nested = QStringLiteral("{\n    \"a\": {\n\n        \"b\": 1\n      \t\n    }\n}");
    const auto starts = call("lineStarts", {nested});
    QList<int> counts;
    for (int line = 0; line < starts.property("length").toInt(); ++line)
        counts << call("guideCount", {nested, starts, line, 4}).toInt();
    QCOMPARE(counts, QList<int>({0, 1, 2, 2, 2, 1, 0}));
    const QString offGrid = QStringLiteral(" \t   value");
    const auto offStarts = call("lineStarts", {offGrid});
    QCOMPARE(call("guideCount", {offGrid, offStarts, 0, 4}).toInt(), 2); // columns 0 and 4 < 7
}

void EditorTextTest::smartBackspace_data()
{
    QTest::addColumn<QString>("text");
    QTest::addColumn<int>("position");
    QTest::addColumn<bool>("useTabs");
    QTest::addColumn<QString>("expected");
    QTest::addColumn<int>("cursor");
    QTest::newRow("on-stop") << QStringLiteral("        x") << 8 << false << QStringLiteral("    x") << 4;
    QTest::newRow("off-grid-snaps") << QStringLiteral("      x") << 6 << false << QStringLiteral("    x") << 4;
    QTest::newRow("last-level") << QStringLiteral("    x") << 4 << false << QStringLiteral("x") << 0;
    QTest::newRow("mixed-to-tabs") << QStringLiteral("\t  x") << 3 << true << QStringLiteral("\tx") << 1;
    QTest::newRow("inside-indent") << QStringLiteral("  \n    ") << 7 << false << QStringLiteral("  \n") << 3;
    // Not in the indentation: plain Backspace (null edit).
    QTest::newRow("after-text") << QStringLiteral("a   ") << 4 << false << QStringLiteral("a   ") << 4;
    QTest::newRow("line-start") << QStringLiteral("a\n    b") << 2 << false << QStringLiteral("a\n    b") << 2;
}

void EditorTextTest::smartBackspace()
{
    QFETCH(QString, text);
    QFETCH(int, position);
    QFETCH(bool, useTabs);
    QFETCH(QString, expected);
    QFETCH(int, cursor);
    const auto result = call("backspaceEdit", {text, position, 4, useTabs});
    QVERIFY2(!result.isError(), qPrintable(result.toString()));
    int actualCursor = -1;
    QCOMPARE(applied(text, result, position, &actualCursor), expected);
    QCOMPARE(actualCursor, cursor);
}

void EditorTextTest::stickyIndentStops_data()
{
    QTest::addColumn<QString>("text");
    QTest::addColumn<int>("position");
    QTest::addColumn<bool>("forward");
    QTest::addColumn<int>("expected"); // -1: ordinary one-character move
    const QString eight = QStringLiteral("        x");
    QTest::newRow("left-stop") << eight << 8 << false << 4;
    QTest::newRow("left-to-start") << eight << 4 << false << 0;
    QTest::newRow("left-at-start") << eight << 0 << false << -1;
    QTest::newRow("right-stop") << eight << 0 << true << 4;
    QTest::newRow("right-to-text") << eight << 4 << true << 8;
    QTest::newRow("right-at-text") << eight << 8 << true << -1;
    const QString six = QStringLiteral("      x"); // off-grid: 6 columns
    QTest::newRow("off-grid-left") << six << 6 << false << 4;
    QTest::newRow("off-grid-right-stops-at-text") << six << 4 << true << 6;
    QTest::newRow("between-stops-left") << six << 5 << false << 4;
    QTest::newRow("between-stops-right") << six << 5 << true << 6;
    QTest::newRow("mixed-space-tab") << QStringLiteral(" \tx") << 2 << false << 0;
    QTest::newRow("second-line") << QStringLiteral("{\n    x") << 6 << false << 2;
    QTest::newRow("blank-line") << QStringLiteral("    ") << 4 << false << 0;
    QTest::newRow("after-text") << QStringLiteral("  ab") << 3 << false << -1;
}

void EditorTextTest::stickyIndentStops()
{
    QFETCH(QString, text);
    QFETCH(int, position);
    QFETCH(bool, forward);
    QFETCH(int, expected);
    const auto result = call("indentCaretMove", {text, position, 4, forward});
    QVERIFY2(!result.isError(), qPrintable(result.toString()));
    QCOMPARE(result.toInt(), expected);
}

void EditorTextTest::mouseSnapsToIndentStops_data()
{
    QTest::addColumn<QString>("text");
    QTest::addColumn<int>("position");
    QTest::addColumn<int>("expected");
    const QString eight = QStringLiteral("        x");
    QTest::newRow("near-left") << eight << 1 << 0;
    QTest::newRow("tie-goes-left") << eight << 2 << 0;
    QTest::newRow("near-right") << eight << 3 << 4;
    QTest::newRow("on-stop") << eight << 4 << 4;
    QTest::newRow("second-level-left") << eight << 5 << 4;
    QTest::newRow("second-tie") << eight << 6 << 4;
    QTest::newRow("near-text") << eight << 7 << 8;
    QTest::newRow("at-text") << eight << 8 << 8;
    QTest::newRow("line-start") << eight << 0 << 0;
    QTest::newRow("off-grid-towards-text") << QStringLiteral("      x") << 5 << 4;
    QTest::newRow("second-line") << QStringLiteral("{\n      x") << 3 << 2;
    QTest::newRow("after-text") << QStringLiteral("  ab") << 3 << 3;
    QTest::newRow("tabs-unchanged") << QStringLiteral("\t\tx") << 1 << 1;
}

void EditorTextTest::mouseSnapsToIndentStops()
{
    QFETCH(QString, text);
    QFETCH(int, position);
    QFETCH(int, expected);
    const auto result = call("snapToIndentStop", {text, position, 4});
    QVERIFY2(!result.isError(), qPrintable(result.toString()));
    QCOMPARE(result.toInt(), expected);
}

void EditorTextTest::closingBracket_data()
{
    QTest::addColumn<QString>("text");
    QTest::addColumn<int>("position");
    QTest::addColumn<QString>("closer");
    QTest::addColumn<bool>("useTabs");
    QTest::addColumn<QString>("expected"); // empty: no special edit (null)
    QTest::addColumn<int>("cursor");
    QTest::newRow("outdent-to-opener") << QStringLiteral("{\n    ") << 6 << QStringLiteral("}") << false
        << QStringLiteral("{\n}") << 3;
    QTest::newRow("nested-array") << QStringLiteral("  \"a\": [\n      ") << 15 << QStringLiteral("]") << false
        << QStringLiteral("  \"a\": [\n  ]") << 12;
    QTest::newRow("tabs") << QStringLiteral("\t{\n\t\t") << 5 << QStringLiteral("}") << true
        << QStringLiteral("\t{\n\t}") << 5;
    QTest::newRow("bracket-in-string-ignored") << QStringLiteral("{\"s\": \"{\",\n    ") << 15 << QStringLiteral("}") << false
        << QStringLiteral("{\"s\": \"{\",\n}") << 12;
    QTest::newRow("already-aligned") << QStringLiteral("{\n") << 2 << QStringLiteral("}") << false << QString() << 0;
    QTest::newRow("text-before-caret") << QStringLiteral("{\n    1") << 7 << QStringLiteral("}") << false << QString() << 0;
    QTest::newRow("unmatched") << QStringLiteral("    ") << 4 << QStringLiteral("]") << false << QString() << 0;
}

void EditorTextTest::closingBracket()
{
    QFETCH(QString, text);
    QFETCH(int, position);
    QFETCH(QString, closer);
    QFETCH(bool, useTabs);
    QFETCH(QString, expected);
    QFETCH(int, cursor);
    const auto result = call("closingBracketEdit", {text, position, closer, 4, useTabs});
    QVERIFY2(!result.isError(), qPrintable(result.toString()));
    if (expected.isEmpty()) {
        QVERIFY(result.isNull());
        return;
    }
    int actualCursor = -1;
    QCOMPARE(applied(text, result, position, &actualCursor), expected);
    QCOMPARE(actualCursor, cursor);
}
void EditorTextTest::blockIndentation_data()
{
    QTest::addColumn<QString>("text");
    QTest::addColumn<int>("start");
    QTest::addColumn<int>("end");
    QTest::addColumn<int>("width");
    QTest::addColumn<bool>("tabs");
    QTest::addColumn<bool>("backwards");
    QTest::addColumn<QString>("expected");
    QTest::addColumn<int>("expectedStart");
    QTest::addColumn<int>("expectedEnd");
    QTest::newRow("partial-lines") << QString("one\ntwo\nthree") << 1 << 6 << 2 << false << false
        << QString("  one\n  two\nthree") << 3 << 10;
    QTest::newRow("reversed") << QString("one\ntwo\nthree") << 6 << 1 << 2 << false << false
        << QString("  one\n  two\nthree") << 3 << 10;
    QTest::newRow("end-at-column-zero") << QString("one\ntwo") << 0 << 4 << 2 << false << false
        << QString("  one\ntwo") << 0 << 6;
    QTest::newRow("single-line") << QString("abc") << 1 << 2 << 4 << false << false
        << QString("    abc") << 5 << 6;
    // Empty and whitespace-only lines are not indented (no trailing blanks).
    QTest::newRow("empty-line") << QString("a\n\nb") << 0 << 4 << 2 << false << false
        << QString("  a\n\n  b") << 0 << 8;
    QTest::newRow("whitespace-only-line") << QString("a\n   \nb") << 0 << 7 << 2 << false << false
        << QString("  a\n   \n  b") << 0 << 11;
    QTest::newRow("whitespace-only-outdent") << QString("  \n  a") << 0 << 6 << 2 << false << true
        << QString("\na") << 0 << 2;
    // Indent/outdent snap to the grid and rewrite the indent in the set style.
    QTest::newRow("off-grid-indent") << QString("      x") << 0 << 7 << 4 << false << false
        << QString("        x") << 0 << 9;
    QTest::newRow("off-grid-outdent") << QString("      x") << 0 << 7 << 4 << false << true
        << QString("    x") << 0 << 5;
    QTest::newRow("normalize-to-tabs") << QString("    a\n  b") << 0 << 9 << 4 << true << false
        << QString("\t\ta\n\tb") << 0 << 6;
    QTest::newRow("trailing-newline") << QString("a\n") << 0 << 2 << 2 << false << false
        << QString("  a\n") << 0 << 4;
    QTest::newRow("tabs") << QString("a\nb") << 0 << 3 << 4 << true << false
        << QString("\ta\n\tb") << 0 << 5;
    QTest::newRow("unindent-spaces") << QString("    a\n  b") << 0 << 9 << 2 << false << true
        << QString("  a\nb") << 0 << 5;
    QTest::newRow("unindent-tabs") << QString("\ta\n\tb") << 0 << 5 << 4 << true << true
        << QString("a\nb") << 0 << 3;
    QTest::newRow("mixed-whitespace") << QString(" \tx\n\t  y") << 0 << 8 << 2 << false << true
        << QString("x\n  y") << 0 << 5;
    QTest::newRow("short-indent") << QString(" a\nb") << 0 << 4 << 4 << true << true
        << QString("a\nb") << 0 << 3;
    QTest::newRow("caret") << QString("    a") << 3 << 3 << 2 << false << true
        << QString("  a") << 1 << 1;
    QTest::newRow("selection-inside-indent") << QString("    a\n    b") << 1 << 8 << 2 << false << true
        << QString("  a\n  b") << 0 << 4;
    QTest::newRow("no-indent") << QString("a\nb") << 0 << 3 << 2 << false << true
        << QString("a\nb") << 0 << 3;
    QTest::newRow("empty-document") << QString() << 0 << 0 << 2 << false << true
        << QString() << 0 << 0;
    QTest::newRow("utf16") << QString::fromUtf8("ёж\n🙂x") << 1 << 5 << 2 << false << false
        << QString::fromUtf8("  ёж\n  🙂x") << 3 << 9;
}

void EditorTextTest::blockIndentation()
{
    QFETCH(QString, text);
    QFETCH(int, start);
    QFETCH(int, end);
    QFETCH(int, width);
    QFETCH(bool, tabs);
    QFETCH(bool, backwards);
    QFETCH(QString, expected);
    QFETCH(int, expectedStart);
    QFETCH(int, expectedEnd);
    const auto result = call("blockIndentEdit", {text, start, end, width, tabs, backwards});
    QVERIFY2(!result.isError(), qPrintable(result.toString()));
    QString actual = text;
    const int from = result.property("from").toInt();
    actual.replace(from, result.property("to").toInt() - from, result.property("text").toString());
    QCOMPARE(actual, expected);
    QCOMPARE(result.property("selectionStart").toInt(), expectedStart);
    QCOMPARE(result.property("selectionEnd").toInt(), expectedEnd);
    QCOMPARE(result.property("changed").toBool(), text != expected);
}
QTEST_GUILESS_MAIN(EditorTextTest)
