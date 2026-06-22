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

    // Открыть файл во вкладке. Если уже открыт — просто делает активным.
    Q_INVOKABLE void openFile(const QString &path);
    // Закрыть вкладку по индексу.
    Q_INVOKABLE void closeAt(int index);
    // Сделать вкладку активной.
    Q_INVOKABLE void activate(int index);
    // Реакция на переименование/перемещение файла на диске: обновить путь и
    // имя у открытой вкладки, если она ссылается на старый путь.
    Q_INVOKABLE void handlePathRenamed(const QString &oldPath, const QString &newPath);

signals:
    void activeIndexChanged();
    void countChanged();
    void activeChanged();

private:
    int indexOfPath(const QString &path) const;
    static QString normalize(const QString &path);
    static QString baseName(const QString &path);
    static QString readFile(const QString &path);

    QList<OpenDocument> m_docs;
    int m_active = -1;
};
