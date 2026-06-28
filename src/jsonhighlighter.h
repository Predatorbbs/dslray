#pragma once

#include <QColor>
#include <QObject>
#include <QPointer>
#include <QQuickTextDocument>
#include <QSyntaxHighlighter>
#include <QTextBlock>
#include <QTextCharFormat>

// Подсветка синтаксиса JSON для QTextDocument. Однопроходный лексер по строке:
// строки JSON не переносятся, поэтому корректно работать построчно безопасно.
class JsonSyntaxHighlighter : public QSyntaxHighlighter
{
    Q_OBJECT
public:
    explicit JsonSyntaxHighlighter(QTextDocument *parent = nullptr);

    // Задать цвета синтаксических групп (вызывает rehighlight снаружи).
    void setColors(const QColor &key, const QColor &str, const QColor &num,
                   const QColor &keyword, const QColor &punct);

protected:
    void highlightBlock(const QString &text) override;

private:
    QTextCharFormat m_keyFmt;     // "ключ":
    QTextCharFormat m_strFmt;     // строковые значения
    QTextCharFormat m_numFmt;     // числа
    QTextCharFormat m_keywordFmt; // true / false / null
    QTextCharFormat m_punctFmt;   // { } [ ] : ,
};

// QML-обёртка: вешает JSON-подсветку на документ TextArea и держит «висячий»
// отступ переноса — при word-wrap продолжение строки на экране выравнивается по
// уровню вложенности (через формат блока: leftMargin + отрицательный textIndent,
// который гасит сдвиг для первой визуальной строки). Текст в файле при этом
// остаётся неразрывной строкой — меняется только раскладка.
// Использование: JsonHighlighter { document: codeArea.textDocument; tabWidth: 2 }.
class JsonHighlighter : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QQuickTextDocument *document READ document WRITE setDocument NOTIFY documentChanged)
    // Ширина одного уровня отступа (в пробелах / колонках таба). Влияет на
    // глубину висячего отступа переноса.
    Q_PROPERTY(int tabWidth READ tabWidth WRITE setTabWidth NOTIFY tabWidthChanged)
    // Цвета синтаксических групп (биндятся из настроек редактора).
    Q_PROPERTY(QColor keyColor READ keyColor WRITE setKeyColor NOTIFY colorsChanged)
    Q_PROPERTY(QColor stringColor READ stringColor WRITE setStringColor NOTIFY colorsChanged)
    Q_PROPERTY(QColor numberColor READ numberColor WRITE setNumberColor NOTIFY colorsChanged)
    Q_PROPERTY(QColor keywordColor READ keywordColor WRITE setKeywordColor NOTIFY colorsChanged)
    Q_PROPERTY(QColor punctColor READ punctColor WRITE setPunctColor NOTIFY colorsChanged)
public:
    explicit JsonHighlighter(QObject *parent = nullptr);

    QQuickTextDocument *document() const { return m_document; }
    void setDocument(QQuickTextDocument *doc);

    int tabWidth() const { return m_tabWidth; }
    void setTabWidth(int width);

    QColor keyColor() const { return m_keyColor; }
    void setKeyColor(const QColor &c);
    QColor stringColor() const { return m_stringColor; }
    void setStringColor(const QColor &c);
    QColor numberColor() const { return m_numberColor; }
    void setNumberColor(const QColor &c);
    QColor keywordColor() const { return m_keywordColor; }
    void setKeywordColor(const QColor &c);
    QColor punctColor() const { return m_punctColor; }
    void setPunctColor(const QColor &c);

    // Пересчитать висячий отступ всех блоков — звать после смены размера шрифта
    // (меняется ширина пробела в пикселях).
    Q_INVOKABLE void refreshIndent();

signals:
    void documentChanged();
    void tabWidthChanged();
    void colorsChanged();

private:
    void attach();
    void applyHangingIndent(int fromPos, int toPos);
    void applyToBlock(const QTextBlock &block, qreal spaceWidth);
    void applyColors(); // протолкнуть текущие цвета в подсветчик + rehighlight

    QPointer<QQuickTextDocument> m_document;
    JsonSyntaxHighlighter       *m_highlighter = nullptr;
    int  m_tabWidth = 2;
    bool m_applyingIndent = false; // защита от рекурсии при правке формата блока

    // Цвета по умолчанию совпадают с прежними хардкод-значениями подсветки.
    QColor m_keyColor     {QStringLiteral("#2563eb")};
    QColor m_stringColor  {QStringLiteral("#2a9d5c")};
    QColor m_numberColor  {QStringLiteral("#b5651d")};
    QColor m_keywordColor {QStringLiteral("#8b5cf6")};
    QColor m_punctColor   {QStringLiteral("#7a818f")};
};
