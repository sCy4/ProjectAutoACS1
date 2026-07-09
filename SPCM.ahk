#Requires AutoHotkey v2.0
;@Ahk2Exe-UpdateManifest 1
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
;    F10         隨時可按：還原游標後重啟整個腳本（卡住／出錯時的緊急中斷）
;
;  ┌─ 日後要改東西，看這裡 ────────────────────────────────────────────────┐
;  │  ‧ 要改提示框／輸入區「顯示的文字」 → 改下方【顯示文字】區（MSG_／TITLE_／UI_）│
;  │  ‧ 要改視窗辨識、選單名稱、等待時間、字數上限等「設定值」→ 改【設定區 CFG】 │
;  │  ‧ 要改流程動作（按鍵順序、點哪個元素）→ 找對應的 Hotkey 函式（見下方熱鍵區）│
;  │  ‧ 選單項目名稱含 (W)(V) 等快捷字母會隨 ERP 版本變動，程式已用正則自動容錯， │
;  │    改 CFG 的選單名稱時「只填中文、不要填括號字母」即可（如 "運務系統"）。     │
;  └──────────────────────────────────────────────────────────────────────────┘
; ════════════════════════════════════════════════════════════════════════════

; ════════════════════════════════════════════════════════════════════════════
; ★【顯示文字｜要改提示框／輸入區的字，改這一區就好】★
;   ‧ 含 {1}、{2} 的是「樣板」：程式會用實際內容（視窗名、數量…）替換，請保留 {1}{2}。
;   ‧ 其餘為純文字，可自由修改。`n 代表換行。
; ════════════════════════════════════════════════════════════════════════════


; ── 指令輸入區（Ctrl+Win+M）介面文字 ──
global UI_CMD_TITLE  := "導出單號"
global UI_CMD_PROMPT := "請輸入外務編號："
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
global MSG_ABORT_NO_MENU_TOP    := "找不到選單列「{1}」項目（選單文字可能與預期不同）。"   ; {1}=menuTop
global MSG_ABORT_NO_MENU_SIGN   := "展開「{1}」選單後，找不到「{2}」項目（選單文字可能與預期不同）。"   ; {1}=menuTop {2}=menuSign
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

    ; ── 開「簽收監控」用的選單名稱（不同電腦/版本的快捷鍵字母 (W)(V)... 會變，比對時忽略括號內字母）──
    menuTop:         "運務系統",            ; 主選單列項目（MenuBar 底下）
    menuSign:        "簽收監控",            ; 主選單展開後的子項目
    menuOpenTimeout: 3000,                  ; 等主選單項目／下拉選單／子項目依序出現，每一步的上限（毫秒）

    ; ── 開「提單圖片管理」用的選單名稱（^#p；同樣忽略括號內快捷鍵字母）──
    ; 流程：Alt+X 展開「提單系統」彈出選單 → 點「提單圖片」展開其子選單 → 點「提單圖片管理」開窗。
    ; 多層彈出選單會有多個 #32768 並存，故各層彈出選單也記其 Name 以便鎖定正確的那一個。
    picTopMenu:      "提單系統",            ; Alt+X 後第一層彈出選單的 Name（其下含「提單圖片」）
    picSubItem:      "提單圖片",            ; 第一層裡要展開的項目（展開後出現第二層彈出選單）
    picMgrItem:      "提單圖片管理",        ; 第二層裡要點擊開窗的項目

    ; ── 共用時序 ──
    delay:         100,                     ; 導出流程每個動作的間隔（毫秒）
    pollGap:       30,                      ; UIA 輪詢間隔（毫秒）
    sysDelay:      30,                      ; Ctrl+Win+P／C 的 SetKeyDelay（毫秒）
    sysSleep:      40,                      ; Ctrl+Win+P／S 流程內的短暫等待（毫秒）
    stepTimeout:   5000,                    ; 送簡訊每一步的最長等待（毫秒，^#s 用）
    smsConfirmDelay: 150,                   ; ^#s 最後「收單成功」框：每次點「確定」後、再判斷是否關閉前，等這段時間（毫秒）
                                            ;   —— 現已改為「反覆點到成功框關閉」的重試機制，故此值可調短。
                                            ;      太短：可能多點幾次（無害）；太長：收工稍慢。100～200 通常剛好。

    ; ── Ctrl+Win+C 行為 ──
    clipMaxLen:    20                       ; 沒選取文字時，剪貼簿英數字超過此字數就拒絕（防呆）
}

; ── 防重入旗標 ──
;   刻意用兩個旗標而非一個，因為兩類流程的進入點不同：
;     ‧ g_Busy    ：導出單號（^#m → DoExportWaybill，由 GUI 按鈕觸發，不經 RunExclusive）專用。
;     ‧ g_Running ：^#p／^#c／^#s（都經 RunExclusive）共用。
;   兩邊進入前都會「同時檢查對方」（g_Busy || g_Running），藉此達成「導出單號」與
;   「其餘三個流程」之間也互斥——同一時間全腳本只會有一個自動化流程在跑。
global g_Busy     := false   ; 導出單號流程執行中為 true
global g_Running  := false   ; ^#p／^#c／^#s 任一流程執行中為 true
global g_guarding := false   ; 滑鼠鎖旗標：自動化執行中為 true（供下方 #HotIf 與保護函式使用）

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

    ; 先轉圈再檢查：讓使用者一按下就看到游標轉圈，知道腳本已在運作
    ; （檢查「提單圖片管理是否已開」是 UIA 整樹掃描，較慢，不先轉圈會讓人誤以為沒反應）。
    BeginGuard()   ; ← 自動化開始：鎖實體滑鼠＋游標轉圈（F10 可隨時重啟腳本中斷）
    try {
        ; 「提單圖片管理」已開著 → 先解鎖（提示框需可用滑鼠關閉）後提示並停止
        if (FindErpChild("Tyd_jobno_jobnopicdownform")) {
            EndGuard()
            MsgBox(MSG_PIC_MGR_OPEN, TITLE_PIC_OPEN, 0x30)
            return
        }

        ; 前置選單動作：Alt+X 展開「提單系統」→ 點「提單圖片」展開子選單 → 點「提單圖片管理」開窗。
        ; 第一層用鍵盤 Alt+X（沿用既有作法）；第二、三層改用 UIA 點擊，名稱忽略括號內快捷鍵字母。
        OpenPicMgrMenu()

        ; 點「上傳」按鈕
        if (!ClickUploadButton()) {
            EndGuard()   ; 先解鎖，提示框才能用滑鼠關閉
            MsgBox(MSG_UPLOAD_FAIL)
            return
        }
        Sleep(CFG.sysSleep)   ; 等上傳後跳出的視窗／狀態穩定

        ; 既定按鍵序列
        SendEvent("{Down}{Tab}{Down}{Tab 2}{Enter}{Down 2}{Enter}{F2}y")
    } catch as err {
        EndGuard()   ; 先解鎖，錯誤框才能用滑鼠關閉
        MsgBox(MSG_EXPORT_ABORT_PREFIX err.Message, TITLE_ERROR, 0x10)
    } finally {
        EndGuard()   ; 正常結束也解鎖（idempotent，已解鎖則無動作）
    }
}

; 開「提單圖片管理」子視窗的選單流程（^#p 用）：
;   ① Alt+X 展開第一層「提單系統」彈出選單（鍵盤，沿用既有作法）。
;   ② 在「提單系統」彈出選單裡找「提單圖片」並展開——它是展開子選單（非執行），
;      故用 ExpandTopMenu（優先 ExpandCollapse，退回 Invoke）。
;   ③ 在「提單圖片」彈出選單裡找「提單圖片管理」並點擊開窗。
; 兩層項目的快捷鍵字母（如「提單圖片(O)」「提單圖片管理(Y)」）會隨版本變動，故皆用正則容錯。
; 多層彈出選單會有多個 #32768 並存，故第二、三層都用 popupNamePattern 鎖定正確的那一個。
; 任一步驟逾時找不到就 Abort，並先按 Escape 收掉殘留的選單展開狀態。
OpenPicMgrMenu() {
    topPopupPat := MenuNamePattern(CFG.picTopMenu)   ; 第一層彈出選單 Name：提單系統(?)
    subItemPat  := MenuNamePattern(CFG.picSubItem)   ; 要展開的項目：提單圖片(?)
    subPopupPat := MenuNamePattern(CFG.picSubItem)   ; 展開後第二層彈出選單 Name：提單圖片(?)
    mgrItemPat  := MenuNamePattern(CFG.picMgrItem)   ; 要點擊的項目：提單圖片管理(?)

    ; ① Alt+X 展開「提單系統」彈出選單
    SendEvent("!x")
    Sleep(CFG.sysSleep)

    ; ② 在「提單系統」彈出選單裡找「提單圖片」並展開
    itemSub := WaitMenuItem(subItemPat, CFG.menuOpenTimeout, topPopupPat)
    if (!itemSub) {
        Send("{Escape 2}")
        Abort(Format(MSG_ABORT_NO_MENU_SIGN, CFG.picTopMenu, CFG.picSubItem))
    }
    ExpandTopMenu(itemSub)
    Sleep(CFG.delay)

    ; ③ 在「提單圖片」彈出選單裡找「提單圖片管理」並點擊開窗
    itemMgr := WaitMenuItem(mgrItemPat, CFG.menuOpenTimeout, subPopupPat)
    if (!itemMgr) {
        Send("{Escape 3}")   ; 已展開到第三層，多按幾次收乾淨
        Abort(Format(MSG_ABORT_NO_MENU_SIGN, CFG.picSubItem, CFG.picMgrItem))
    }
    ClickEl(itemMgr)
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
    BeginGuard()   ; ← 自動化開始：鎖實體滑鼠＋游標轉圈（F10 可隨時重啟腳本中斷）
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

    BeginGuard()   ; ← 自動化開始：鎖實體滑鼠＋游標轉圈（F10 可隨時重啟腳本中斷）
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
        Sleep(CFG.sysSleep * 2.4)

        ; ⑦ 收單成功框「確定」：反覆點到成功框關閉為止（避免偶爾單次沒點到而卡在最後一步）
        ;    先等「簡訊中心收單成功！」出現當錨點，再進迴圈：
        ;      每輪 →（一）確認成功框還在（沒關才動作，避免關閉後誤點到頁面上其他「確定」）
        ;           →（二）抓「確定」點一次 → 等 smsConfirmDelay → 回頭重判
        ;    成功框消失＝已關閉，break 收工；逾時（T）仍未關才丟例外。
        WaitFor({Type:"Text", Name:"簡訊中心收單成功！", MatchMode:"Substring"}, "錨點 收單成功", T, false)
        endTime := A_TickCount + T
        Loop {
            root := UIA.ElementFromHandle(WinActive("A"))   ; 每輪重抓作用中視窗

            ; （一）成功框還在嗎？消失＝已關閉 → 收工（FindElement 找不到會丟例外，故 try＋三元）
            boxOpen := false
            try boxOpen := root.FindElement({Type:"Text", Name:"簡訊中心收單成功！", MatchMode:"Substring"}) ? true : false
            if (!boxOpen)
                break

            ; （二）成功框還在 → 抓「確定」點一次（抓不到或尚未就緒就這輪略過，下一輪再試）
            try {
                confirmBtn := root.FindElement({Type:"Text", Name:"確定", MatchMode:"Substring"})
                if (confirmBtn.IsEnabled && !confirmBtn.IsOffscreen)
                    ClickEl(confirmBtn)
            }

            Sleep(CFG.smsConfirmDelay)   ; 點完等一小段，讓框有時間關閉，再回頭重判
            if (A_TickCount > endTime)
                throw Error(Format(MSG_STEP_TIMEOUT, "第7步 收單確定", T))
        }

    } catch as err {
        EndGuard()   ; 先解鎖，錯誤框才能用滑鼠關閉
        MsgBox(MSG_SMS_ABORT_PREFIX "`n" err.Message, TITLE_ERROR, 0x10)
    } finally {
        EndGuard()   ; 正常結束也解鎖（idempotent，已解鎖則無動作）
    }
}

; ════════════════════════════════════════════════════════════════════════════
;  保護期間熱鍵：鎖定中吞掉所有實體滑鼠鍵
;    只在 g_guarding 為真時生效；平時這些鍵照常運作。
;    （沿用哲盟枝椏／ClearFlow 做法：不靠 BlockInput，免系統管理員權限。
;     腳本自身的點擊都走 UIA 程式化 Invoke／ControlClick，不會被這些熱鍵吞掉。）
;    F10（重啟腳本）不放這裡——它需要「隨時可按」，故另設為下方的全域熱鍵。
; ════════════════════════════════════════════════════════════════════════════
#HotIf g_guarding
*LButton::return
*RButton::return
*MButton::return
*WheelUp::return
*WheelDown::return
*XButton1::return
*XButton2::return
#HotIf

; F10：隨時可按，還原游標後重啟整個腳本。
;   出錯／卡住時（不論是否在鎖定中、流程卡在哪一步），按 F10 一律能強制回到乾淨狀態，
;   不必判斷當前狀態。重啟前先還原系統游標，避免 SetSystemCursor 改過的轉圈游標殘留。
*F10::RestartScript()

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

    ; 先轉圈再檢查：讓使用者一按下就看到游標轉圈，知道腳本已在運作
    ; （檢查「簽收監控是否已開」是 UIA 整樹掃描，較慢，不先轉圈會讓人誤以為沒反應）。
    ; 解鎖統一由外層 DoExportWaybill 的 try/finally 處理：不論正常結束或 Abort 丟例外都會 EndGuard。
    BeginGuard()

    ; 2.「簽收監控」若已開著 → 提示使用者自行關閉後停止。
    ;    必須用 UIA 偵測：簽收監控子表單是 MDI 子視窗（非頂層視窗），WinExist 抓不到它
    ;    （實測開著時 WinExist 回 0），只有 UIA 找得到。此檢查在 ERP 被其他視窗蓋住、
    ;    UIA 樹尚未就緒時較慢（約 1~1.7 秒），但正確性優先——若漏判成「沒開」會重複開窗，
    ;    導致子視窗焦點不在預設日期欄、後續 Tab 跳欄全部錯亂。
    if (SignMonitorIsOpen(opHwnd)) {
        EndGuard()   ; 先解鎖，提示框才能用滑鼠關閉
        MsgBox(MSG_MONITOR_OPEN, TITLE_MONITOR, 0x30)
        return
    }

    ; 3. 打開「簽收監控」子視窗：點「運務系統」選單列項目 → 點下拉選單中的「簽收監控」
    ;    （不靠 Alt+W／W 之類的鍵盤按鍵：不同電腦／ERP 版本上，括號內的快捷鍵字母可能不同，
    ;     例如「運務系統(W)」在別的電腦可能是「運務系統(V)」，故用 RegEx 比對名稱、忽略括號內字母。）
    OpenSignMonitorMenu(opHwnd)

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

; 反覆啟用視窗，直到「它本身」確實在前景（用 handle 確認，不靠標題，擺脫同名冒充）。
; 改為短間隔輪詢：視窗常在數十毫秒內就切到前景，故每 20ms 檢查一次、一就緒立即返回，
; 不再每輪固定睡滿 120ms（那會白白多等）。WinActivate 不必每輪重發（過於頻繁反而干擾），
; 每 5 輪（約 100ms）重發一次即可。總上限約 2 秒（100 輪 × 20ms）。
ActivateMain(winId) {
    Loop 100 {
        if (Mod(A_Index - 1, 5) = 0)         ; 第 1、6、11… 輪重發一次啟用
            WinActivate(winId)
        if (WinActive(winId))
            return true
        Sleep(20)
    }
    return false
}

; 在當前作用視窗底下找指定 ClassName 的子視窗；找到回元素、否則回 ""
FindErpChild(className) {
    try return UIA.ElementFromHandle(WinActive("A")).FindElement({Type:"Window", ClassName:className})
    return ""
}

; 把選單顯示文字（如「運務系統」）轉成可容忍「括號內快捷鍵字母不同」的比對用正則。
;   「運務系統」→ 比對「運務系統」或「運務系統(任一字母)」（半形／全形括號都接受），
;   這樣不管該電腦的 ERP 版本把快捷鍵設成 (W)(V) 或其他字母，名稱都能對得上。
MenuNamePattern(baseName) {
    escaped := RegExReplace(baseName, "([.\\+*?\[^\]$(){}=!<>|:#-])", "\$1")
    return "^" escaped "([(（][A-Za-z][)）])?\s*$"
}

; 偵測「簽收監控」子視窗是否已開著。回 true／false。
; 簽收監控是 MDI 子視窗（非頂層），只能用 UIA 偵測（WinExist 抓不到）。
; 用整樹 FindFirst 比對 ClassName——實測此寫法在「已開著」時比加 Type:Window 的寫法更快，
; 而「沒開」時兩者相當；由於已開著時會走到提示、不影響自動化耗時，故採此寫法。
SignMonitorIsOpen(opHwnd) {
    sign := ""
    try sign := UIA.ElementFromHandle(opHwnd).FindFirst({ClassName: CFG.signClass})
    return sign ? true : false
}

; 打開「簽收監控」子視窗：兩層都用 UIA 元素定位（名稱忽略括號內快捷鍵字母），不依賴鍵盤快捷鍵。
;   ① 第一層「運務系統」是收合狀態的選單列頂層項目。實測這台電腦上，這些頂層項目在 UIA 樹
;      上**並不是掛在 MenuBar 元素底下**（從 MenuBar 往下只找得到「文件視窗」一項），而是直接
;      掛在主視窗下。故改為：從主視窗一次抓出所有 MenuItem，再用 RegExMatch 比對名稱找到
;      「運務系統」，然後用 ExpandTopMenu 展開它（優先 ExpandCollapse 模式，退回 Invoke）。
;      ——這也是先前各版第一層失敗的真正原因：舊寫法限定「先找 MenuBar、再從其下找」，
;        但目標項目根本不在 MenuBar 子樹裡，故永遠找不到。
;   ② 第二層「簽收監控」在展開後的彈出選單（ClassName "#32768"，獨立頂層視窗）裡。用 WinExist
;      取得其 HWND 後抓出所有 MenuItem，再 RegExMatch 比對名稱找到並點擊。
;      兩層的快捷鍵字母（如「運務系統(W)」「簽收監控(W)/(T)/…」）都會隨版本變動，故皆用正則容錯。
; 任一層逾時找不到就 Abort，並先按 Escape 收掉殘留的選單展開／反白狀態。
OpenSignMonitorMenu(opHwnd) {
    topPattern  := MenuNamePattern(CFG.menuTop)
    signPattern := MenuNamePattern(CFG.menuSign)

    ; ① 在主視窗下找「運務系統」頂層項目並展開
    itemTop := WaitTopMenuItem(opHwnd, topPattern, CFG.menuOpenTimeout)
    if (!itemTop) {
        Send("{Escape}")
        Abort(Format(MSG_ABORT_NO_MENU_TOP, CFG.menuTop))
    }
    ExpandTopMenu(itemTop)
    Sleep(CFG.delay)

    ; ② 在展開出的彈出選單（#32768）裡找「簽收監控」並點擊
    itemSign := WaitMenuItem(signPattern, CFG.menuOpenTimeout)
    if (!itemSign) {
        Send("{Escape 2}")   ; 收掉已展開的子選單與選單列反白，避免中止後卡在選單模式
        Abort(Format(MSG_ABORT_NO_MENU_SIGN, CFG.menuTop, CFG.menuSign))
    }
    ClickEl(itemSign)
}

; 在主視窗（opHwnd）下輪詢尋找「名稱符合 namePattern（正則）」的頂層 MenuItem：
; 每輪抓出主視窗下所有 MenuItem，用 AHK 的 RegExMatch 逐一比對名稱。找到回元素；逾時回 ""。
WaitTopMenuItem(opHwnd, namePattern, timeoutMS, gap := "") {
    if (gap = "")
        gap := CFG.pollGap
    endTime := A_TickCount + timeoutMS
    Loop {
        try {
            items := UIA.ElementFromHandle(opHwnd).FindElements({Type:"MenuItem"})
            if (items) {
                for it in items {
                    nm := ""
                    try nm := it.Name
                    if (nm != "" && RegExMatch(nm, namePattern))
                        return it
                }
            }
        }
        if (A_TickCount > endTime)
            return ""
        Sleep(gap)
    }
}

; 展開選單列頂層項目，使其下拉選單彈出。優先用 ExpandCollapse 模式的 Expand()
; （語義最正確），不支援時退回 ClickEl（Invoke／DoDefaultAction，對多數選單也會展開）。
ExpandTopMenu(item) {
    try {
        item.ExpandCollapsePattern.Expand()
        return
    }
    ClickEl(item)
}

; 取得彈出選單（pop-up menu，ClassName="#32768"）的 UIA 根元素。
; namePattern 為空 → 回傳找到的第一個 #32768（單層選單用，如簽收監控）。
; namePattern 有值 → 在所有並存的 #32768 中，回傳「UIA Name 符合該正則」的那一個
;   （多層選單可能有多個 #32768，需靠 Name 區分，例如「提單系統(X)」「提單圖片(O)」）。
; 注意：原生選單視窗的 Win32 標題（WinGetTitle）是空的，選單名稱只存在於 UIA 的 Name 屬性，
;   故必須先 ElementFromHandle 再讀 .Name 來比對，不能用 WinGetTitle。
; 找不到符合者回 ""（交給呼叫端進入下一輪重試）。
PopupMenuRoot(namePattern := "") {
    prev := A_DetectHiddenWindows
    DetectHiddenWindows(false)              ; 彈出選單為可見視窗，限定只找可見者，避免抓到殘影
    hwnds := WinGetList("ahk_class #32768")
    DetectHiddenWindows(prev)
    if (!hwnds.Length)
        return ""
    if (namePattern = "") {
        try return UIA.ElementFromHandle(hwnds[1])
        return ""
    }
    ; 有指定 Name：逐一讀每個彈出選單的 UIA Name 來比對，回傳符合者
    for h in hwnds {
        try {
            el := UIA.ElementFromHandle(h)
            nm := ""
            try nm := el.Name
            if (nm != "" && RegExMatch(nm, namePattern))
                return el
        }
    }
    return ""
}

; 在彈出選單裡輪詢尋找「名稱符合 namePattern（正則）」的 MenuItem：
; 每輪重新取得彈出選單根節點、抓出其下所有 MenuItem，再用 AHK 的 RegExMatch 逐一比對名稱。
; popupNamePattern：限定要在「哪個 Name 的彈出選單」裡找（多層選單用）；空字串＝第一個 #32768。
; 找到回該 MenuItem；逾時回 ""。
WaitMenuItem(namePattern, timeoutMS, popupNamePattern := "", gap := "") {
    if (gap = "")
        gap := CFG.pollGap
    endTime := A_TickCount + timeoutMS
    Loop {
        root := PopupMenuRoot(popupNamePattern)
        if (root) {
            items := ""
            try items := root.FindElements({Type:"MenuItem"})
            if (items) {
                for it in items {
                    nm := ""
                    try nm := it.Name
                    if (nm != "" && RegExMatch(nm, namePattern))
                        return it
                }
            }
        }
        if (A_TickCount > endTime)
            return ""
        Sleep(gap)
    }
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

; F10 用：還原游標後重啟整個腳本。隨時可按（不論是否在鎖定中）。
; 順序很重要：先停游標保活計時器、再還原系統游標，最後才 Reload——
; 否則計時器可能在 Reload 前一刻又把游標改回轉圈，或 SetSystemCursor 改過的
; 全域游標在重啟後殘留，導致使用者卡在轉圈游標。
RestartScript() {
    global g_guarding
    g_guarding := false             ; 先解除狀態，停用滑鼠吞鍵熱鍵
    SetTimer(CursorLockKeepAlive, 0)   ; 停掉游標保活計時器
    RestoreCursor()                 ; 還原系統預設游標（消除轉圈）
    Reload()                        ; 重啟腳本，強制終止任何卡住的流程
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
