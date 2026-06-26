#Requires AutoHotkey v2.0
#SingleInstance Force
#Include UIA.ahk

SetTitleMatchMode(2)   ; 標題「包含」即視為符合

; ════════════════════════════════════════════════════════════════════════════
;  ERP 整合工具：原「ERP快捷鍵」＋「導出單號」合併版
;
;  熱鍵總覽
;    Ctrl+Win+M  叫出「指令輸入區」→ 輸入一行配送員編號即導出單號
;    Ctrl+Win+P  提單圖片：確認未開啟管理視窗 → 跑上傳流程並送出
;    Ctrl+Win+C  追蹤查詢：複製目前選取內容 → 跳到 ERP 追蹤查詢並查詢
;    Ctrl+Win+S  送出簡訊（每一步動態等待目標就緒）
; ════════════════════════════════════════════════════════════════════════════

; ════════════════════════════════════════════════════════════════════════════
; ★【顯示文字｜要改提示框／輸入區的字，改這一區就好】★
;   ‧ 含 {1}、{2} 的是「樣板」：程式會用實際內容（視窗名、數量…）替換，請保留 {1}{2}。
;   ‧ 其餘為純文字，可自由修改。`n 代表換行。
; ════════════════════════════════════════════════════════════════════════════

; ── 指令輸入區（Ctrl+Win+M）介面文字 ──
global UI_CMD_TITLE  := "指令輸入區"
global UI_CMD_PROMPT := "請輸入配送員編號，按『執行』或 Enter："
global UI_BTN_RUN    := "執行"
global UI_BTN_CLEAR  := "清空"

; ── 對話框標題 ──
global TITLE_TIP      := "提示"          ; 一般提示（Alert 預設標題）
global TITLE_CANT_RUN := "無法執行"
global TITLE_EXPORT   := "導出單號"
global TITLE_MONITOR  := "簽收監控"
global TITLE_SMS_NOT  := "未在簡訊平台"
global TITLE_PIC_OPEN := "提單圖片管理已開啟"
global TITLE_ERROR    := "錯誤"

; ── 一般提示訊息 ──
global MSG_ERP_NOT_FOUND     := "找不到「{1}」視窗。`n請先開啟「{1}」之後，再使用本快捷鍵。"   ; {1}=ERP 視窗名
global MSG_ERP_NO_FOREGROUND := "找到「{1}」主視窗，但無法切到前景。"                          ; {1}=ERP 視窗名
global MSG_SMS_NOT_PLATFORM  := "請先切換到瀏覽器中的「{1}」視窗，`n並完成前置作業後，再執行 Ctrl+Win+S。"   ; {1}=簡訊平台視窗名
global MSG_SMS_NOT_START     := "非簡訊起始頁，已取消。"
global MSG_PIC_MGR_OPEN      := "請先關閉「提單圖片管理」視窗後再執行 Ctrl+Win+P。"
global MSG_UPLOAD_FAIL       := "找不到或無法點擊「上傳」按鈕。"
global MSG_RIDER_EMPTY       := "請先輸入配送員編號。"
global MSG_BUSY              := "目前已有一個流程正在執行，請先等它完成後再操作。"
global MSG_MONITOR_OPEN      := "偵測到「簽收監控」視窗已開啟。`n請先手動關閉它，再重新執行。"

; ── Ctrl+Win+C 追蹤查詢提示 ──
global MSG_TRACK_CHILD_NOT_FOUND := "找不到「追蹤查詢」子視窗（請先開啟它）。"
global MSG_TRACK_FIELD_NOT_FOUND := "找不到目標欄位 TEdit1 或無法聚焦。"
global MSG_CLIP_SET_FAIL         := "無法將要查詢的內容放入剪貼簿，請再試一次。"
global MSG_NO_SEL_NO_CLIP        := "沒有選取文字，且剪貼簿是空的。`n請先反白要查詢的單號，或先複製單號後再執行。"
global MSG_CLIP_NOT_ALNUM        := "沒有選取文字；剪貼簿內容不是純英數字，已取消。`n（追蹤查詢只接受英文字母與數字）"
global MSG_CLIP_TOO_LONG         := "沒有選取文字；剪貼簿的英數字共 {2} 個，超過上限 {1} 個字，已取消。"   ; {1}=上限 {2}=實際字數

; ── 錯誤／中斷訊息 ──
;   下面兩個「前綴」後面會直接接系統錯誤訊息：刻意用字串連接而非 {1} 樣板，
;   以免系統錯誤訊息剛好含有大括號時，Format 會解析失敗。
global MSG_SMS_ABORT_PREFIX    := "■ 腳本中斷："
global MSG_EXPORT_ABORT_PREFIX := "中止："
global MSG_STEP_TIMEOUT        := "逾時：等不到【{1}】({2}ms)"   ; {1}=步驟說明 {2}=毫秒
global MSG_CLICK_FAIL          := "無法點擊元素（背景點擊全部失敗，可能需要實體滑鼠介入）。"

; ── 導出流程各步驟的中止訊息 ──
global MSG_ABORT_NO_SIGN_WINDOW := "等不到「簽收監控」子視窗開啟（請確認快遞服務系統正常）。"
global MSG_ABORT_NO_QUERY_BTN   := "找不到「查詢」按鈕。"
global MSG_ABORT_QUERY_TIMEOUT  := "等不到查詢完成（標題未變化）。"
global MSG_ABORT_NO_EXCEL_BTN   := "找不到「EXCEL」按鈕。"
global MSG_ABORT_NO_WAYBILL     := "在「不導出字段」中找不到「運單號碼」。"
global MSG_ABORT_NO_ARROW_BTN   := "找不到「>」箭頭按鈕。"
global MSG_ABORT_NO_EXPORT_BTN  := "找不到「導出EXCEL」按鈕。"
global MSG_ABORT_NO_SAVE_DIALOG := "等不到『另存新檔』視窗，請手動存檔。"

; ────────────────────────────────────────────────────────────────────────────
;  設定區：所有可能需要調整的字串／數值都集中在這裡
; ────────────────────────────────────────────────────────────────────────────
global CFG := {
    ; ── ERP 主視窗辨識（用 class+exe，避免被同名的 Chrome 分頁冒充）──
    erpWin:        "ahk_class Tmainform ahk_exe intelink.exe",
    erpName:       "快遞服務系統",         ; 找不到視窗時提示用的名稱

    ; ── 簡訊平台視窗辨識（^#s 守門用；瀏覽器分頁標題「包含」此字串即視為符合）──
    smsWin:        "電訊簡訊平台",         ; 瀏覽器中的簡訊平台視窗標題
    browserExes:   ["chrome.exe", "msedge.exe", "firefox.exe"],   ; ^#s 額外驗證：作用中視窗必須是其中一種瀏覽器

    ; ── 導出單號流程 ──
    signClass:     "Ts_ok_manageForm",     ; 簽收監控子表單的 UIA ClassName
    subWinOpen:    5000,                    ; 按下開啟後，等簽收監控子視窗出現的上限（毫秒）
    subWin:        "簽收監控",              ; 簽收監控子視窗標題（判斷查詢完成用）
    saveWin:       "另存",                  ; 另存新檔對話框標題
    queryTimeout:  60000,                   ; 等查詢完成的上限（毫秒）

    ; ── 共用時序 ──
    delay:         100,                     ; 導出流程每個動作的間隔（毫秒）
    pollGap:       30,                      ; UIA 輪詢間隔（毫秒）
    sysDelay:      30,                      ; Ctrl+Win+P／C 的 SetKeyDelay（毫秒）
    sysSleep:      40,                      ; Ctrl+Win+P／S 流程內的短暫等待（毫秒）
    stepTimeout:   5000,                    ; 送簡訊每一步的最長等待（毫秒，^#s 用）

    ; ── Ctrl+Win+C 行為 ──
    clipMaxLen:    20                       ; 沒選取文字時，剪貼簿英數字超過此字數就拒絕（防呆）
}

global g_Busy := false   ; 導出防重入旗標：執行中為 true
global g_guarding := false   ; 滑鼠鎖旗標：自動化執行中為 true（供下方 #HotIf 與保護函式使用）
global g_Running := false   ; ^#p／^#c／^#s 共用防重入旗標：任一流程執行中為 true

; 指令輸入區 GUI 物件（延後到第一次叫出時才建立）
cmdGui  := ""
cmdEdit := ""

; 系統匣圖示：不另外覆蓋，編譯成 EXE 後會自動沿用你在編譯時設定的應用程式圖示。
;   （原本這裡寫 TraySetIcon("shell32.dll", 44)，會在啟動時把圖示改成 shell32 的星星，故移除。）
;   若想在「直接執行 .ahk（未編譯）」時也顯示自訂圖示，解除下行註解並改成你的 .ico 路徑：
; TraySetIcon("圖示檔.ico")

; ════════════════════════════════════════════════════════════════════════════
;  熱鍵
; ════════════════════════════════════════════════════════════════════════════

; Ctrl+Win+M：叫出指令輸入區（唯一的叫出方式）
^#m:: {
    if (g_Running || g_Busy) {   ; 有其他流程在跑就不開窗，避免搶走焦點打斷它
        MsgBox(MSG_BUSY, TITLE_TIP, 0x40)
        return
    }
    if (!RequireErpWindow())   ; ERP 視窗不在就不開輸入框
        return
    ShowCmdGui()
}

; Ctrl+Win+P：跳到 ERP →「提單圖片管理」未開啟才跑上傳流程並送出
^#p:: RunExclusive(HotkeyUploadPic)
HotkeyUploadPic() {
    KeyWait("Ctrl"), KeyWait("LWin"), KeyWait("RWin"), KeyWait("p")   ; 等修飾鍵與字母放開（含 Win），避免送鍵時 Win 還按著
    SetKeyDelay(CFG.sysDelay)

    if (!RequireErpWindow())   ; ERP 視窗不在就停止
        return

    if (!GoToErpMain())
        return

    if (FindErpChild("Tyd_jobno_jobnopicdownform")) {
        MsgBox(MSG_PIC_MGR_OPEN, TITLE_PIC_OPEN, 0x30)
        return
    }

    BeginGuard()   ; ← 自動化開始：鎖實體滑鼠＋游標轉圈（F8 可緊急解鎖）
    try {
        ; 前置選單動作：Alt+X → O → Y
        SendEvent("!x")
        Sleep(CFG.sysSleep)
        SendEvent("o")
        Sleep(CFG.sysSleep)
        SendEvent("y")
        Sleep(CFG.sysSleep)

        ; 點「上傳」按鈕
        if (!ClickUploadButton()) {
            EndGuard()   ; 先解鎖，提示框才能用滑鼠關閉
            MsgBox(MSG_UPLOAD_FAIL)
            return
        }
        Sleep(CFG.sysSleep)   ; 等上傳後跳出的視窗／狀態穩定

        ; 既定按鍵序列
        SendEvent("{Down}{Tab}{Down}{Tab 2}{Enter}{Down 2}{Enter}{F2}y")
    } finally {
        EndGuard()   ; 正常結束也解鎖（idempotent，已解鎖則無動作）
    }
}

; Ctrl+Win+C：取得查詢字串（選取優先，沒選取則用剪貼簿英數內容）→ 跳到 ERP「追蹤查詢」貼上並查詢
^#c:: RunExclusive(HotkeyTrackQuery)
HotkeyTrackQuery() {
    KeyWait("Ctrl"), KeyWait("LWin"), KeyWait("RWin"), KeyWait("c")   ; 等修飾鍵與字母放開（含 Win），避免送鍵時 Win 還按著
    SetKeyDelay(CFG.sysDelay)

    if (!RequireErpWindow())   ; ERP 視窗不在就停止，連複製都不做
        return

    ; 1. 取得要查詢的字串（內部已對各種失敗情形提示；回空字串＝中止）
    queryText := GetQueryText()
    if (queryText = "")
        return

    ; 2. 確保剪貼簿內容就是要查詢的字串，供後續 ^v 貼上
    A_Clipboard := queryText
    if (!ClipWait(1)) {
        Alert(MSG_CLIP_SET_FAIL)
        return
    }

    ; 3. 跳到 ERP 主視窗
    if (!GoToErpMain())
        return

    ; 4~6. 跳窗→聚焦→貼上查詢：這段才上鎖（避免貼上途中誤觸跳焦）
    BeginGuard()   ; ← 自動化開始：鎖實體滑鼠＋游標轉圈（F8 可緊急解鎖）
    try {
        ; 4. 等「追蹤查詢」子視窗就緒（最多 3 秒）
        child := ""
        if (!WaitMs(() => (child := FindErpChild("Ts_tracksearchForm")) ? true : false, 3000)) {
            EndGuard()   ; 先解鎖，提示框才能用滑鼠關閉
            Alert(MSG_TRACK_CHILD_NOT_FOUND)
            return
        }

        ; 5. WM_MDIACTIVATE 把子視窗確實啟動並置頂
        hChild  := child.NativeWindowHandle
        hClient := DllCall("GetParent", "ptr", hChild, "ptr")
        SendMessage(0x0222, hChild, 0, , hClient)

        ; 6. 等 TEdit1 取得鍵盤焦點即貼上查詢
        if (!WaitMs(() => ControlFocusReady("TEdit1", hChild), 3000)) {
            EndGuard()   ; 先解鎖，提示框才能用滑鼠關閉
            Alert(MSG_TRACK_FIELD_NOT_FOUND)
            return
        }
        SendEvent("{End}+{Home}^v{F3}")
    } finally {
        EndGuard()   ; 正常結束也解鎖（idempotent，已解鎖則無動作）
    }
}

; 取得追蹤查詢要用的字串。規則：
;   ① 先存下原剪貼簿、清空，再複製目前選取內容。
;   ② 有複製到（代表有選取）→ 原樣採用，不限長度／字元。
;   ③ 沒複製到（代表沒選取）→ 退回用「原本剪貼簿」內容，但僅限純英數字、且不超過 CFG.clipMaxLen 字。
; 回傳要查詢的字串；任何中止情形都會自行提示並回 ""。
GetQueryText() {
    savedText := A_Clipboard            ; 先存原剪貼簿（純文字），供無選取時回退／還原
    A_Clipboard := ""                   ; 清空，才能用 ClipWait 判斷是否真的複製到新內容

    ; 來源端複製：原生 ERP 表格 vs 外部程式 分流
    if (WinActive(CFG.erpWin)) {
        hCtl := ControlGetFocus(WinActive("A"))
        cls  := hCtl ? WinGetClass(hCtl) : ""
        if (InStr(cls, "Edit"))
            SendEvent("{Home}+{End}^c")   ; 已在編輯狀態：整列全選再複製
        else
            SendEvent("{Space}^c")        ; 尚未編輯：空格進入編輯，舊 ERP 自動全選後複製
    } else {
        SendEvent("^c")                   ; 外部程式（Chrome／LINE／Excel…）：直接複製
    }

    ; ② 有選取：複製成功 → 原樣採用
    if (ClipWait(1))
        return A_Clipboard

    ; ③ 沒選取 → 回退用原剪貼簿內容（先把使用者原本的剪貼簿還原）
    A_Clipboard := savedText
    fallback := Trim(savedText, " `t`r`n")
    if (fallback = "") {
        Alert(MSG_NO_SEL_NO_CLIP)
        return ""
    }
    if (!RegExMatch(fallback, "^[A-Za-z0-9]+$")) {
        Alert(MSG_CLIP_NOT_ALNUM)
        return ""
    }
    if (StrLen(fallback) > CFG.clipMaxLen) {
        Alert(Format(MSG_CLIP_TOO_LONG, CFG.clipMaxLen, StrLen(fallback)))
        return ""
    }
    return fallback
}

; Ctrl+Win+S：送出簡訊（每一步都動態等待目標就緒）
^#s:: RunExclusive(HotkeySendSms)
HotkeySendSms() {
    ; 守門：必須先處在「瀏覽器」中的「電訊簡訊平台」視窗（前置作業需使用者自行完成，故不替其跳轉）
    if (!WinActive(CFG.smsWin) || !IsBrowserActive()) {
        MsgBox(Format(MSG_SMS_NOT_PLATFORM, CFG.smsWin), TITLE_SMS_NOT, 0x30)
        return
    }

    T := CFG.stepTimeout

    ; 起始守門（不上鎖，提示框需可用滑鼠關閉）：必須「nextStep 在」且「有效名單：不在」才開跑
    hasStart := false, hasList := false
    try {
        root := UIA.ElementFromHandle(WinActive("A"))
        try hasStart := root.FindElement({Type:"Group", AutomationId:"nextStep"}) ? true : false
        try hasList  := root.FindElement({Type:"Text",  Name:"有效名單：", MatchMode:"Substring"}) ? true : false
    }
    if (!hasStart || hasList) {
        Alert(MSG_SMS_NOT_START)
        return
    }

    BeginGuard()   ; ← 自動化開始：鎖實體滑鼠＋游標轉圈（F8 可緊急解鎖）
    try {
        ; ① 第一個「下一步」
        ClickEl(WaitFor({Type:"Group", AutomationId:"nextStep"}, "第1步 下一步", T))
        Sleep(CFG.sysSleep * 0.6)

        ; ② 第二個「下一步」：先等「有效名單：」確認換頁，再點同一顆 id
        WaitFor({Type:"Text", Name:"有效名單：", MatchMode:"Substring"}, "錨點 有效名單", T, false)
        ClickEl(WaitFor({Type:"Group", AutomationId:"nextStep"}, "第2步 下一步", T))
        Sleep(CFG.sysSleep * 0.6)

        ; ③ 第三個「下一步」（next2_img 出現＝②已成功）
        ClickEl(WaitFor({Type:"Group", AutomationId:"next2_img"}, "第3步 下一步", T))
        Sleep(CFG.sysSleep * 0.6)

        ; ④ 第四個「下一步」：先等「Retry 時間」確認換頁，再點同一顆 id
        WaitFor({Type:"Text", Name:"Retry 時間", MatchMode:"Substring"}, "錨點 Retry 時間", T, false)
        ClickEl(WaitFor({Type:"Group", AutomationId:"next2_img"}, "第4步 下一步", T))
        Sleep(CFG.sysSleep * 0.6)

        ; ⑤ 確認傳送（confirmSendId 出現＝④已成功）
        ClickEl(WaitFor({Type:"Group", AutomationId:"confirmSendId"}, "第5步 確認傳送", T))
        Sleep(CFG.sysSleep * 0.6)

        ; ⑥ 原生對話框「確定」：Chrome 原生對話框對 UIA 點擊無效，改用鍵盤（確定為預設鍵）
        WaitFor({Type:"Button", Name:"確定", MatchMode:"Substring"}, "第6步 等對話框跳出", T)
        Send("{Enter}")
        Sleep(CFG.sysSleep * 1.2)

        ; ⑦ 收單成功框「確定」：先等「簡訊中心收單成功！」，再點
        WaitFor({Type:"Text", Name:"簡訊中心收單成功！", MatchMode:"Substring"}, "錨點 收單成功", T, false)
        ClickEl(WaitFor({Type:"Text", Name:"確定", MatchMode:"Substring"}, "第7步 收單確定", T))

    } catch as err {
        EndGuard()   ; 先解鎖，錯誤框才能用滑鼠關閉
        MsgBox(MSG_SMS_ABORT_PREFIX "`n" err.Message, TITLE_ERROR, 0x10)
    } finally {
        EndGuard()   ; 正常結束也解鎖（idempotent，已解鎖則無動作）
    }
}

; ════════════════════════════════════════════════════════════════════════════
;  保護期間熱鍵：鎖定中吞掉所有實體滑鼠鍵；F8 緊急解鎖
;    只在 g_guarding 為真時生效；平時這些鍵照常運作。
;    （沿用哲盟枝椏／ClearFlow 做法：不靠 BlockInput，免系統管理員權限。
;     腳本自身的點擊都走 UIA 程式化 Invoke／ControlClick，不會被這些熱鍵吞掉。）
; ════════════════════════════════════════════════════════════════════════════
#HotIf g_guarding
*LButton::return
*RButton::return
*MButton::return
*WheelUp::return
*WheelDown::return
*XButton1::return
*XButton2::return
*F8::EndGuard()      ; 保護期間若卡住，按 F8 立即解除鎖定
#HotIf

; ════════════════════════════════════════════════════════════════════════════
;  共用防重入：同一時間只允許一個自動化流程（^#p／^#c／^#s 與導出單號互斥）
;    已有流程在跑（g_Running 或 g_Busy）就提示並略過；否則上旗標跑完一定還原。
; ════════════════════════════════════════════════════════════════════════════
RunExclusive(fn) {
    global g_Running, g_Busy
    if (g_Running || g_Busy) {
        MsgBox(MSG_BUSY, TITLE_TIP, 0x40)
        return
    }
    g_Running := true
    try
        fn()
    finally
        g_Running := false   ; 不論正常結束、提早 return 或例外，都會還原
}

; 作用中視窗是否為瀏覽器（依 exe 名稱比對 CFG.browserExes，比對不分大小寫）
IsBrowserActive() {
    exe := ""
    try exe := WinGetProcessName("A")
    if (exe = "")
        return false
    for b in CFG.browserExes
        if (exe = b)
            return true
    return false
}

; ════════════════════════════════════════════════════════════════════════════
;  指令輸入區（只由 Ctrl+Win+M 叫出）：輸入一行配送員編號即導出單號
; ════════════════════════════════════════════════════════════════════════════
ShowCmdGui(*) {
    global cmdGui, cmdEdit
    if (cmdGui) {                  ; 已建立過 → 直接顯示並把游標放回輸入框
        cmdGui.Show()
        cmdEdit.Focus()
        return
    }
    cmdGui := Gui("+AlwaysOnTop", UI_CMD_TITLE)
    cmdGui.SetFont("s11", "Microsoft JhengHei")
    cmdGui.AddText("", UI_CMD_PROMPT)
    cmdEdit := cmdGui.AddEdit("w240")           ; 單行：只收一個編號
    btnRun := cmdGui.AddButton("w100 Default", UI_BTN_RUN)
    btnRun.OnEvent("Click", RunExport)
    btnClear := cmdGui.AddButton("x+10 w100", UI_BTN_CLEAR)
    btnClear.OnEvent("Click", (*) => cmdEdit.Value := "")
    cmdGui.OnEvent("Close",  (*) => cmdGui.Hide())
    cmdGui.OnEvent("Escape", (*) => cmdGui.Hide())
    cmdGui.Show()
    cmdEdit.Focus()
}

; 讀取輸入框那一行編號，去頭尾空白後導出
RunExport(*) {
    global cmdGui, cmdEdit
    rider := Trim(cmdEdit.Value)
    if (rider = "") {
        MsgBox(MSG_RIDER_EMPTY, TITLE_EXPORT, 0x40)
        return
    }
    cmdGui.Hide()
    DoExportWaybill(rider)
}

; ════════════════════════════════════════════════════════════════════════════
;  導出單號：外層（防重入 + 集中錯誤處理）＋ 內層（實際流程）
; ════════════════════════════════════════════════════════════════════════════
DoExportWaybill(rider) {
    global g_Busy, g_Running
    if (g_Busy || g_Running) {
        MsgBox(MSG_BUSY, TITLE_MONITOR, 0x40)
        return
    }
    g_Busy := true
    try {
        ExportWaybillCore(rider)
    } catch as e {
        EndGuard()        ; 先解鎖，錯誤框才能用滑鼠關閉
        MsgBox(MSG_EXPORT_ABORT_PREFIX e.Message, TITLE_MONITOR, 0x40)
    } finally {
        EndGuard()        ; 正常結束也解鎖（idempotent，已解鎖則無動作）
        g_Busy := false   ; 不論成功、失敗、例外都會解鎖
    }
}

ExportWaybillCore(rider) {
    ; 1. 找到並啟用 ERP 主視窗（含隱藏／最小化還原），取得其數字 HWND 供 UIA 鎖定
    if (!(opHwnd := GoToErpMain()))
        return   ; GoToErpMain 已用 Alert 提示原因

    ; 2.「簽收監控」若已開著 → 提示使用者自行關閉後停止
    signForm := ""
    try signForm := UIA.ElementFromHandle(opHwnd).FindFirst({ClassName: CFG.signClass})
    if (signForm) {
        MsgBox(MSG_MONITOR_OPEN, TITLE_MONITOR, 0x30)
        return
    }

    ; 自動化開始：鎖實體滑鼠＋游標轉圈（F8 可緊急解鎖）。
    ; 解鎖統一由外層 DoExportWaybill 的 try/finally 處理：不論正常結束或 Abort 丟例外都會 EndGuard。
    BeginGuard()

    ; 3. 打開「簽收監控」子視窗：Alt+W 下拉 → W
    Send("!w")
    Sleep(CFG.delay)
    Send("w")
    Sleep(CFG.delay)

    ; 3b. 防呆：等子視窗（ClassName=Ts_ok_manageForm）真的出現，再往下輸入，避免盲打到錯視窗
    if (!WaitEl({Type:"Window", ClassName: CFG.signClass}, CFG.subWinOpen, , opHwnd))
        Abort(MSG_ABORT_NO_SIGN_WINDOW)
    Sleep(CFG.delay)

    ; 4. 輸入今天日期（數字用 SendText 繞過輸入法）
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

    ; 5. 後續欄位：類別 01 →（跳 3 格）派件 →（跳 2 格、確認）→ 配送員編號
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

    ; 6. 記下查詢前的子視窗標題，按「查詢」
    titleBefore := ""
    try titleBefore := WinGetTitle(CFG.subWin)

    btnQuery := WaitEl({Type:"Button", Name:"查詢", ClassName:"TBitBtn"}, 5000, , opHwnd)
    if (!btnQuery)
        Abort(MSG_ABORT_NO_QUERY_BTN)
    btnQuery.Click()

    ; 7. 等子視窗標題「改變」＝查詢完成
    if (!WaitTitleChange(CFG.subWin, titleBefore, CFG.queryTimeout))
        Abort(MSG_ABORT_QUERY_TIMEOUT)
    Sleep(CFG.delay)

    ; 8. 按「EXCEL」叫出導出設定視窗（鎖 opHwnd，標題列變灰也找得到）
    btnExcel := WaitEl({Type:"Button", Name:"EXCEL", ClassName:"TBitBtn"}, 30000, , opHwnd)
    if (!btnExcel)
        Abort(MSG_ABORT_NO_EXCEL_BTN)
    btnExcel.Click()
    Sleep(CFG.delay)

    ; 9. 在「不導出字段」窗格選「運單號碼」並用 > 移走；順便記下導出設定視窗 HWND
    expHwnd := 0
    itemWaybill := ""
    endTime := A_TickCount + 8000
    Loop {
        try {
            curHwnd := WinActive("A")
            pane := UIA.ElementFromHandle(curHwnd).FindFirst({Type:"Pane", Name:"不導出字段", ClassName:"TGroupBox"})
            if (pane) {
                expHwnd := curHwnd
                itemWaybill := pane.FindFirst({Type:"ListItem", Name:"運單號碼"})
            }
        }
        if (itemWaybill || A_TickCount > endTime)
            break
        Sleep(CFG.pollGap)
    }
    if (!itemWaybill)
        Abort(MSG_ABORT_NO_WAYBILL)
    itemWaybill.Select()
    Sleep(CFG.delay)

    btnArrow := WaitEl({Type:"Button", Name:">", ClassName:"TBitBtn"}, 5000)
    if (!btnArrow)
        Abort(MSG_ABORT_NO_ARROW_BTN)
    btnArrow.Invoke()
    Sleep(CFG.delay)

    ; 10. 按「導出EXCEL」
    btnExport := WaitEl({Type:"Button", Name:"導出EXCEL", ClassName:"TButton"}, 8000, , expHwnd)
    if (!btnExport)
        Abort(MSG_ABORT_NO_EXPORT_BTN)
    btnExport.Invoke()

    ; 11. 另存新檔：存到桌面，檔名「配送員編號.MMDD」
    if (!WinWait(CFG.saveWin, , 15))
        Abort(MSG_ABORT_NO_SAVE_DIALOG)
    WinActivate(CFG.saveWin)
    WinWaitActive(CFG.saveWin, , 5)
    Sleep(CFG.delay)

    SendText(A_Desktop "\" rider "." A_MM A_DD)
    Sleep(CFG.delay)
    Send("{Enter}")
}

; 中止用：統一丟例外，由 DoExportWaybill 的 catch 顯示
Abort(msg) {
    throw Error(msg)
}

; ════════════════════════════════════════════════════════════════════════════
;  ERP 視窗／UIA 共用輔助函式
; ════════════════════════════════════════════════════════════════════════════

; 檢查 ERP 主視窗是否存在（含被隱藏／最小化者），只看存在、不啟用、不切前景。
ErpWindowExists() {
    prev := A_DetectHiddenWindows
    DetectHiddenWindows(true)
    exist := WinExist(CFG.erpWin) ? true : false
    DetectHiddenWindows(prev)
    return exist
}

; 守門：ERP 主視窗不存在就用 MsgBox 提示並回 false；存在回 true。
RequireErpWindow() {
    if (ErpWindowExists())
        return true
    MsgBox(Format(MSG_ERP_NOT_FOUND, CFG.erpName), TITLE_CANT_RUN, 0x30)
    return false
}

; 跳到原生 ERP 主視窗（最小化→還原、隱藏→顯示、切到前景）。
; 成功回「數字 HWND」（供 UIA 使用），失敗則 Alert 提示並回 0。
GoToErpMain() {
    DetectHiddenWindows(true)
    hMain := WinExist(CFG.erpWin)
    if (!hMain) {
        DetectHiddenWindows(false)
        Alert(Format(MSG_ERP_NOT_FOUND, CFG.erpName))
        return 0
    }
    winId := "ahk_id " hMain
    if (WinGetMinMax(winId) = -1)            ; 最小化 → 還原
        WinRestore(winId)
    WinShow(winId)                           ; 被隱藏 → 顯示
    DetectHiddenWindows(false)
    if (!ActivateMain(winId)) {
        Alert(Format(MSG_ERP_NO_FOREGROUND, CFG.erpName))
        return 0
    }
    return hMain
}

; 反覆啟用視窗，直到「它本身」確實在前景（用 handle 確認，不靠標題，擺脫同名冒充）
ActivateMain(winId) {
    Loop 20 {
        WinActivate(winId)
        Sleep(120)
        if (WinActive(winId))
            return true
    }
    return false
}

; 在當前作用視窗底下找指定 ClassName 的子視窗；找到回元素、否則回 ""
FindErpChild(className) {
    try return UIA.ElementFromHandle(WinActive("A")).FindElement({Type:"Window", ClassName:className})
    return ""
}

; 點 ERP 的「上傳」按鈕（TBitBtn 的 UIA Invoke 偶爾失敗，重試 3 次）
ClickUploadButton(timeout := 3000) {
    hwnd := WinExist("A")
    if (!hwnd)
        return false
    btn := UIA.ElementFromHandle(hwnd).WaitElement({Type:"Button", Name:"上傳", ClassName:"TBitBtn"}, timeout)
    if (!btn)
        return false
    Loop 3 {
        try {
            btn.Invoke()
            return true
        } catch {
            Sleep(100)
        }
    }
    return false
}

; 通用輪詢：每 gap 毫秒檢查一次 cond()，成立即回 true；逾時回 false
WaitMs(cond, timeoutMS, gap := 15) {
    endTime := A_TickCount + timeoutMS
    Loop {
        try if (cond())
            return true
        if (A_TickCount > endTime)
            return false
        Sleep(gap)
    }
}

; 等到指定視窗標題「非空且不等於 before」＝內容已更新；逾時回 false
WaitTitleChange(win, before, timeoutMS, gap := 150) {
    endTime := A_TickCount + timeoutMS
    Loop {
        cur := ""
        try cur := WinGetTitle(win)
        if (cur != "" && cur != before)
            return true
        if (A_TickCount > endTime)
            return false
        Sleep(gap)
    }
}

; 對指定子視窗聚焦 ctl，並確認它確實取得鍵盤焦點（給 WaitMs 當條件用）
ControlFocusReady(ctl, hChild) {
    try {
        ControlFocus(ctl, hChild)
        return ControlGetFocus(hChild) = ControlGetHwnd(ctl, hChild)
    }
    return false
}

; UIA 元素等待（回傳元素或 ""）：在 hwnd（省略則用當下作用中視窗）底下用 FindFirst 輪詢 cond
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

; UIA 元素等待（找不到就丟例外）：每輪重抓作用中視窗用 FindElement 找 cond；
; needClickable=true 時要求可見可按（按鈕用），錨點文字傳 false（只看存在）
WaitFor(cond, label, timeoutMS, needClickable := true) {
    endTime := A_TickCount + timeoutMS
    Loop {
        try {
            root := UIA.ElementFromHandle(WinActive("A"))   ; 每輪重抓，可同時涵蓋頁內元素與原生對話框
            target := root.FindElement(cond)
            if (target) {
                if (!needClickable) || (target.IsEnabled && !target.IsOffscreen)
                    return target
            }
        }
        if (A_TickCount > endTime)
            throw Error(Format(MSG_STEP_TIMEOUT, label, timeoutMS))
        Sleep(20)
    }
}

; 背景點擊：依序嘗試多種點法，全部失敗才丟例外
ClickEl(target) {
    try target.SetFocus()
    Sleep(30)
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
    throw Error(MSG_CLICK_FAIL)
}

; ════════════════════════════════════════════════════════════════════════════
;  執行保護：自動化期間鎖實體滑鼠、游標顯示忙碌轉圈，避免誤觸造成跳窗或錯誤
;    做法沿用哲盟枝椏／ClearFlow：不靠 BlockInput（免系統管理員權限、較穩定）。
;    實體滑鼠鍵由上方「#HotIf g_guarding」熱鍵吞掉；游標用 100ms 計時器持續壓住，
;    避免 UIA／ERP 互動時被系統改回箭頭而閃爍。
;    一律搭配 try/finally 呼叫，確保動作中途出錯時也會 EndGuard() 解鎖。
;    EndGuard 為 idempotent（已解鎖則直接 return），可重複呼叫不出錯。
; ════════════════════════════════════════════════════════════════════════════
BeginGuard() {
    global g_guarding
    if (g_guarding)
        return
    g_guarding := true              ; 開啟後，上方滑鼠吞鍵熱鍵即生效
    StartCursorLock()
}

EndGuard() {
    global g_guarding
    if (!g_guarding)
        return
    g_guarding := false             ; 關閉滑鼠吞鍵熱鍵
    StopCursorLock()
}

; 把系統游標換成「忙碌(等待)」轉圈（只替換最常見的三種）
SetBusyCursor() {
    static IDs := [32512, 32513, 32649]   ; 箭頭、I 字游標、手形
    for id in IDs {
        hWait := DllCall("LoadCursor", "Ptr", 0, "Ptr", 32514, "Ptr")   ; IDC_WAIT
        hCopy := DllCall("CopyImage", "Ptr", hWait, "UInt", 2, "Int", 0, "Int", 0, "UInt", 0, "Ptr")   ; IMAGE_CURSOR
        DllCall("SetSystemCursor", "Ptr", hCopy, "UInt", id)
    }
}

; 還原系統預設游標（依登錄檔重載，自訂游標配置也會正確還原）
RestoreCursor() {
    DllCall("SystemParametersInfo", "UInt", 0x57, "UInt", 0, "Ptr", 0, "UInt", 0)   ; SPI_SETCURSORS
}

; 游標保活：系統會反覆把游標改回箭頭，用 100ms 計時器持續壓住，肉眼看不到閃爍
CursorLockKeepAlive() {
    global g_guarding
    if (g_guarding)
        SetBusyCursor()
}

StartCursorLock() {
    SetBusyCursor()
    SetTimer(CursorLockKeepAlive, 100)
}

StopCursorLock() {
    SetTimer(CursorLockKeepAlive, 0)
    RestoreCursor()
}

; 阻斷式提示：用 MsgBox 告知使用者（取代原本自動消失的 ToolTip）
Alert(msg, title := "") {
    MsgBox(msg, (title = "" ? TITLE_TIP : title), 0x30)
}
