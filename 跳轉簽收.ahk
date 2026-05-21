#Requires AutoHotkey v2.0
#Include UIA.ahk

SetTitleMatchMode(2)

^!a::SignReceive()

FindSignEl(hwnds*) {
    for hwnd in hwnds {
        try {
            el := UIA.ElementFromHandle(hwnd).FindElement({AutomationId:"65282"})
            if el
                return el
        }
    }
    return 0
}

SignReceive() {
    ; --- 步驟 1：記錄當前視窗（LINE 聊天室），複製單號 ---
    prevHwnd := WinGetID("A")

    A_Clipboard := ""
    Send("^c")
    if !ClipWait(1) {
        MsgBox("複製失敗：請先在 LINE 中選取單號文字")
        return
    }
    trackingNumber := Trim(A_Clipboard)
    if (trackingNumber = "") {
        MsgBox("剪貼簿沒有有效的單號")
        return
    }

    ; --- 步驟 2：找到主框架視窗並啟用 ---
    refHwnd := WinExist("快遞服務系統")
    if !refHwnd {
        MsgBox("找不到『快遞服務系統』視窗")
        return
    }
    mainPid := WinGetPID("ahk_id " refHwnd)

    frameHwnd := 0
    for hwnd in WinGetList() {
        try {
            if WinGetPID("ahk_id " hwnd) = mainPid && hwnd != refHwnd {
                frameHwnd := hwnd
                break
            }
        }
    }
    if !frameHwnd
        frameHwnd := refHwnd

    ; 最小化時停止並提示
    if (WinGetMinMax("ahk_id " frameHwnd) = -1) {
        MsgBox("請展開哲盟頁面")
        return
    }

    targetTid := DllCall("GetWindowThreadProcessId", "Ptr", frameHwnd, "UInt*", 0, "UInt")
    currentTid := DllCall("GetCurrentThreadId", "UInt")
    DllCall("AttachThreadInput", "UInt", currentTid, "UInt", targetTid, "Int", true)
    DllCall("SetForegroundWindow", "Ptr", frameHwnd)
    DllCall("BringWindowToTop", "Ptr", frameHwnd)
    WinActivate("ahk_id " frameHwnd)
    DllCall("AttachThreadInput", "UInt", currentTid, "UInt", targetTid, "Int", false)
    Sleep(150)

    ; --- 步驟 3：搜尋「簽收」子視窗 ---
    signEl := FindSignEl(frameHwnd, refHwnd)

    if !signEl {
        Send("!w")
        Sleep(300)
        Send("n")
        Sleep(300)
        Send("z")

        Loop 12 {
            Sleep(300)
            signEl := FindSignEl(frameHwnd, refHwnd)
            if signEl
                break
        }

        if !signEl {
            MsgBox("無法開啟『簽收』視窗（UIA 搜尋失敗）")
            return
        }
    }

    ; --- 步驟 4：在「運單號碼」欄位輸入單號 ---
    trackingField := signEl.WaitElement({ClassName:"TEdit_jobno"}, 3000)
    if !trackingField {
        MsgBox("找不到『運單號碼』欄位")
        return
    }
    trackingField.SetFocus()
    Sleep(50)
    try {
        trackingField.Value := trackingNumber
    } catch {
        Send("^a")
        Send("{Delete}")
        SendText(trackingNumber)
    }

    ; --- 步驟 5：在「簽收人」欄位輸入「已簽收」，按 Enter ---
    signerField := signEl.WaitElement({Type:"Edit", AutomationId:"1001"}, 3000)
    if !signerField {
        MsgBox("找不到『簽收人』欄位")
        return
    }
    signerField.SetFocus()
    Sleep(50)
    try {
        signerField.Value := "已簽收"
    } catch {
        Send("^a")
        Send("{Delete}")
        SendText("已簽收")
    }
    Sleep(50)
    Send("{Enter}")

    ; --- 步驟 6：將 LINE 聊天室叫回最上層 ---
    Sleep(150)
    if WinExist("ahk_id " prevHwnd) {
        targetTid := DllCall("GetWindowThreadProcessId", "Ptr", prevHwnd, "UInt*", 0, "UInt")
        currentTid := DllCall("GetCurrentThreadId", "UInt")
        DllCall("AttachThreadInput", "UInt", currentTid, "UInt", targetTid, "Int", true)
        DllCall("SetForegroundWindow", "Ptr", prevHwnd)
        DllCall("BringWindowToTop", "Ptr", prevHwnd)
        WinActivate("ahk_id " prevHwnd)
        DllCall("AttachThreadInput", "UInt", currentTid, "UInt", targetTid, "Int", false)
    }
}
