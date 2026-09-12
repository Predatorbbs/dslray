#include "jsonhighlighter.h"

#include <QCoreApplication>
#include <QQmlComponent>
#include <QQmlEngine>
#include <QQuickTextDocument>
#include <QTextBlock>
#include <QTextBlockFormat>
#include <QTextDocument>
#include <QTextLayout>
#include <QtTest>
#include <memory>

namespace {

QColor foregroundAt(const QTextDocument &document, int position)
{
    const QTextBlock block = document.findBlock(position);
    const int offset = position - block.position();
    if (const QTextLayout *layout = block.layout()) {
        for (const QTextLayout::FormatRange &range : layout->formats()) {
            if (offset >= range.start && offset < range.start + range.length)
                return range.format.foreground().color();
        }
    }
    return {};
}

std::unique_ptr<QObject> createTextEdit(QQmlEngine &engine)
{
    QQmlComponent component(&engine);
    component.setData("import QtQuick\nTextEdit {}", QUrl());
    return std::unique_ptr<QObject>(component.create());
}

QQuickTextDocument *quickDocument(QObject *textEdit)
{
    return textEdit->property("textDocument").value<QQuickTextDocument *>();
}

} // namespace

class JsonHighlighterTest : public QObject
{
    Q_OBJECT

private slots:
    void formatsJsonTokensAndEscapedStrings();
    void keywordsRespectBoundaries();
    void switchingDocumentsRemovesOldHighlighter();
    void documentCanBeDestroyedBeforeWrapper();
    void wrapperCanBeDestroyedBeforeDocument();
    void detachingCancelsPendingIndent();
};

void JsonHighlighterTest::formatsJsonTokensAndEscapedStrings()
{
    QTextDocument document;
    JsonSyntaxHighlighter highlighter(&document);
    const QString text = QStringLiteral(
        R"({"elementName": "true \"quoted\"", "enabled": true, "empty": null, "disabled": false, "value": -1.25e+2})");
    document.setPlainText(text);
    highlighter.rehighlight();

    QCOMPARE(foregroundAt(document, text.indexOf(QStringLiteral("elementName"))), QColor("#2563eb"));
    QCOMPARE(foregroundAt(document, text.indexOf(QStringLiteral("true"))), QColor("#2a9d5c"));
    QCOMPARE(foregroundAt(document, text.indexOf(QStringLiteral("quoted"))), QColor("#2a9d5c"));
    QCOMPARE(foregroundAt(document, text.indexOf(QStringLiteral("true,"))), QColor("#8b5cf6"));
    QCOMPARE(foregroundAt(document, text.indexOf(QStringLiteral("null"))), QColor("#8b5cf6"));
    QCOMPARE(foregroundAt(document, text.indexOf(QStringLiteral("false"))), QColor("#8b5cf6"));
    QCOMPARE(foregroundAt(document, text.indexOf(QStringLiteral("-1.25e+2"))), QColor("#b5651d"));
    QCOMPARE(foregroundAt(document, 0), QColor("#7a818f"));

    highlighter.setColors(Qt::red, Qt::green, Qt::blue, Qt::magenta, Qt::cyan);
    highlighter.rehighlight();
    QCOMPARE(foregroundAt(document, text.indexOf(QStringLiteral("elementName"))), QColor(Qt::red));
    QCOMPARE(foregroundAt(document, text.indexOf(QStringLiteral("quoted"))), QColor(Qt::green));
    QCOMPARE(foregroundAt(document, text.indexOf(QStringLiteral("true,"))), QColor(Qt::magenta));
}

void JsonHighlighterTest::keywordsRespectBoundaries()
{
    QTextDocument document;
    JsonSyntaxHighlighter highlighter(&document);
    const QString text = QStringLiteral("true truex xfalse null0 null false n");
    document.setPlainText(text);
    highlighter.rehighlight();

    QCOMPARE(foregroundAt(document, 0), QColor("#8b5cf6"));
    QVERIFY(!foregroundAt(document, text.indexOf(QStringLiteral("truex"))).isValid());
    QVERIFY(!foregroundAt(document, text.indexOf(QStringLiteral("xfalse")) + 1).isValid());
    QVERIFY(!foregroundAt(document, text.indexOf(QStringLiteral("null0"))).isValid());
    QCOMPARE(foregroundAt(document, text.lastIndexOf(QStringLiteral("null"))), QColor("#8b5cf6"));
    QCOMPARE(foregroundAt(document, text.lastIndexOf(QStringLiteral("false"))), QColor("#8b5cf6"));
    QVERIFY(!foregroundAt(document, text.size() - 1).isValid());
}

void JsonHighlighterTest::switchingDocumentsRemovesOldHighlighter()
{
    QQmlEngine engine;
    auto firstEdit = createTextEdit(engine);
    auto secondEdit = createTextEdit(engine);
    QVERIFY(firstEdit);
    QVERIFY(secondEdit);
    auto *first = quickDocument(firstEdit.get());
    auto *second = quickDocument(secondEdit.get());
    QVERIFY(first);
    QVERIFY(second);

    JsonHighlighter wrapper;
    wrapper.setDocument(first);
    QPointer<JsonSyntaxHighlighter> oldHighlighter =
        first->textDocument()->findChild<JsonSyntaxHighlighter *>();
    QVERIFY(oldHighlighter);
    wrapper.setDocument(second);
    QVERIFY(oldHighlighter.isNull());
    QCOMPARE(wrapper.document(), second);
    QVERIFY(!first->textDocument()->findChild<JsonSyntaxHighlighter *>());

    second->textDocument()->setPlainText(QStringLiteral("true"));
    wrapper.setKeywordColor(Qt::red);
    auto *current = second->textDocument()->findChild<JsonSyntaxHighlighter *>();
    QVERIFY(current);
    current->rehighlight();
    QCOMPARE(foregroundAt(*second->textDocument(), 0), QColor(Qt::red));
}

void JsonHighlighterTest::documentCanBeDestroyedBeforeWrapper()
{
    QQmlEngine engine;
    JsonHighlighter wrapper;
    auto firstEdit = createTextEdit(engine);
    QVERIFY(firstEdit);
    auto *first = quickDocument(firstEdit.get());
    QVERIFY(first);
    first->textDocument()->setPlainText(QStringLiteral("  {}"));
    wrapper.setDocument(first);
    QPointer<QTextDocument> firstText = first->textDocument();
    QPointer<JsonSyntaxHighlighter> firstHighlighter =
        firstText->findChild<JsonSyntaxHighlighter *>();
    QVERIFY(firstHighlighter);

    firstEdit.reset();
    QVERIFY(firstText.isNull());
    QVERIFY(firstHighlighter.isNull());
    QVERIFY(!wrapper.document());
    wrapper.setKeywordColor(Qt::red);

    auto secondEdit = createTextEdit(engine);
    QVERIFY(secondEdit);
    auto *second = quickDocument(secondEdit.get());
    QVERIFY(second);
    wrapper.setDocument(second);
    QVERIFY(second->textDocument()->findChild<JsonSyntaxHighlighter *>());
    QCoreApplication::processEvents();
    QCOMPARE(wrapper.document(), second);
}

void JsonHighlighterTest::wrapperCanBeDestroyedBeforeDocument()
{
    QQmlEngine engine;
    auto edit = createTextEdit(engine);
    QVERIFY(edit);
    auto *document = quickDocument(edit.get());
    QVERIFY(document);
    QPointer<JsonSyntaxHighlighter> highlighter;
    {
        JsonHighlighter wrapper;
        wrapper.setDocument(document);
        highlighter = document->textDocument()->findChild<JsonSyntaxHighlighter *>();
        QVERIFY(highlighter);
    }
    QVERIFY(highlighter.isNull());
    document->textDocument()->setPlainText(QStringLiteral("  null"));
    QCoreApplication::processEvents();
    QCOMPARE(document->textDocument()->toPlainText(), QStringLiteral("  null"));
}

void JsonHighlighterTest::detachingCancelsPendingIndent()
{
    QQmlEngine engine;
    auto edit = createTextEdit(engine);
    QVERIFY(edit);
    auto *document = quickDocument(edit.get());
    QVERIFY(document);
    document->textDocument()->setPlainText(QStringLiteral("    {}"));
    JsonHighlighter wrapper;
    wrapper.setDocument(document);
    wrapper.setDocument(nullptr);
    QCoreApplication::processEvents();

    QVERIFY(!document->textDocument()->findChild<JsonSyntaxHighlighter *>());
    QCOMPARE(document->textDocument()->firstBlock().blockFormat().leftMargin(), 0.0);
}

QTEST_MAIN(JsonHighlighterTest)
#include "jsonhighlighter_test.moc"
