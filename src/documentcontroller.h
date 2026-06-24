#pragma once

#include <QAbstractListModel>
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

    // Открыть файл во вкладке. Если уже открыт — просто делает активным.
    Q_INVOKABLE void openFile(const QString &path);
    // Закрыть вкладку по индексу.
    Q_INVOKABLE void closeAt(int index);
    // Сделать вкладку активной.
    Q_INVOKABLE void activate(int index);
    // Реакция на переименование/перемещение файла на диске: обновить путь и
    // имя у открытой вкладки, если она ссылается на старый путь.
    Q_INVOKABLE void handlePathRenamed(const QString &oldPath, const QString &newPath);

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
};
