#include "jsonhighlighter.h"

#include <QFontMetricsF>
#include <QQuickTextDocument>
#include <QTextBlock>
#include <QTextBlockFormat>
#include <QTextCursor>
#include <QTextDocument>


// ── JsonSyntaxHighlighter ───────────────────────────────────────────────

JsonSyntaxHighlighter::JsonSyntaxHighlighter(QTextDocument *parent)
    : QSyntaxHighlighter(parent)
{
    m_keyFmt.setForeground(QColor("#2563eb"));     // ключи — синий
    m_keyFmt.setFontWeight(QFont::DemiBold);
    m_strFmt.setForeground(QColor("#2a9d5c"));     // строки — зелёный
    m_numFmt.setForeground(QColor("#b5651d"));     // числа — охра
    m_keywordFmt.setForeground(QColor("#8b5cf6")); // true/false/null — фиолетовый
    m_keywordFmt.setFontWeight(QFont::DemiBold);
    m_punctFmt.setForeground(QColor("#7a818f"));   // пунктуация — приглушённый
}

void JsonSyntaxHighlighter::setColors(const QColor &key, const QColor &str, const QColor &num,
                                      const QColor &keyword, const QColor &punct)
{
    m_keyFmt.setForeground(key);
    m_strFmt.setForeground(str);
    m_numFmt.setForeground(num);
    m_keywordFmt.setForeground(keyword);
    m_punctFmt.setForeground(punct);
}

void JsonSyntaxHighlighter::highlightBlock(const QString &text)
{
    const int n = text.length();
    int i = 0;
    while (i < n) {
        const QChar c = text.at(i);

        if (c == QLatin1Char('"')) {
            // Строка от " до незаэкранированной ".
            int j = i + 1;
            while (j < n) {
                if (text.at(j) == QLatin1Char('\\'))
                    j += 2;
                else if (text.at(j) == QLatin1Char('"'))
                    break;
                else
                    ++j;
            }
            const int end = (j < n) ? j : n - 1;
            const int len = end - i + 1;

            // Ключ, если за строкой (через пробелы) идёт двоеточие.
            int k = end + 1;
            while (k < n && text.at(k).isSpace())
                ++k;
            const bool isKey = (k < n && text.at(k) == QLatin1Char(':'));

            setFormat(i, len, isKey ? m_keyFmt : m_strFmt);
            i = end + 1;
            continue;
        }

        if (c.isDigit() || (c == QLatin1Char('-') && i + 1 < n && text.at(i + 1).isDigit())) {
            int j = i + 1;
            while (j < n) {
                const QChar d = text.at(j);
                if (d.isDigit() || d == QLatin1Char('.') || d == QLatin1Char('e')
                    || d == QLatin1Char('E') || d == QLatin1Char('+') || d == QLatin1Char('-'))
                    ++j;
                else
                    break;
            }
            setFormat(i, j - i, m_numFmt);
            i = j;
            continue;
        }

        // Ключевые слова true / false / null.
        static const QString kw[] = { QStringLiteral("true"),
                                      QStringLiteral("false"),
                                      QStringLiteral("null") };
        bool matched = false;
        for (const QString &w : kw) {
            if (text.mid(i, w.length()) == w) {
                const QChar before = (i > 0) ? text.at(i - 1) : QChar();
                const QChar after  = (i + w.length() < n) ? text.at(i + w.length()) : QChar();
                const bool boundaryBefore = (i == 0) || !(before.isLetterOrNumber());
                const bool boundaryAfter  = (i + w.length() >= n) || !(after.isLetterOrNumber());
                if (boundaryBefore && boundaryAfter) {
                    setFormat(i, w.length(), m_keywordFmt);
                    i += w.length();
                    matched = true;
                    break;
                }
            }
        }
        if (matched)
            continue;

        if (c == QLatin1Char('{') || c == QLatin1Char('}') || c == QLatin1Char('[')
            || c == QLatin1Char(']') || c == QLatin1Char(':') || c == QLatin1Char(',')) {
            setFormat(i, 1, m_punctFmt);
            ++i;
            continue;
        }

        ++i;
    }
}


// ── JsonHighlighter (QML-обёртка) ────────────────────────────────────────

JsonHighlighter::JsonHighlighter(QObject *parent)
    : QObject(parent)
{
}

void JsonHighlighter::setDocument(QQuickTextDocument *doc)
{
    if (m_document == doc)
        return;
    if (m_document && m_document->textDocument())
        disconnect(m_document->textDocument(), nullptr, this, nullptr);
    m_document = doc;
    attach();
    emit documentChanged();
}

void JsonHighlighter::setTabWidth(int width)
{
    const int clamped = width < 1 ? 1 : width;
    if (m_tabWidth == clamped)
        return;
    m_tabWidth = clamped;
    emit tabWidthChanged();
    refreshIndent();
}

void JsonHighlighter::setKeyColor(const QColor &c)
{
    if (m_keyColor == c) return;
    m_keyColor = c;
    applyColors();
    emit colorsChanged();
}

void JsonHighlighter::setStringColor(const QColor &c)
{
    if (m_stringColor == c) return;
    m_stringColor = c;
    applyColors();
    emit colorsChanged();
}

void JsonHighlighter::setNumberColor(const QColor &c)
{
    if (m_numberColor == c) return;
    m_numberColor = c;
    applyColors();
    emit colorsChanged();
}

void JsonHighlighter::setKeywordColor(const QColor &c)
{
    if (m_keywordColor == c) return;
    m_keywordColor = c;
    applyColors();
    emit colorsChanged();
}

void JsonHighlighter::setPunctColor(const QColor &c)
{
    if (m_punctColor == c) return;
    m_punctColor = c;
    applyColors();
    emit colorsChanged();
}

void JsonHighlighter::applyColors()
{
    if (!m_highlighter)
        return;
    m_highlighter->setColors(m_keyColor, m_stringColor, m_numberColor,
                             m_keywordColor, m_punctColor);
    m_highlighter->rehighlight();
}

void JsonHighlighter::attach()
{
    delete m_highlighter;
    m_highlighter = nullptr;
    if (m_document && m_document->textDocument()) {
        QTextDocument *d = m_document->textDocument();
        m_highlighter = new JsonSyntaxHighlighter(d);
        applyColors();
        // На правки документа — переустановить висячий отступ затронутых блоков.
        connect(d, &QTextDocument::contentsChange, this,
                [this](int position, int charsRemoved, int charsAdded) {
                    Q_UNUSED(charsRemoved);
                    if (m_applyingIndent)
                        return;
                    applyHangingIndent(position, position + charsAdded);
                });
        refreshIndent();
    }
}

void JsonHighlighter::refreshIndent()
{
    if (m_document && m_document->textDocument())
        applyHangingIndent(0, m_document->textDocument()->characterCount());
}

// Переустановить висячий отступ для блоков, попадающих в диапазон [fromPos..toPos].
void JsonHighlighter::applyHangingIndent(int fromPos, int toPos)
{
    if (m_applyingIndent)
        return;
    QTextDocument *d = m_document ? m_document->textDocument() : nullptr;
    if (!d)
        return;
    const QFontMetricsF fm(d->defaultFont());
    const qreal spaceWidth = fm.horizontalAdvance(QLatin1Char(' '));
    if (spaceWidth <= 0.0)
        return;

    m_applyingIndent = true;
    QTextBlock block = d->findBlock(qMax(0, fromPos));
    const QTextBlock last = d->findBlock(qMax(fromPos, toPos));
    while (block.isValid()) {
        applyToBlock(block, spaceWidth);
        if (block == last)
            break;
        block = block.next();
    }
    m_applyingIndent = false;
}

void JsonHighlighter::applyToBlock(const QTextBlock &block, qreal spaceWidth)
{
    const QString text = block.text();
    int cols = 0;
    for (int i = 0; i < text.size(); ++i) {
        const QChar c = text.at(i);
        if (c == QLatin1Char(' '))
            ++cols;
        else if (c == QLatin1Char('\t'))
            cols += m_tabWidth;
        else
            break;
    }
    // Продолжение строки висит ровно на уровне собственного отступа строки.
    const qreal margin = cols * spaceWidth;
    QTextBlockFormat fmt = block.blockFormat();
    // Уже выставлено — выходим (и заодно рвём возможную рекурсию).
    // (Сравниваем вручную: qFuzzyCompare ненадёжен при нулевых значениях.)
    if (qAbs(fmt.leftMargin() - margin) < 0.01 && qAbs(fmt.textIndent() + margin) < 0.01)
        return;
    fmt.setLeftMargin(margin);
    fmt.setTextIndent(-margin);
    QTextCursor cur(block);
    cur.setBlockFormat(fmt);
}
