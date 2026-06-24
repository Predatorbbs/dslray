#include "jsonhighlighter.h"

#include <QQuickTextDocument>
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
    m_document = doc;
    attach();
    emit documentChanged();
}

void JsonHighlighter::attach()
{
    delete m_highlighter;
    m_highlighter = nullptr;
    if (m_document && m_document->textDocument())
        m_highlighter = new JsonSyntaxHighlighter(m_document->textDocument());
}
