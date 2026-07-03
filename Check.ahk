#Requires AutoHotkey v2.0
;@Ahk2Exe-UpdateManifest 1
#SingleInstance Force

#Include UIA.ahk

SetTitleMatchMode(2)   ; 標題「包含」即視為符合

; ════════════════════════════════════════════════════════════════════════════
;  ERP 追蹤查詢工具（單一功能精簡版）
;
;  熱鍵
;    Ctrl+Win+C  追蹤查詢：複製目前選取內容 → 跳到 ERP 追蹤查詢並自動查詢
;    F10         隨時可按：還原游標後重啟整個腳本（卡住／出錯時的緊急中斷）
;
;  用法
;    ‧ 反白要查詢的單號（在 ERP 表格、Chrome、LINE、Excel… 皆可）後按 Ctrl+Win+C。
;    ‧ 若沒有反白任何文字，會改用剪貼簿內容（限純英數字、不超過字數上限）。
;
;  ┌─ 日後要改東西，看這裡 ────────────────────────────────────────────────┐
;  │  ‧ 要改提示框「顯示的文字」 → 改下方【顯示文字】區（MSG_／TITLE_）          │
;  │  ‧ 要改視窗辨識、等待時間、字數上限等「設定值」→ 改【設定區 CFG】          │
;  │  ‧ 要改流程動作（按鍵順序、點哪個元素）→ 改 HotkeyTrackQuery 函式          │
;  └──────────────────────────────────────────────────────────────────────────┘
; ════════════════════════════════════════════════════════════════════════════

; ════════════════════════════════════════════════════════════════════════════
; ★【顯示文字｜要改提示框的字，改這一區就好】★
;   ‧ 含 {1}、{2} 的是「樣板」：程式會用實際內容（視窗名、數量…）替換，請保留 {1}{2}。
;   ‧ 其餘為純文字，可自由修改。`n 代表換行。
; ════════════════════════════════════════════════════════════════════════════

; ── 對話框標題 ──
global TITLE_TIP      := "提示"          ; 一般提示（Alert 預設標題）
global TITLE_CANT_RUN := "無法執行"

; ── ERP 視窗相關提示 ──
global MSG_ERP_NOT_FOUND     := "找不到「{1}」視窗。`n請先開啟「{1}」之後，再使用本快捷鍵。"   ; {1}=ERP 視窗名
global MSG_ERP_NO_FOREGROUND := "找到「{1}」主視窗，但無法切到前景。"                          ; {1}=ERP 視窗名
global MSG_BUSY              := "目前已有一個流程正在執行，請先等它完成後再操作。"

; ── 追蹤查詢流程提示 ──
global MSG_TRACK_CHILD_NOT_FOUND := "找不到「追蹤查詢」子視窗（請先開啟它）。"
global MSG_TRACK_FIELD_NOT_FOUND := "找不到目標欄位 TEdit1 或無法聚焦。"
global MSG_CLIP_SET_FAIL         := "無法將要查詢的內容放入剪貼簿，請再試一次。"
global MSG_NO_SEL_NO_CLIP        := "沒有選取文字，且剪貼簿是空的。`n請先反白要查詢的單號，或先複製單號後再執行。"
global MSG_CLIP_NOT_ALNUM        := "沒有選取文字；剪貼簿內容不是純英數字，已取消。`n（追蹤查詢只接受英文字母與數字）"
global MSG_CLIP_TOO_LONG         := "沒有選取文字；剪貼簿的英數字共 {2} 個，超過上限 {1} 個字，已取消。"   ; {1}=上限 {2}=實際字數

; ────────────────────────────────────────────────────────────────────────────
;  設定區：所有可能需要調整的字串／數值都集中在這裡
; ────────────────────────────────────────────────────────────────────────────
global CFG := {
    ; ── ERP 主視窗辨識（用 class+exe，避免被同名的 Chrome 分頁冒充）──
    erpWin:        "ahk_class Tmainform ahk_exe intelink.exe",
    erpName:       "快遞服務系統",         ; 找不到視窗時提示用的名稱

    ; ── 時序 ──
    sysDelay:      30,                      ; 送鍵的 SetKeyDelay（毫秒）

    ; ── 追蹤查詢行為 ──
    clipMaxLen:    20                       ; 沒選取文字時，剪貼簿英數字超過此字數就拒絕（防呆）
}

; ── 防重入旗標 ──
;   本工具只有追蹤查詢一個流程，用單一旗標即可：執行中為 true，防止重複觸發。
global g_Running  := false   ; 追蹤查詢流程執行中為 true
global g_guarding := false   ; 滑鼠鎖旗標：自動化執行中為 true（供下方 #HotIf 與保護函式使用）

; 系統匣圖示：不另外覆蓋，編譯成 EXE 後會自動沿用你在編譯時設定的應用程式圖示。
;   若想在「直接執行 .ahk（未編譯）」時也顯示自訂圖示，解除下行註解並改成你的 .ico 路徑：
; TraySetIcon("圖示檔.ico")

; ════════════════════════════════════════════════════════════════════════════
;  熱鍵
; ════════════════════════════════════════════════════════════════════════════

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

; ════════════════════════════════════════════════════════════════════════════
;  保護期間熱鍵：鎖定中吞掉所有實體滑鼠鍵
;    只在 g_guarding 為真時生效；平時這些鍵照常運作。
;    （不靠 BlockInput，免系統管理員權限。腳本自身動作走程式化 UIA／SendEvent，不受影響。）
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
;  共用防重入：同一時間只允許一個流程執行
;    已有流程在跑（g_Running）就提示並略過；否則上旗標跑完一定還原。
; ════════════════════════════════════════════════════════════════════════════
RunExclusive(fn) {
    global g_Running
    if (g_Running) {
        MsgBox(MSG_BUSY, TITLE_TIP, 0x40)
        return
    }
    g_Running := true
    try
        fn()
    finally
        g_Running := false   ; 不論正常結束、提早 return 或例外，都會還原
}

; ════════════════════════════════════════════════════════════════════════════
;  ERP 視窗共用輔助函式
; ════════════════════════════════════════════════════════════════════════════

; ERP 主視窗是否存在（含隱藏視窗）
ErpWindowExists() {
    prev := A_DetectHiddenWindows
    DetectHiddenWindows(true)
    exist := WinExist(CFG.erpWin) ? true : false
    DetectHiddenWindows(prev)
    return exist
}

; ERP 不在就提示並回 false
RequireErpWindow() {
    if (ErpWindowExists())
        return true
    MsgBox(Format(MSG_ERP_NOT_FOUND, CFG.erpName), TITLE_CANT_RUN, 0x30)
    return false
}

; 跳到 ERP 主視窗（最小化→還原、隱藏→顯示、切到前景）。
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
; 短間隔輪詢：視窗常在數十毫秒內就切到前景，故每 20ms 檢查、一就緒立即返回。
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

; 輪詢等待 cond() 為真，逾時回 false
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

; 對指定控制項聚焦，並確認鍵盤焦點確實落在它身上
ControlFocusReady(ctl, hChild) {
    try {
        ControlFocus(ctl, hChild)
        return ControlGetFocus(hChild) = ControlGetHwnd(ctl, hChild)
    }
    return false
}

; ════════════════════════════════════════════════════════════════════════════
;  執行保護：自動化期間鎖實體滑鼠、游標顯示忙碌轉圈，避免誤觸造成跳窗或錯誤
;    不靠 BlockInput（免系統管理員權限、較穩定）。實體滑鼠鍵由上方「#HotIf g_guarding」
;    熱鍵吞掉；游標用 100ms 計時器持續壓住，避免 UIA／ERP 互動時被系統改回箭頭而閃爍。
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

; 將系統游標暫時換成忙碌轉圈（箭頭、I 字、手形都換成等待游標）
SetBusyCursor() {
    static IDs := [32512, 32513, 32649]   ; 箭頭、I 字游標、手形
    for id in IDs {
        hWait := DllCall("LoadCursor", "Ptr", 0, "Ptr", 32514, "Ptr")   ; IDC_WAIT
        hCopy := DllCall("CopyImage", "Ptr", hWait, "UInt", 2, "Int", 0, "Int", 0, "UInt", 0, "Ptr")   ; IMAGE_CURSOR
        DllCall("SetSystemCursor", "Ptr", hCopy, "UInt", id)
    }
}

; 還原系統預設游標
RestoreCursor() {
    DllCall("SystemParametersInfo", "UInt", 0x57, "UInt", 0, "Ptr", 0, "UInt", 0)   ; SPI_SETCURSORS
}

; 計時器回呼：鎖定期間持續把游標壓成忙碌狀（避免被系統／ERP 改回箭頭）
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

; 一般提示（預設用「提示」標題）
Alert(msg, title := "") {
    MsgBox(msg, (title = "" ? TITLE_TIP : title), 0x30)
}
