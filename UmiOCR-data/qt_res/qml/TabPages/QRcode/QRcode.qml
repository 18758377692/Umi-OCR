// ==============================================
// =============== 功能页：二维码 ===============
// ==============================================

import QtQuick 2.15

import ".."
import "../../Widgets"
import "../../Widgets/ResultLayout"
import "../../Widgets/ImageViewer"

TabPage {
    id: tabPage
    // 配置
    configsComp: QRcodeConfigs {} 

    // ========================= 【逻辑】 =========================

    // 开始截图
    function screenshot() {
        qmlapp.imageManager.screenshot(screenshotEnd)
    }
    // 截图完毕
    function screenshotEnd(clipID) {
        popMainWindow()
        if(!clipID) {
            return
        }
        const configDict = configsComp.getConfigValueDict()
        running = true
        tabPage.callPy("scanImgID", clipID, configDict)
        qmlapp.tab.showTabPageObj(tabPage) // 切换标签页
    }

    // 开始粘贴
    function paste() {
        popMainWindow()
        const res = qmlapp.imageManager.getPaste()
        if(res.error) {
            qmlapp.popup.simple(qsTr("获取剪贴板异常"), res.error)
            return
        }
        if(res.text) {
            qmlapp.popup.simple(qsTr("剪贴板中为文本"), res.text)
            return
        }
        qmlapp.tab.showTabPageObj(tabPage) // 切换标签页
        if(res.imgID) { // 图片
            imageText.showImgID(res.imgID)
            const configDict = configsComp.getConfigValueDict()
            running = true
            tabPage.callPy("scanImgID", res.imgID, configDict)
        }
        else if(res.paths) { // 地址
            scanPaths(res.paths)
        }
    }

    // 对一批图片路径做扫码
    function scanPaths(paths) {
        paths = qmlapp.utilsConnector.findImages(paths, false)
        if(!paths || paths.length < 1) {
            qmlapp.popup.simple(qsTr("无有效图片"), "")
            return
        }
        const configDict = configsComp.getConfigValueDict()
        const simpleType = configDict["other.simpleNotificationType"]
        qmlapp.popup.simple(qsTr("导入%1条图片路径").arg(paths.length), "", simpleType)
        imageText.showPath(paths[0])
        running = true
        tabPage.callPy("scanPaths", paths, configDict)
    }

    // 弹出主窗口
    function popMainWindow() {
        // 等一回合再弹，防止与收回截图窗口相冲突
        if(configsComp.getValue("action.popMainWindow"))
            Qt.callLater(()=>qmlapp.mainWin.setVisibility(true))
    }

    // ========================= 【python调用qml】 =========================

    // 获取一个扫码的返回值
    function onQRcodeGet(res, imgID="", imgPath="") {
        running = false
        // 添加到结果
        if(imgID) // 图片类型
            imageText.showImgID(imgID)
        else if(imgPath) // 地址类型
            imageText.showPath(imgPath)
            res.title = res.fileName
        imageText.showTextBoxes(res)
        const resText = resultsTableView.addOcrResult(res)
        // 若tabPanel面板的下标没有变化过，则切换到记录页
        if(tabPanel.indexChangeNum < 2)
            tabPanel.currentIndex = 1
        // 复制到剪贴板
        const copy = configsComp.getValue("action.copy")
        if(copy && resText!="") 
            qmlapp.utilsConnector.copyText(resText)
        // 弹出通知
        showSimple(res, resText, copy)
        // 升起主窗口
        popMainWindow()
    }

    // 任务完成后发送通知
    function showSimple(res, resText, isCopy) {
        // 获取弹窗类型
        let simpleType = configsComp.getValue("other.simpleNotificationType")
        if(simpleType==="default") {
            simpleType = qmlapp.globalConfigs.getValue("window.simpleNotificationType")
        }
        const code = res.code
        const time = res.time.toFixed(2)
        let title = ""
        resText = resText.replace(/\n/g, " ") // 换行符替换空格
        if(code === 100 || code === 101) { // 成功时，不发送内部弹窗
            if(simpleType==="inside" || simpleType==="onlyInside")
                if(qmlapp.mainWin.getVisibility()) 
                    return
        }
        if(code === 100) {
            if(isCopy) title = qsTr("已复制到剪贴板")
            else title = qsTr("识图完成")
        }
        else if(code === 101) {
            title = qsTr("无文字")
            resText = ""
        }
        else {
            title = qsTr("识别失败")
        }
        title += `  -  ${time}s`
        qmlapp.popup.simple(title, resText, simpleType)
    }

    // ========================= 【事件管理】 =========================

    Component.onCompleted: {
        eventSub() // 订阅事件
    }
    // 关闭页面
    function closePage() {
        eventUnsub()
        delPage()
    }
    // 订阅事件
    function eventSub() {
        qmlapp.pubSub.subscribeGroup("<<qrcode_screenshot>>", this, "screenshot", ctrlKey)
        qmlapp.pubSub.subscribeGroup("<<qrcode_paste>>", this, "paste", ctrlKey)
        qmlapp.systemTray.addMenuItem("<<qrcode_screenshot>>", qsTr("扫描二维码"), screenshot)
    }
    // 取消订阅事件
    function eventUnsub() {
        qmlapp.systemTray.delMenuItem("<<qrcode_screenshot>>")
        qmlapp.pubSub.unsubscribeGroup(ctrlKey)
    }

    // ========================= 【布局】 =========================
    property bool running: false
    // 主区域：双栏面板
    DoubleRowLayout {
        id: doubleColumnLayout
        anchors.fill: parent
        initSplitterX: 0.5

        // 左面板
        leftItem: Panel {
            anchors.fill: parent
            clip: true
            // 顶部控制栏
            Item  {
                id: dLeftTop
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.topMargin: size_.smallSpacing
                height: size_.line * 1.5
                // 靠左
                Row {
                    id: dLeftTopL
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.leftMargin: size_.spacing
                    spacing: size_.smallSpacing

                    IconButton {
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: height
                        icon_: "screenshot"
                        color: theme.textColor
                        toolTip: qsTr("屏幕截图")
                        onClicked: tabPage.screenshot()
                    }
                    IconButton {
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: height
                        icon_: "paste"
                        color: theme.textColor
                        toolTip: qsTr("粘贴图片")
                        onClicked: tabPage.paste()
                    }
                }
                // 靠右
                Row {
                    id: dLeftTopR
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.rightMargin: size_.spacing
                    spacing: size_.smallSpacing
                    visible: dLeftTop.width > dLeftTopL.width + dLeftTopR.width

                    // 适合宽高
                    IconButton {
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: height
                        icon_: "full_screen"
                        color: theme.subTextColor
                        onClicked: imageText.imageFullFit()
                        toolTip: qsTr("图片大小：适应窗口")
                    }
                    // 1:1
                    IconButton {
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: height
                        icon_: "one_to_one"
                        color: theme.subTextColor
                        onClicked: imageText.imageScaleAddSub(0)
                        toolTip: qsTr("图片大小：实际")
                    }
                    // 百分比显示
                    Text_ {
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        verticalAlignment: Text.AlignBottom
                        horizontalAlignment: Text.AlignRight
                        text: (imageText.scale*100).toFixed(0) + "%"
                        color: theme.subTextColor
                        width: size_.line * 2.5
                    }
                }
            }
            // 图片预览区域
            ImageText {
                id: imageText
                anchors.top: dLeftTop.bottom
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: size_.spacing
                anchors.topMargin: size_.smallSpacing

                // 提示
                DefaultTips {
                    visibleFlag: running
                    anchors.fill: parent
                    tips: qsTr("截图、拖入或粘贴二维码图片")
                }
            }
        }

        // 右面板
        rightItem: Panel {
            anchors.fill: parent

            TabPanel {
                id: tabPanel
                anchors.fill: parent
                anchors.margins: size_.spacing

                // 结果面板
                ResultsTableView {
                    id: resultsTableView
                    anchors.fill: parent
                    visible: false
                }

                tabsModel: [
                    {
                        "key": "configs",
                        "title": qsTr("设置"),
                        "component": configsComp.panelComponent,
                    },
                    {
                        "key": "ocrResult",
                        "title": qsTr("记录"),
                        "component": resultsTableView,
                    },
                ]
            }
        }
    }
}