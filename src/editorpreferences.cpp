#include "editorpreferences.h"

#include <QSettings>

EditorPreferences::EditorPreferences(QObject *parent)
    : QObject(parent)
{
    QSettings s;
    m_wordWrap = s.value(QStringLiteral("editor/wordWrap"), false).toBool();
    m_codeFontSize = qBound(14, s.value(QStringLiteral("editor/codeFontSize"), 14).toInt(), 32);
    m_indentWidth = qBound(1, s.value(QStringLiteral("editor/indentWidth"), 2).toInt(), 8);
    m_indentUseTabs = s.value(QStringLiteral("editor/indentUseTabs"), false).toBool();

    m_themeId = s.value(QStringLiteral("appearance/theme"), QStringLiteral("light")).toString();
    if (m_themeId != QLatin1String("dark") && m_themeId != QLatin1String("light"))
        m_themeId = QStringLiteral("light");
    m_userName = s.value(QStringLiteral("user/name"), QStringLiteral("designer")).toString();
    m_userEmail = s.value(QStringLiteral("user/email")).toString();
    m_avatarPath = s.value(QStringLiteral("user/avatar")).toString();

    const auto readColor = [&s](const QString &key, const QColor &def) {
        const QColor c(s.value(key, def.name()).toString());
        return c.isValid() ? c : def;
    };
    m_colorKey     = readColor(QStringLiteral("editor/colorKey"),     m_colorKey);
    m_colorString  = readColor(QStringLiteral("editor/colorString"),  m_colorString);
    m_colorNumber  = readColor(QStringLiteral("editor/colorNumber"),  m_colorNumber);
    m_colorKeyword = readColor(QStringLiteral("editor/colorKeyword"), m_colorKeyword);
    m_colorPunct   = readColor(QStringLiteral("editor/colorPunct"),   m_colorPunct);
}

void EditorPreferences::setThemeId(const QString &id)
{
    const QString v = (id == QLatin1String("dark")) ? QStringLiteral("dark") : QStringLiteral("light");
    if (m_themeId == v)
        return;
    m_themeId = v;
    QSettings().setValue(QStringLiteral("appearance/theme"), v);
    emit themeIdChanged();
}

void EditorPreferences::setUserName(const QString &name)
{
    if (m_userName == name)
        return;
    m_userName = name;
    QSettings().setValue(QStringLiteral("user/name"), name);
    emit userChanged();
}

void EditorPreferences::setUserEmail(const QString &email)
{
    if (m_userEmail == email)
        return;
    m_userEmail = email;
    QSettings().setValue(QStringLiteral("user/email"), email);
    emit userChanged();
}

void EditorPreferences::setAvatarPath(const QString &path)
{
    if (m_avatarPath == path)
        return;
    m_avatarPath = path;
    QSettings().setValue(QStringLiteral("user/avatar"), path);
    emit userChanged();
}

void EditorPreferences::setColorKey(const QColor &c)
{
    if (!c.isValid() || m_colorKey == c) return;
    m_colorKey = c;
    QSettings().setValue(QStringLiteral("editor/colorKey"), c.name());
    emit colorsChanged();
}

void EditorPreferences::setColorString(const QColor &c)
{
    if (!c.isValid() || m_colorString == c) return;
    m_colorString = c;
    QSettings().setValue(QStringLiteral("editor/colorString"), c.name());
    emit colorsChanged();
}

void EditorPreferences::setColorNumber(const QColor &c)
{
    if (!c.isValid() || m_colorNumber == c) return;
    m_colorNumber = c;
    QSettings().setValue(QStringLiteral("editor/colorNumber"), c.name());
    emit colorsChanged();
}

void EditorPreferences::setColorKeyword(const QColor &c)
{
    if (!c.isValid() || m_colorKeyword == c) return;
    m_colorKeyword = c;
    QSettings().setValue(QStringLiteral("editor/colorKeyword"), c.name());
    emit colorsChanged();
}

void EditorPreferences::setColorPunct(const QColor &c)
{
    if (!c.isValid() || m_colorPunct == c) return;
    m_colorPunct = c;
    QSettings().setValue(QStringLiteral("editor/colorPunct"), c.name());
    emit colorsChanged();
}

void EditorPreferences::resetColors()
{
    m_colorKey     = QColor(QStringLiteral("#2563eb"));
    m_colorString  = QColor(QStringLiteral("#2a9d5c"));
    m_colorNumber  = QColor(QStringLiteral("#b5651d"));
    m_colorKeyword = QColor(QStringLiteral("#8b5cf6"));
    m_colorPunct   = QColor(QStringLiteral("#7a818f"));
    QSettings s;
    s.setValue(QStringLiteral("editor/colorKey"),     m_colorKey.name());
    s.setValue(QStringLiteral("editor/colorString"),  m_colorString.name());
    s.setValue(QStringLiteral("editor/colorNumber"),  m_colorNumber.name());
    s.setValue(QStringLiteral("editor/colorKeyword"), m_colorKeyword.name());
    s.setValue(QStringLiteral("editor/colorPunct"),   m_colorPunct.name());
    emit colorsChanged();
}

void EditorPreferences::setIndentWidth(int width)
{
    const int clamped = qBound(1, width, 8);
    if (m_indentWidth == clamped)
        return;
    m_indentWidth = clamped;
    QSettings().setValue(QStringLiteral("editor/indentWidth"), clamped);
    emit indentWidthChanged();
}

void EditorPreferences::setIndentUseTabs(bool on)
{
    if (m_indentUseTabs == on)
        return;
    m_indentUseTabs = on;
    QSettings().setValue(QStringLiteral("editor/indentUseTabs"), on);
    emit indentUseTabsChanged();
}

void EditorPreferences::setWordWrap(bool on)
{
    if (m_wordWrap == on)
        return;
    m_wordWrap = on;
    QSettings().setValue(QStringLiteral("editor/wordWrap"), on);
    emit wordWrapChanged();
}

void EditorPreferences::setCodeFontSize(int size)
{
    const int clamped = qBound(14, size, 32);
    if (m_codeFontSize == clamped)
        return;
    m_codeFontSize = clamped;
    QSettings().setValue(QStringLiteral("editor/codeFontSize"), clamped);
    emit codeFontSizeChanged();
}
