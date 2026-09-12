#include "editorpreferences.h"
#include <QSettings>
#include <QSignalSpy>
#include <QTemporaryDir>
#include <QTest>

class EditorPreferencesTest : public QObject
{
    Q_OBJECT
    QTemporaryDir m_settings;

private slots:
    void initTestCase()
    {
        QVERIFY(m_settings.isValid());
        QCoreApplication::setOrganizationName("DSLRayTests");
        QCoreApplication::setApplicationName("preferences");
        QSettings::setDefaultFormat(QSettings::IniFormat);
        QSettings::setPath(QSettings::IniFormat, QSettings::UserScope, m_settings.path());
    }
    void init() { QSettings().clear(); }
    void readsExistingKeysAndClampsInvalidValues()
    {
        QSettings settings;
        settings.setValue("editor/wordWrap", true);
        settings.setValue("editor/codeFontSize", 500);
        settings.setValue("editor/indentWidth", 0);
        settings.setValue("appearance/theme", "unknown");
        settings.setValue("user/name", "Existing user");
        settings.setValue("editor/colorKey", "#123456");
        settings.setValue("editor/colorString", "bad color");
        EditorPreferences preferences;
        QVERIFY(preferences.wordWrap());
        QCOMPARE(preferences.codeFontSize(), 32);
        QCOMPARE(preferences.indentWidth(), 1);
        QCOMPARE(preferences.themeId(), QString("light"));
        QCOMPARE(preferences.userName(), QString("Existing user"));
        QCOMPARE(preferences.colorKey(), QColor("#123456"));
        QCOMPARE(preferences.colorString(), QColor("#2a9d5c"));
    }
    void writesSurviveReloadAndNotifyOnlyOnChange()
    {
        EditorPreferences preferences;
        QSignalSpy fontChanges(&preferences, &EditorPreferences::codeFontSizeChanged);
        preferences.setCodeFontSize(20);
        preferences.setCodeFontSize(20);
        QCOMPARE(fontChanges.count(), 1);
        preferences.setIndentWidth(4);
        preferences.setIndentUseTabs(true);
        preferences.setWordWrap(true);
        preferences.setThemeId("dark");
        preferences.setUserName("Designer");
        preferences.setUserEmail("user@example.test");
        preferences.setAvatarPath("file:///example.png");
        preferences.setColorKey(QColor("#654321"));
        EditorPreferences restored;
        QCOMPARE(restored.codeFontSize(), 20);
        QCOMPARE(restored.indentWidth(), 4);
        QVERIFY(restored.indentUseTabs());
        QVERIFY(restored.wordWrap());
        QCOMPARE(restored.themeId(), QString("dark"));
        QCOMPARE(restored.userName(), QString("Designer"));
        QCOMPARE(restored.userEmail(), QString("user@example.test"));
        QCOMPARE(restored.avatarPath(), QString("file:///example.png"));
        QCOMPARE(restored.colorKey(), QColor("#654321"));
    }
    void colorValidationAndReset()
    {
        EditorPreferences preferences;
        QSignalSpy changes(&preferences, &EditorPreferences::colorsChanged);
        preferences.setColorKey(QColor());
        QCOMPARE(changes.count(), 0);
        preferences.setColorKey(QColor("#112233"));
        preferences.setColorString(QColor("#223344"));
        preferences.setColorNumber(QColor("#334455"));
        preferences.setColorKeyword(QColor("#445566"));
        preferences.setColorPunct(QColor("#556677"));
        preferences.resetColors();
        EditorPreferences restored;
        QCOMPARE(restored.colorKey(), QColor("#2563eb"));
        QCOMPARE(restored.colorString(), QColor("#2a9d5c"));
        QCOMPARE(restored.colorNumber(), QColor("#b5651d"));
        QCOMPARE(restored.colorKeyword(), QColor("#8b5cf6"));
        QCOMPARE(restored.colorPunct(), QColor("#7a818f"));
    }
};
QTEST_GUILESS_MAIN(EditorPreferencesTest)
#include "editorpreferences_test.moc"
