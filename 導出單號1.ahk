#Requires AutoHotkey v2.0
#SingleInstance Force
#include UIA.ahk

SetTitleMatchMode(2)   ; 標題「包含」即視為符合

; ══════════════════════════════════════════════
;  設定區：可能需要更動的字串／數值都集中在這裡
; ══════════════════════════════════════════════
global CFG := {
    findTitle:      "快遞服務系統",                  ; 用來找到主視窗
    okMarkers:      ["快遞服務系統", "國際快遞"],     ; 視為「已到前景」的標題特徵
    signClass:      "Ts_ok_manageForm",             ; 簽收監控子表單的 UIA ClassName
    subWin:         "簽收監控",                       ; 簽收監控子視窗標題（判斷查詢完成用）
    saveWin:        "另存",                           ; 另存新檔對話框標題
    defaultRider:   "Moto12",                         ; 快捷鍵直接導出時的預設配送員編號
    delay:          100,                              ; 每個動作之間的間隔（毫秒）
    pollGap:        30,                               ; UIA 輪詢間隔（毫秒）
    queryTimeout:   60000                             ; 等查詢完成的上限（毫秒）
}

global g_Busy := false   ; 防重入旗標：導出進行中為 true

; ══════════════════════════════════════════════
;  托盤右鍵選單：加入「指令輸入區」
; ══════════════════════════════════════════════
A_TrayMenu.Insert("1&")
A_TrayMenu.Insert("1&", "指令輸入區", ShowCmdGui)
A_TrayMenu.Default := "指令輸入區"
TraySetIcon("shell32.dll", 44)

; 保留快捷鍵：直接導出（用設定區的預設配送員編號）
^!m:: DoExportWaybill(CFG.defaultRider)

; ══════════════════════════════════════════════
;  指令輸入區 GUI
; ══════════════════════════════════════════════
cmdGui := ""
cmdEdit := ""

ShowCmdGui(*) {
    global cmdGui, cmdEdit
    if (cmdGui) {
        cmdGui.Show()
        return
    }
    cmdGui := Gui("+AlwaysOnTop", "指令輸入區")
    cmdGui.SetFont("s11", "Microsoft JhengHei")
    cmdGui.AddText("", "請輸入指令（可多行），按『執行』或 Ctrl+Enter：")
    cmdEdit := cmdGui.AddEdit("w360 r5")
    btnRun := cmdGui.AddButton("w100 Default", "執行")
    btnRun.OnEvent("Click", RunCmd)
    btnClear := cmdGui.AddButton("x+10 w100", "清空")
    btnClear.OnEvent("Click", (*) => cmdEdit.Value := "")
    cmdGui.OnEvent("Close", (*) => cmdGui.Hide())
    cmdGui.OnEvent("Escape", (*) => cmdGui.Hide())
    cmdGui.Show()
}

; Ctrl+Enter 在輸入框裡也能執行
#HotIf WinActive("指令輸入區")
^Enter:: RunCmd()
#HotIf

; ══════════════════════════════════════════════
;  解析輸入字串並分派到對應功能
; ══════════════════════════════════════════════
RunCmd(*) {
    global cmdEdit, cmdGui
    raw := cmdEdit.Value
    if (Trim(raw) = "") {
        MsgBox("沒有輸入任何指令。", "指令輸入區", 0x40)
        return
    }

    lines := []
    for line in StrSplit(raw, "`n", "`r") {
        t := Trim(line)
        if (t != "")
            lines.Push(t)
    }
    if (lines.Length = 0) {
        MsgBox("沒有有效的指令內容。", "指令輸入區", 0x40)
        return
    }

    cmd := lines[1]
    args := []
    Loop lines.Length - 1
        args.Push(lines[A_Index + 1])

    if (cmdGui)
        cmdGui.Hide()

    Dispatch(cmd, args)
}

; ── 指令分派表：將來加新指令只要在這裡多一個 case ──
Dispatch(cmd, args) {
    switch cmd {
        case "導出單號":
            if (args.Length < 1) {
                MsgBox("「導出單號」需要一行配送員編號，例如：`n導出單號`nMoto12", "指令輸入區", 0x40)
                return
            }
            DoExportWaybill(args[1])

        default:
            MsgBox("無法辨識的指令：「" cmd "」", "指令輸入區", 0x40)
    }
}

; ══════════════════════════════════════════════
;  功能本體外層包裝：防重入 + 集中錯誤處理
; ══════════════════════════════════════════════
DoExportWaybill(rider) {
    global g_Busy
    if (g_Busy) {
        MsgBox("目前已有一筆導出正在執行，請稍候。", "簽收監控", 0x40)
        return
    }
    g_Busy := true
    try {
        _ExportWaybillCore(rider)
    } catch as e {
        MsgBox("中止：" e.Message, "簽收監控", 0x40)
    } finally {
        g_Busy := false   ; 不論成功、失敗、例外，都會解鎖
    }
}

; 中止用：統一丟例外，由上層 catch 顯示
Abort(msg) {
    throw Error(msg)
}

; ══════════════════════════════════════════════
;  功能本體：導出單號
; ══════════════════════════════════════════════
_ExportWaybillCore(rider) {
    ; ── 1. 找到並啟用主視窗 ──
    hwnd := WinExist(CFG.findTitle)
    if (!hwnd)
        Abort("找不到「" CFG.findTitle "」視窗")
    winId := "ahk_id " hwnd

    if (WinGetMinMax(winId) = -1) {
        WinRestore(winId)
        Sleep(400)
    }

    if (!ActivateMain(winId))
        Abort("視窗已找到但無法切到前景。`n目前作用中視窗：" WinGetTitle("A"))

    ; ── 2. 按 Alt+W 前，檢查簽收監控是否已開著；若是，提示使用者自行關閉並停止 ──
    ; 用當下作用中視窗當根元素（hwnd 與實際前景視窗常對不上，故不用 hwnd）
    signForm := ""
    try signForm := UIA.ElementFromHandle(WinActive("A")).FindFirst({ClassName: CFG.signClass})
    if (signForm) {
        MsgBox("偵測到「簽收監控」視窗已開啟。`n請先手動關閉它，再重新執行。", "簽收監控", 0x30)
        return
    }

    ; 記下實際在前景操作的視窗 HWND（後續 UIA 鎖定它，不受作用中狀態變化影響）
    opHwnd := WinGetID("A")

    ; ── 3. 打開「簽收監控」子視窗 ──
    Send("!w")
    Sleep(CFG.delay)
    Send("w")
    Sleep(CFG.delay)

    ; ── 4. 輸入日期（數字用 SendText 繞過輸入法）──
    SendText(A_YYYY)
    Sleep(CFG.delay)
    Send("{Right}")
    Sleep(CFG.delay)
    SendText(A_MM)
    Sleep(CFG.delay)
    Send("{Right}")
    Sleep(CFG.delay)
    SendText(A_DD)
    Sleep(CFG.delay)
    Send("{Tab}")
    Sleep(CFG.delay)

    ; ── 5. 後續欄位輸入 ──
    SendText("01")
    Sleep(CFG.delay)
    Send("{Tab 3}")
    Sleep(CFG.delay)
    SendText("派件")
    Sleep(CFG.delay)
    Send("{Tab 2}")
    Sleep(CFG.delay)
    Send("{Enter}")
    Sleep(CFG.delay)
    SendText(rider)
    Sleep(CFG.delay)
    Send("{Enter 2}")
    Sleep(CFG.delay)

    ; ── 6. 按查詢前，先記下「簽收監控」子視窗當前標題 ──
    titleBefore := ""
    try titleBefore := WinGetTitle(CFG.subWin)

    btnQuery := WaitEl({Type:"Button", Name:"查詢", ClassName:"TBitBtn"}, 5000, , opHwnd)
    if (!btnQuery)
        Abort("找不到「查詢」按鈕")
    btnQuery.Click()

    ; ── 7. 等子視窗標題「出現變化」＝查詢完成 ──
    queryDone := false
    endTime := A_TickCount + CFG.queryTimeout
    Loop {
        Sleep(150)
        cur := ""
        try cur := WinGetTitle(CFG.subWin)
        if (cur != "" && cur != titleBefore) {
            queryDone := true
            break
        }
        if (A_TickCount > endTime)
            break
    }
    if (!queryDone)
        Abort("等不到查詢完成（標題未變化）")
    Sleep(CFG.delay)

    ; EXCEL 按鈕鎖定 opHwnd：即使查詢後視窗標題列變灰(非作用中)也找得到
    btnExcel := WaitEl({Type:"Button", Name:"EXCEL", ClassName:"TBitBtn"}, 30000, , opHwnd)
    if (!btnExcel)
        Abort("找不到「EXCEL」按鈕")
    btnExcel.Click()
    Sleep(CFG.delay)

    ; ── 8. 在「不導出字段」窗格中選中「運單號碼」並按 > 箭頭移走 ──
    ; 按下 EXCEL 後會跳出「導出設定」新視窗，這裡用當下作用中視窗抓新視窗
    itemWaybill := ""
    expHwnd := 0            ; 導出設定視窗的 HWND
    endTime := A_TickCount + 8000
    Loop {
        try {
            curHwnd := WinActive("A")
            r := UIA.ElementFromHandle(curHwnd)
            pane := r.FindFirst({Type:"Pane", Name:"不導出字段", ClassName:"TGroupBox"})
            if (pane) {
                expHwnd := curHwnd         ; 記下導出設定視窗，供後續步驟鎖定
                itemWaybill := pane.FindFirst({Type:"ListItem", Name:"運單號碼"})
            }
        }
        if (itemWaybill)
            break
        if (A_TickCount > endTime)
            break
        Sleep(CFG.pollGap)
    }
    if (!itemWaybill)
        Abort("在「不導出字段」中找不到「運單號碼」")
    itemWaybill.Select()
    Sleep(CFG.delay)

    btnArrow := WaitEl({Type:"Button", Name:">", ClassName:"TBitBtn"}, 5000)
    if (!btnArrow)
        Abort("找不到「>」箭頭按鈕")
    btnArrow.Invoke()
    Sleep(CFG.delay)

    ; ── 9. 導出EXCEL 按鈕 ──
    btnExport := WaitEl({Type:"Button", Name:"導出EXCEL", ClassName:"TButton"}, 8000, , expHwnd)
    if (!btnExport)
        Abort("找不到「導出EXCEL」按鈕")
    btnExport.Invoke()

    ; ── 10. 另存新檔：存到桌面，檔名「配送員編號.MMDD」 ──
    if (!WinWait(CFG.saveWin, , 15))
        Abort("等不到『另存新檔』視窗，請手動存檔")
    WinActivate(CFG.saveWin)
    WinWaitActive(CFG.saveWin, , 5)
    Sleep(CFG.delay)

    savePath := A_Desktop "\" rider "." A_MM A_DD
    SendText(savePath)
    Sleep(CFG.delay)
    Send("{Enter}")
}

; ══════════════════════════════════════════════
;  輔助函式
; ══════════════════════════════════════════════

; 啟用主視窗：反覆啟用，直到作用中視窗標題含任一 marker
ActivateMain(winId) {
    Loop 20 {
        WinActivate(winId)
        Sleep(120)
        activeTitle := WinGetTitle("A")
        for marker in CFG.okMarkers {
            if InStr(activeTitle, marker)
                return true
        }
    }
    return false
}

; 在指定視窗(hwnd)底下等待元素；hwnd 省略(0)時才退而用當下作用中視窗
WaitEl(cond, timeout := 8000, gap := "", hwnd := 0) {
    if (gap = "")
        gap := CFG.pollGap
    endTime := A_TickCount + timeout
    Loop {
        try {
            target := hwnd ? hwnd : WinActive("A")
            el := UIA.ElementFromHandle(target).FindFirst(cond)
            if (el)
                return el
        }
        if (A_TickCount > endTime)
            return ""
        Sleep(gap)
    }
}