#pragma once

#include <QColor>
#include <QObject>
#include <QString>

// Preferences are independent of open documents; QSettings keys remain unchanged.
class EditorPreferences : public QObject
{
    Q_OBJECT
    // Перенос текста по строкам в редакторе кода. Хранится в QSettings.
    Q_PROPERTY(bool wordWrap READ wordWrap WRITE setWordWrap NOTIFY wordWrapChanged)
    // Размер шрифта кода (14…32). Хранится в QSettings.
    Q_PROPERTY(int codeFontSize READ codeFontSize WRITE setCodeFontSize NOTIFY codeFontSizeChanged)
    // Ширина отступа в пробелах / визуальная ширина таба (1…8). Хранится в QSettings.
    Q_PROPERTY(int indentWidth READ indentWidth WRITE setIndentWidth NOTIFY indentWidthChanged)
    // true — отступы табами ('\t'), false — пробелами. Хранится в QSettings.
    Q_PROPERTY(bool indentUseTabs READ indentUseTabs WRITE setIndentUseTabs NOTIFY indentUseTabsChanged)
    // Тема оформления: "light" | "dark". Хранится в QSettings.
    Q_PROPERTY(QString themeId READ themeId WRITE setThemeId NOTIFY themeIdChanged)
    // Профиль пользователя (имя/почта/аватар) — для статус-бара и раздела «Пользователь».
    Q_PROPERTY(QString userName READ userName WRITE setUserName NOTIFY userChanged)
    Q_PROPERTY(QString userEmail READ userEmail WRITE setUserEmail NOTIFY userChanged)
    Q_PROPERTY(QString avatarPath READ avatarPath WRITE setAvatarPath NOTIFY userChanged)
    // Цвета подсветки JSON (внешний вид кода). Хранятся в QSettings как hex-имена.
    Q_PROPERTY(QColor colorKey READ colorKey WRITE setColorKey NOTIFY colorsChanged)
    Q_PROPERTY(QColor colorString READ colorString WRITE setColorString NOTIFY colorsChanged)
    Q_PROPERTY(QColor colorNumber READ colorNumber WRITE setColorNumber NOTIFY colorsChanged)
    Q_PROPERTY(QColor colorKeyword READ colorKeyword WRITE setColorKeyword NOTIFY colorsChanged)
    Q_PROPERTY(QColor colorPunct READ colorPunct WRITE setColorPunct NOTIFY colorsChanged)

public:
    explicit EditorPreferences(QObject *parent = nullptr);

    bool wordWrap() const { return m_wordWrap; }
    void setWordWrap(bool on);
    int codeFontSize() const { return m_codeFontSize; }
    void setCodeFontSize(int size);
    int indentWidth() const { return m_indentWidth; }
    void setIndentWidth(int width);
    bool indentUseTabs() const { return m_indentUseTabs; }
    void setIndentUseTabs(bool on);

    QString themeId() const { return m_themeId; }
    void setThemeId(const QString &id);
    QString userName() const { return m_userName; }
    void setUserName(const QString &name);
    QString userEmail() const { return m_userEmail; }
    void setUserEmail(const QString &email);
    QString avatarPath() const { return m_avatarPath; }
    void setAvatarPath(const QString &path);

    QColor colorKey() const { return m_colorKey; }
    void setColorKey(const QColor &c);
    QColor colorString() const { return m_colorString; }
    void setColorString(const QColor &c);
    QColor colorNumber() const { return m_colorNumber; }
    void setColorNumber(const QColor &c);
    QColor colorKeyword() const { return m_colorKeyword; }
    void setColorKeyword(const QColor &c);
    QColor colorPunct() const { return m_colorPunct; }
    void setColorPunct(const QColor &c);
    // Вернуть цвета подсветки к значениям по умолчанию.
    Q_INVOKABLE void resetColors();

signals:
    void wordWrapChanged();
    void codeFontSizeChanged();
    void indentWidthChanged();
    void indentUseTabsChanged();
    void colorsChanged();
    void themeIdChanged();
    void userChanged();

private:
    bool m_wordWrap = false;
    int  m_codeFontSize = 14;
    int  m_indentWidth = 2;
    bool m_indentUseTabs = false;

    QString m_themeId = QStringLiteral("light");
    QString m_userName = QStringLiteral("designer");
    QString m_userEmail;
    QString m_avatarPath;

    // Цвета подсветки (по умолчанию — как в JsonSyntaxHighlighter).
    QColor m_colorKey     {QStringLiteral("#2563eb")};
    QColor m_colorString  {QStringLiteral("#2a9d5c")};
    QColor m_colorNumber  {QStringLiteral("#b5651d")};
    QColor m_colorKeyword {QStringLiteral("#8b5cf6")};
    QColor m_colorPunct   {QStringLiteral("#7a818f")};
};
