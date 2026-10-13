#include <QGuiApplication>
#include <QClipboard>
#include <QMimeData>
#include <QQmlEngine>
#include <QQmlComponent>
#include <QQuickItem>
#include <QQuickWindow>
#include <QInputMethodEvent>
#include <QAccessible>
#include <QSignalSpy>
#include <QTest>
#include <iostream>
class CountingMime: public QMimeData {
public: mutable int reads = 0;
QStringList formats() const override { return {"text/plain"}; }
protected: QVariant retrieveData(const QString&, QMetaType) const override { reads++; return QString("controlled clipboard"); }
};
int main(int argc,char** argv) {
 if(qEnvironmentVariable("QT_QPA_PLATFORM")!="offscreen" || argc<2) return 2;
 QGuiApplication app(argc,argv); QQmlEngine engine;
 auto probe=[&](const QByteArray& qml) {
  QQmlComponent c(&engine); c.setData(qml,QUrl());
  QObject* item=c.create(); if(!item){std::cerr<<c.errorString().toStdString();return -1;}
  auto* mime=new CountingMime; app.clipboard()->setMimeData(mime); app.processEvents();
  int reads=mime->reads; delete item; app.clipboard()->clear(); return reads;
 };
 int original=probe("import QtQuick; import QtQuick.Controls; TextField {maximumLength:100}");
 int replacement=probe("import QtQuick; import QtQuick.Controls; TextArea {textFormat:TextEdit.PlainText}");
 QQmlComponent production(&engine,QUrl::fromLocalFile(QString::fromLocal8Bit(argv[1])+"/ClipboardField.qml"));
 auto* item=qobject_cast<QQuickItem*>(production.create());
 if(!item){std::cerr<<production.errorString().toStdString();return 2;}
 QQuickWindow window; window.resize(400,100); item->setParentItem(window.contentItem()); item->setSize({400,44}); window.show(); item->forceActiveFocus(); app.processEvents();
 auto* mime=new CountingMime; app.clipboard()->setMimeData(mime); app.processEvents(); int actual=mime->reads;
 QInputMethodEvent preedit(QString::fromUtf8("pré"),{}); app.sendEvent(item,&preedit);
 QInputMethodEvent commit; commit.setCommitString(QString::fromUtf8("日本語")); app.sendEvent(item,&commit);
 bool ime=item->property("text").toString()==QString::fromUtf8("日本語");
 auto* access=QAccessible::queryAccessibleInterface(item);
 bool editable=access && !access->state().readOnly;
 item->setProperty("text",QString("Portal")); item->setProperty("cursorPosition",6);
 QSignalSpy requests(item,SIGNAL(pasteRequested())); QSignalSpy accepted(item,SIGNAL(accepted()));
 QTest::keyClick(&window,Qt::Key_V,Qt::ControlModifier); app.processEvents();
 bool ctrl=requests.count()==1 && mime->reads==0;
 QMetaObject::invokeMethod(item,"finishPaste",Q_ARG(QVariant,QVariant(" 2")),Q_ARG(QVariant,QVariant(0)),Q_ARG(QVariant,QVariant(0)));
 bool normal=item->property("text").toString()=="Portal 2";
 QTest::keyClick(&window,Qt::Key_Insert,Qt::ShiftModifier); app.processEvents();
 bool shift=requests.count()==2 && mime->reads==0;
 QMetaObject::invokeMethod(item,"finishPaste",Q_ARG(QVariant,QVariant(QString(101,'x'))),Q_ARG(QVariant,QVariant(0)),Q_ARG(QVariant,QVariant(0)));
 bool oversized=item->property("text").toString()=="Portal 2";
 QTest::keyClick(&window,Qt::Key_Return); app.processEvents();
 bool enter=accepted.count()==1 && !item->property("text").toString().contains('\n');
 item->setProperty("text",QString("")); item->setProperty("maximumLength",3);
 for(auto key:{Qt::Key_A,Qt::Key_B,Qt::Key_C}) QTest::keyClick(&window,key);
 QTest::keyClick(&window,Qt::Key_Home); QTest::keyClick(&window,Qt::Key_X); app.processEvents();
 bool limit=item->property("text").toString()=="abc";
 QTest::keyClick(&window,Qt::Key_Z,Qt::ControlModifier); app.processEvents();
 bool undo=item->property("text").toString()!="abc";
 item->setProperty("text",QString("abc")); QInputMethodEvent overflow; overflow.setCommitString(QString::fromUtf8("日本"));
 app.sendEvent(item,&overflow); app.processEvents();
 bool imeLimit=item->property("text").toString()=="abc";
 item->setProperty("maximumLength",100); item->setProperty("text",QString("abcd")); item->setProperty("cursorPosition",0);
 int beforeMiddle=requests.count(); QTest::mouseClick(&window,Qt::MiddleButton,Qt::NoModifier,QPoint(200,20)); app.processEvents();
 bool middle=requests.count()==beforeMiddle+1 && item->property("pastePrimary").toBool() && item->property("pasteStart").toInt()==4 && mime->reads==0;
 item->setProperty("text",QString("abcd"));
 QMetaObject::invokeMethod(item,"select",Q_ARG(int,1),Q_ARG(int,3));
 QMetaObject::invokeMethod(item,"finishPaste",Q_ARG(QVariant,QVariant("")),Q_ARG(QVariant,QVariant(1)),Q_ARG(QVariant,QVariant(1)));
 int beforeReflect=requests.count(); QMetaObject::invokeMethod(item,"paste"); app.processEvents();
 bool reflected=requests.count()==beforeReflect+1 && mime->reads==0;
 QMetaObject::invokeMethod(item,"finishPaste",Q_ARG(QVariant,QVariant("XY")),Q_ARG(QVariant,QVariant(0)),Q_ARG(QVariant,QVariant(0)));
 bool selection=item->property("text").toString()=="aXYd";
 QTest::keyClick(&window,Qt::Key_Z,Qt::ControlModifier); app.processEvents();
 std::cout<<"selection undo result="<<item->property("text").toString().toStdString()<<std::endl;
 item->setProperty("text",QString(100,'W')); item->setProperty("cursorPosition",100); app.processEvents();
 bool scroll=item->property("cursorRectangle").toRectF().x()<=item->width();
 QTest::keyClick(&window,Qt::Key_Home); app.processEvents();
 bool home=item->property("cursorRectangle").toRectF().x()>=0;
 QQuickItem nextField(window.contentItem()); nextField.setActiveFocusOnTab(true); nextField.setSize({200,40}); nextField.setY(50);
 item->forceActiveFocus(); QString beforeTab=item->property("text").toString();
 QTest::keyClick(&window,Qt::Key_Tab); app.processEvents();
 bool tabFocus=nextField.hasActiveFocus() && item->property("text").toString()==beforeTab;
 QTest::keyClick(&window,Qt::Key_Backtab,Qt::ShiftModifier); app.processEvents();
 bool backtabFocus=item->hasActiveFocus() && item->property("text").toString()==beforeTab;
 std::cout<<"Tab focus="<<tabFocus<<" Backtab focus="<<backtabFocus<<std::endl;
 std::cout<<"TextField passive reads="<<original<<" TextArea passive reads="<<replacement<<" production passive reads="<<actual<<" IME="<<ime<<" accessible editable="<<editable<<" CtrlV="<<ctrl<<" ShiftInsert="<<shift<<" normal paste="<<normal<<" oversized rejected="<<oversized<<" Enter="<<enter<<" limit="<<limit<<" undo="<<undo<<" IME limit="<<imeLimit<<" middle="<<middle<<" reflected paste="<<reflected<<" selection="<<selection<<" horizontal scroll="<<scroll<<" home="<<home<<std::endl;
 delete item; app.clipboard()->clear();
 return original>=0 && replacement==0 && actual==0 && ime && editable && ctrl && shift && normal && oversized && enter && limit && undo && imeLimit && middle && reflected && selection && scroll && home && tabFocus && backtabFocus ? 0:1;
}