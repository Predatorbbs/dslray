#pragma once
#include <QJSEngine>
#include <QObject>

class EditorTextTest : public QObject
{
    Q_OBJECT
    QJSEngine m_engine;
    QJSValue call(const char *name, const QJSValueList &arguments);

private slots:
    void initTestCase();
    void logicalLines_data();
    void logicalLines();
    void lineLookupIsLogarithmic();
    void escapedStringsDoNotProduceBrackets();
    void bracketErrors_data();
    void bracketErrors();
    void formattingPreservesJsonAndIsIdempotent();
    void newlineInsertion_data();
    void newlineInsertion();
    void tabAndGuides();
};
