#Requires AutoHotkey v2.0
#Include UIA.ahk
SetTitleMatchMode 2

; ==============================================================================
; ★【可自行修改區】★
; ==============================================================================
global SysDelay := 50
global SysSleep := 40
global StepTimeout := 8000      ; 送簡訊每一步最長等待 (ms)，平台很慢時可調大
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

; Ctrl+Alt+C：簽收監控-查詢此單（自動判斷編輯狀態 + 指定跳轉目標視窗）
^!c:: {
    KeyWait("Ctrl"), KeyWait("Alt"), KeyWait("c")
    SetKeyDelay SysDelay
    A_Clipboard := ""

    ; 來源端：判斷是否已在格子編輯狀態，分別全選複製
    hCtl := ControlGetFocus(WinActive("A"))
    cls  := hCtl ? WinGetClass(hCtl) : ""
    if InStr(cls, "Edit")
        SendEvent "{Home}+{End}^c"   ; 已在編輯狀態
    else
        SendEvent "{Space}^c"        ; 尚未編輯，靠自動全選
    ClipWait(1)

    ; 切換到指定目標視窗：追蹤查詢
    WinActivate("ahk_class Ts_tracksearchForm")
    if !WinWaitActive("ahk_class Ts_tracksearchForm", , 2) {
        Flash("找不到或無法切換到「追蹤查詢」視窗")
        return
    }

    ; 目標端：清空欄位 → 貼上 → 查詢
    SendEvent "{End}+{Home}^v{F3}"
}

; Ctrl+Alt+S：送出簡訊（動態等待版）
^!s:: {
    global StepTimeout
    T := StepTimeout
    try {
        ; ── 起始守門：必須「nextStep 在」且「有效名單：不在」才開跑 ──
        root := UIA.ElementFromHandle(WinActive("A"))
        hasStart := false, hasList := false
        try hasStart := root.FindElement({Type:"Group", AutomationId:"nextStep"}) ? true : false
        try hasList  := root.FindElement({Type:"Text",  Name:"有效名單：", MatchMode:"Substring"}) ? true : false
        if (!hasStart || hasList) {
            Flash("非簡訊起始頁，已取消")
            return
        }

        ; ① 第一個「下一步」
        ClickEl(WaitFor({Type:"Group", AutomationId:"nextStep"}, "第1步 下一步", T))
	Sleep SysSleep * 0.6

        ; ② 第二個「下一步」：先等「有效名單：」確認已換頁，再點同一顆 id
        WaitFor({Type:"Text", Name:"有效名單：", MatchMode:"Substring"}, "錨點 有效名單", T, false)
        ClickEl(WaitFor({Type:"Group", AutomationId:"nextStep"}, "第2步 下一步", T))
	Sleep SysSleep * 0.6

        ; ③ 第三個「下一步」（next2_img 出現＝②已成功）
        ClickEl(WaitFor({Type:"Group", AutomationId:"next2_img"}, "第3步 下一步", T))
	Sleep SysSleep * 0.6

        ; ④ 第四個「下一步」：先等「Retry 時間」確認框框已換頁，再點同一顆 id
        WaitFor({Type:"Text", Name:"Retry 時間", MatchMode:"Substring"}, "錨點 Retry 時間", T, false)
        ClickEl(WaitFor({Type:"Group", AutomationId:"next2_img"}, "第4步 下一步", T))

        ; ⑤ 確認傳送（confirmSendId 出現＝④已成功）
	Sleep SysSleep * 0.6
        ClickEl(WaitFor({Type:"Group", AutomationId:"confirmSendId"}, "第5步 確認傳送", T))
	Sleep SysSleep * 0.6

        ; ⑥ 原生對話框「確定」：Chrome 原生對話框對 UIA 點擊無效，改用鍵盤送出（它跳出時握有焦點，確定為預設鍵）
        WaitFor({Type:"Button", Name:"確定", MatchMode:"Substring"}, "第6步 等對話框跳出", T)
        Send "{Enter}"
	Sleep SysSleep * 0.6

        ; ⑦ 收單成功框「確定」：先等「簡訊中心收單成功！」，再點
        WaitFor({Type:"Text", Name:"簡訊中心收單成功！", MatchMode:"Substring"}, "錨點 收單成功", T, false)
        ClickEl(WaitFor({Type:"Text", Name:"確定", MatchMode:"Substring"}, "第7步 收單確定", T))

    } catch as err {
        MsgBox "■ 腳本中斷：`n" err.Message, "錯誤", "0x10"
    }
}

; ==============================================================================
; 【輔助函式】
; ==============================================================================

; 動態等待：每 20ms 重抓當前作用視窗並尋找目標，找到（且可按）即回傳；逾時拋出帶標籤的錯誤
; needClickable=true 時要求 IsEnabled 且 !IsOffscreen（按鈕用）；錨點文字傳 false（只看存在）
WaitFor(cond, label, timeoutMS, needClickable := true) {
    endTime := A_TickCount + timeoutMS
    Loop {
        try {
            root := UIA.ElementFromHandle(WinActive("A"))   ; 每輪重抓，可同時涵蓋頁內元素與原生對話框
            target := root.FindElement(cond)
            if target {
                if (!needClickable) || (target.IsEnabled && !target.IsOffscreen)
                    return target
            }
        }
        if (A_TickCount > endTime)
            throw Error("逾時：等不到【" label "】(" timeoutMS "ms)")
        Sleep 20
    }
}

; 背景點擊：沿用原本經過驗證的後備鏈
ClickEl(target) {
    try target.SetFocus()
    Sleep 30
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
    throw Error("無法點擊元素（背景點擊全部失敗，可能需要實體滑鼠介入）")
}

; 非阻斷提示，自動消失
Flash(msg, ms := 1500) {
    ToolTip msg
    SetTimer () => ToolTip(), -ms
}