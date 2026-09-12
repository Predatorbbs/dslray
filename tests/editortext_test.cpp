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

void EditorTextTest::newlineInsertion_data()
{
    QTest::addColumn<QString>("text");
    QTest::addColumn<int>("position");
    QTest::addColumn<bool>("useTabs");
    QTest::addColumn<QString>("insertion");
    QTest::addColumn<int>("cursor");
    QTest::newRow("pair") << QStringLiteral("  {}") << 3 << false << QStringLiteral("\n    \n  ") << 8;
    QTest::newRow("tab-pair") << QStringLiteral("\t[]") << 2 << true << QStringLiteral("\n\t\t\n\t") << 5;
    QTest::newRow("opening") << QStringLiteral("  [") << 3 << false << QStringLiteral("\n    ") << 8;
    QTest::newRow("plain") << QStringLiteral("  value") << 7 << false << QStringLiteral("\n  ") << 10;
    QTest::newRow("start-before-newline") << QStringLiteral("\n  next") << 0 << false << QStringLiteral("\n") << 1;
    QTest::newRow("empty") << QString() << 0 << false << QStringLiteral("\n") << 1;
}

void EditorTextTest::newlineInsertion()
{
    QFETCH(QString, text);
    QFETCH(int, position);
    QFETCH(bool, useTabs);
    QFETCH(QString, insertion);
    QFETCH(int, cursor);
    const auto result = call("newlineEdit", {text, position, 2, useTabs});
    QVERIFY(!result.isError());
    QCOMPARE(result.property("text").toString(), insertion);
    QCOMPARE(result.property("cursor").toInt(), cursor);
}

void EditorTextTest::tabAndGuides()
{
    QCOMPARE(call("tabText", {QStringLiteral("abc"), 3, 4, false}).toString(), QStringLiteral(" "));
    QCOMPARE(call("tabText", {QStringLiteral("abcd"), 4, 4, false}).toString(), QStringLiteral("    "));
    QCOMPARE(call("tabText", {QStringLiteral("\ntext"), 0, 4, false}).toString(), QStringLiteral("    "));
    QCOMPARE(call("tabText", {QStringLiteral("a\nb"), 3, 4, false}).toString(), QStringLiteral("   "));
    QCOMPARE(call("tabText", {QStringLiteral("x"), 1, 4, true}).toString(), QStringLiteral("\t"));
    QCOMPARE(call("indentStops", {QStringLiteral(" \t  value"), 0, 4}).toInt(), 1);
    QCOMPARE(call("indentStops", {QStringLiteral("x\n\t    value"), 2, 4}).toInt(), 2);
    QCOMPARE(call("firstContent", {QStringLiteral("x\n\t    value"), 2}).toInt(), 7);
    QCOMPARE(call("firstContent", {QStringLiteral("  \nnext"), 0}).toInt(), 2);
}
QTEST_GUILESS_MAIN(EditorTextTest)
