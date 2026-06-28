#pragma once

#include <QAbstractListModel>
#include <QColor>
#include <QList>
#include <QObject>
#include <QString>

// Одна открытая вкладка-документ.
struct OpenDocument {
    QString path;       // абсолютный путь, разделители "/"
    QString name;       // имя файла для вкладки
    QString content;    // содержимое (читается с диска при открытии)
    bool    modified = false;
};

// Модель открытых документов + управление активной вкладкой.
// Сама является списочной моделью (роли name/path/modified) — её напрямую
// потребляет ListView со вкладками. Активный документ отдаётся через
// activePath/activeName/activeContent для редактора и панели «Структура».
class DocumentController : public QAbstractListModel
{
    Q_OBJECT
    Q_PROPERTY(int activeIndex READ activeIndex WRITE setActiveIndex NOTIFY activeIndexChanged)
    Q_PROPERTY(bool hasDocuments READ hasDocuments NOTIFY countChanged)
    Q_PROPERTY(QString activePath READ activePath NOTIFY activeChanged)
    Q_PROPERTY(QString activeName READ activeName NOTIFY activeChanged)
    Q_PROPERTY(QString activeContent READ activeContent NOTIFY activeChanged)
    // false — «Прозрачный режим» (запись на лету), true — «Безопасный режим»
    // (правки в черновик, в оригинал — по сохранению). Хранится в QSettings.
    Q_PROPERTY(bool safeMode READ safeMode WRITE setSafeMode NOTIFY safeModeChanged)
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
    enum Roles {
        PathRole = Qt::UserRole + 1,
        NameRole,
        ModifiedRole,
    };

    explicit DocumentController(QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = {}) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    int activeIndex() const { return m_active; }
    void setActiveIndex(int index);
    bool hasDocuments() const { return !m_docs.isEmpty(); }
    QString activePath() const;
    QString activeName() const;
    QString activeContent() const;

    bool safeMode() const { return m_safeMode; }
    void setSafeMode(bool on);
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

    // Открыть файл во вкладке. Если уже открыт — просто делает активным.
    Q_INVOKABLE void openFile(const QString &path);
    // Закрыть вкладку по индексу.
    Q_INVOKABLE void closeAt(int index);
    // Сделать вкладку активной.
    Q_INVOKABLE void activate(int index);
    // Реакция на переименование/перемещение файла на диске: обновить путь и
    // имя у открытой вкладки, если она ссылается на старый путь.
    Q_INVOKABLE void handlePathRenamed(const QString &oldPath, const QString &newPath);
    // Закрыть вкладку удалённого файла (если он был открыт).
    Q_INVOKABLE void closePath(const QString &path);

    // Применить правку активного документа. В «Прозрачном режиме» пишется
    // оригинал; в «Безопасном» — черновик, а документ помечается изменённым.
    Q_INVOKABLE void applyEdit(const QString &text);
    // Сбросить правку конкретного документа по пути (например, при уходе с
    // вкладки, когда активным стал уже другой документ).
    Q_INVOKABLE void flushEdit(const QString &path, const QString &text);

    // Сохранить активный документ: записать содержимое в оригинал, удалить
    // черновик, снять пометку «изменён». Триггер — Ctrl+S.
    Q_INVOKABLE void saveActive();

    // Есть ли хоть один открытый документ с несохранёнными изменениями.
    Q_INVOKABLE bool hasUnsavedChanges() const;
    // Применить все черновики в оригиналы (при выключении «Безопасного режима»).
    Q_INVOKABLE void applyAllDrafts();
    // Отбросить все черновики, вернув оригинальное содержимое.
    Q_INVOKABLE void discardAllDrafts();

signals:
    void activeIndexChanged();
    void countChanged();
    void activeChanged();
    void errorOccurred(const QString &message);
    void safeModeChanged();
    void wordWrapChanged();
    void codeFontSizeChanged();
    void indentWidthChanged();
    void indentUseTabsChanged();
    void colorsChanged();
    void themeIdChanged();
    void userChanged();
    // Содержимое активного документа заменено программно (например, отброс
    // черновика) — редактору нужно перечитать текст даже без смены пути.
    void activeContentReset();

private:
    int indexOfPath(const QString &path) const;
    void commitContent(int index);          // запись в черновик/оригинал по режиму
    void setModified(int index, bool value);
    bool writeTextToFile(const QString &path, const QString &text);
    QString draftPathFor(const QString &path) const;
    void deleteDraft(const QString &path) const;
    void persist() const; // сохраняет список открытых вкладок и активную в QSettings
    static QString normalize(const QString &path);
    static QString baseName(const QString &path);
    static QString readFile(const QString &path);

    QList<OpenDocument> m_docs;
    int  m_active = -1;
    bool m_safeMode = false;
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
