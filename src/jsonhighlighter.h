#pragma once

#include <QObject>
#include <QPointer>
#include <QQuickTextDocument>
#include <QSyntaxHighlighter>
#include <QTextCharFormat>

// Подсветка синтаксиса JSON для QTextDocument. Однопроходный лексер по строке:
// строки JSON не переносятся, поэтому корректно работать построчно безопасно.
class JsonSyntaxHighlighter : public QSyntaxHighlighter
{
    Q_OBJECT
public:
    explicit JsonSyntaxHighlighter(QTextDocument *parent = nullptr);

protected:
    void highlightBlock(const QString &text) override;

private:
    QTextCharFormat m_keyFmt;     // "ключ":
    QTextCharFormat m_strFmt;     // строковые значения
    QTextCharFormat m_numFmt;     // числа
    QTextCharFormat m_keywordFmt; // true / false / null
    QTextCharFormat m_punctFmt;   // { } [ ] : ,
};

// QML-обёртка: вешает JSON-подсветку на документ TextArea.
// Использование: JsonHighlighter { document: codeArea.textDocument }.
class JsonHighlighter : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QQuickTextDocument *document READ document WRITE setDocument NOTIFY documentChanged)
public:
    explicit JsonHighlighter(QObject *parent = nullptr);

    QQuickTextDocument *document() const { return m_document; }
    void setDocument(QQuickTextDocument *doc);

signals:
    void documentChanged();

private:
    void attach();

    QPointer<QQuickTextDocument> m_document;
    JsonSyntaxHighlighter       *m_highlighter = nullptr;
};
