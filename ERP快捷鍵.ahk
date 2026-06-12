#Requires AutoHotkey v2.0
#Include UIA.ahk
SetTitleMatchMode 2

; ==============================================================================
; ★【可自行修改區】★
; ==============================================================================
global SysDelay := 50
global SysSleep := 40
; ==============================================================================

; ==============================================================================
; 【熱鍵】
; ==============================================================================

; Ctrl+Alt+P：上傳客指定位簽收圖片
^!p:: {
    KeyWait("Ctrl"), KeyWait("Alt"), KeyWait("p")
    SetKeyDelay SysDelay
    SendEvent "{Down}{Tab}{Down}{Tab 2}{Enter}{Down 2}{Enter}{F2}y"
}

; Ctrl+Alt+C：簽收監控-查詢此單
^!c:: {
    KeyWait("Ctrl"), KeyWait("Alt"), KeyWait("c")
    SetKeyDelay SysDelay
    A_Clipboard := ""
    SendEvent "{Space}^c"
    ClipWait(1)
    SendEvent "^{Tab}"
    Sleep SysSleep * 5
    SendEvent "{End}+{Home}^v{F3}"
}

; Ctrl+Alt+S：送出簡訊
^!s:: {
    try {
        hWnd := WinActive("A")
        if !hWnd
            return
        el := UIA.ElementFromHandle(hWnd)
        Loop 2 {
            ClickUIElement(el, {Type: "Group", AutomationId: "nextStep"})
            Sleep (A_Index == 2) ? 2000 : 200
        }
        Loop 2 {
            ClickUIElement(el, {Type: "Group", AutomationId: "next2_img"})
            Sleep 200
        }
        ClickUIElement(el, {Type: "Group", AutomationId: "confirmSendId"})
        Sleep 500
        ClickUIElement(el, {Type: "Button", Name: "確定", MatchMode: "Substring"})
        Sleep 500
        ClickUIElement(el, {Type: "Text", Name: "確定", MatchMode: "Substring"})
    } catch as err {
        MsgBox "■ 錯誤：腳本中斷`n" err.Message
    }
}

; ==============================================================================
; 【輔助函式】
; ==============================================================================
ClickUIElement(rootEl, condition) {
    target := rootEl.WaitElement(condition, 5000)
    try target.SetFocus()
    Sleep 50
    try {
        target.DoDefaultAction()
        return
    }
    try {
        target.Invoke()
        return
    }
    try {
        target.ControlClick()
        return
    }
    throw Error("無法在背景點擊該元素，可能需要實體滑鼠介入。")
}
