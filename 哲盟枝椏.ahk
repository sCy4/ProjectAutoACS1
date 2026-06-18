#Requires AutoHotkey v2.0
#Include UIA.ahk

; ==============================================================================
; ★【可自行修改區】平常維護主要改這上半段就好★
;   本工具功能：快速簽收、快速問題、簽收監控人員捷徑、貼上文本（全在右鍵滑鼠選單）
; ==============================================================================

; --- 按鍵延遲 ---
global SysDelay := 60
global SysSleep := 50

; --- 提示與警示訊息（可自由修改文字）---
global MSG_TITLE := "哲盟枝椏"
; 游標不在正確的視窗/欄位時的警示；{1} 會替換成下面對應的欄位說明
global MSG_WRONG_FIELD := "您尚未選中正確的輸入框，已取消執行。`n`n{1}，再執行此功能。"
global MSG_FIELD_SIGN    := "若您要簽收，請先用滑鼠點一下「簽收」視窗中的「運單號碼」輸入框"
global MSG_FIELD_PROBLEM := "若您要入問題件，請先用滑鼠點一下「問題件管理」視窗中的「運單號碼」輸入框"
global MSG_FIELD_MONITOR := "若您要看某派件員的簽收監控，請先用滑鼠點一下「簽收監控」視窗中的「派件員」輸入框"
; 清單編輯：沒選取列就按「保存修改／刪除此項」時的提示
global MSG_PICK_ROW := "請先在上方清單中選擇你要修改／刪除的項目。"
; 刪除群組的二次確認；{1} 會替換成群組名稱
global MSG_DELETE_GROUP := "確定要刪除群組「{1}」？"
; 新增／重新命名群組的輸入框提示
global MSG_ADD_GROUP_PROMPT    := "請輸入新群組名稱："
global MSG_RENAME_GROUP_PROMPT := "請輸入新的群組名稱："

; --- 介面顯示文字（選單與設定表上的文字都集中在這裡，方便日後維護）---
; 右鍵選單的分類標題（◎ 開頭）
global MENU_HDR_SIGN    := "◇ 快速簽收"
global MENU_HDR_PROBLEM := "◇ 快速問題"
global MENU_HDR_MONITOR := "◇ 簽收監控人員捷徑"
global MENU_HDR_PASTE   := "◇ 貼上文本"
global MENU_EMPTY       := "（尚未設定任何項目，請從右下角圖示開啟設定）"

; 設定視窗標題與分頁名稱
global UI_SETTINGS_TITLE := MSG_TITLE " - 編輯區"
global TAB_SIGN    := "快速簽收"
global TAB_PROBLEM := "快速問題"
global TAB_MONITOR := "簽收監控人員捷徑"
global TAB_PASTE   := "貼上文本"

; 各分頁頂端的用法說明
global HINT_SIGN    := "效果：根據您設定的字串作為簽收類型，自動化簽收動作"
global HINT_PROBLEM := "效果：根據您設定的代號作為問題件類型，自動化入問題件動作"
global HINT_MONITOR := "效果：根據您設定的人員編號，在簽收監控中快速選定人員"
global HINT_PASTE   := "效果：在當前欄位貼上您設定的字串"

; 設定表的欄位標籤（清單第一欄固定為「標題」，第二欄各分頁不同）
global LBL_TITLE       := "標題"
global LBL_COL_SIGN    := "簽收類型"
global LBL_COL_PROBLEM := "問題件類型代號"
global LBL_COL_MONITOR := "人員編碼"
global LBL_COL_PASTE   := "文本內容"
global LBL_GROUP_UNNAMED := "（未命名）"   ; 群組未命名時，群組清單顯示用

; 設定表的按鈕文字
global BTN_ADD        := "新增此項"
global BTN_SAVE       := "保存修改"
global BTN_DELETE     := "刪除此項"
global BTN_UP         := "▲"
global BTN_DOWN       := "▼"
global BTN_GRP_ADD    := "新增人員群組"
global BTN_GRP_RENAME := "重新命名群組"
global BTN_GRP_DELETE := "刪除人員群組"
global BTN_RESTORE    := "本頁還原預設"
global BTN_CANCEL     := "取消"
global BTN_CONFIRM    := "確認"

; 群組管理對話框／提示框的標題
global TITLE_GRP_ADD    := "新增人員群組"
global TITLE_GRP_RENAME := "重新命名群組"
global TITLE_GRP_DELETE := "刪除人員群組"
global TITLE_HINT       := "提示"

; 系統列(托盤)選單文字
global TRAY_SETTINGS    := "編輯區"

; --- 防錯偵測目標（可自由修改）---
; 各功能執行前，游標必須位於「指定 ClassName 的 Edit」，且該 Edit 位於「標題含指定關鍵字的 Window」內，才會執行
; （win 採關鍵字比對：視窗標題只要「包含」該字串即可，例如標題變成「簽收監控 共340筆…」仍算符合）
global GUARD_SIGN    := {class: "TEdit_jobno", win: "簽收"}
global GUARD_PROBLEM := {class: "TEdit",       win: "問題件管理"}
global GUARD_MONITOR := {class: "TEdit",       win: "簽收監控"}

; --- 設定檔位置（每台電腦各一份，不隨漫遊設定檔同步）---
global INI_PATH := EnvGet("LOCALAPPDATA") "\ACStools\哲盟枝椏.ini"

; --- 各分類的預設值（第一次使用、或在分頁按「本頁還原預設」時採用）---
global DEFAULT_SIGN := [
    {title: "已簽收",            code: "已簽收"},
    {title: "客指定位", code: "已放置客戶指定位置"}
]
global DEFAULT_PROBLEM := [
    {title: "電話無人接",        code: "01"},
    {title: "另約派送日期", code: "ct"},
    {title: "更改地址", code: "ca"},
    {title: "收件人不在家",      code: "36"}
]
global DEFAULT_MONITOR := [
    {name: "北市十二位外務", items: [
        {title: "01. 西-溫正杭", code: "20240513"}, {title: "02. 東-蔡俊傑", code: "20240710"},
        {title: "03. 西-戴勝堂", code: "20250324"}, {title: "04. 東-郭香蘭", code: "20260305"},
        {title: "05. 東-趙克強", code: "20289041"}, {title: "06. 東-牟善賢", code: "20290022"},
        {title: "07. 東-詹益全", code: "20296021"}, {title: "08. 東-吳萌瑜", code: "20997092"},
        {title: "09. 東-鄒樂勳", code: "21005222"}, {title: "10. 西-梁志強", code: "21192074"},
        {title: "11. 東-劉彥璋", code: "260603"},   {title: "12. 東-洪森賢", code: "260604"}
    ]},
    {name: "六位外派", items: [
        {title: "機車快遞2", code: "MOTO2"},   {title: "機車快遞5", code: "MOTO5"},
        {title: "機車快遞8", code: "MOTO8"},   {title: "機車快遞10", code: "MOTO10"},
        {title: "機車快遞12", code: "MOTO12"}, {title: "機車快遞13", code: "MOTO13"}
    ]}
]
; 貼上文本：title = 選單上顯示的標題，code = 要貼進輸入框的內容（可多行；用 `n 換行）
; 這些只是範例，請改成你自己常用的罐頭文字。內容會「原樣貼上」，不受當下輸入法（中／英）影響。
global DEFAULT_PASTETEXT := [
    {title: "另約 6/17 (三)", code: "客戶另約派送日期：6/17 (三)"},
    {title: "客戶更改收件地址：", code: "客戶更改收件地址："},
    {title: "北市<每日問題件回報>", code: "<<<每日問題件回報>>>`n日期：6/16`n超過六點後 問題件請自己入問題`n為了避免漏件 請配合!! 謝謝!!`n`n趙克強:`n牟善賢:`n詹益全:`n鄒樂勳:`n吳萌瑜:`n梁志強:`n温正杭:`n蔡俊傑:`n戴勝堂:`n郭香蘭:`n洪森賢:`n學長: `n--------------------請接龍"}
]
; ==============================================================================
; ★【可自行修改區結束】以下為程式邏輯，非必要不用動★
; ==============================================================================

global g_config := ""        ; 目前生效的設定 {sign, problem, monitor, pastetext}
global g_work := ""          ; 設定視窗的暫存編輯副本（按「確認」才寫回 g_config）

global AnythingMenu := ""    ; 主選單（每次設定變更後重建）
global g_subMenus := []      ; 保留子選單參考，避免被回收

global g_guarding := false   ; 是否正在執行保護中（鎖滑鼠＋游標轉圈）；供下方 #HotIf 與保護函式使用

; 設定視窗的物件參考
global g_settingsGui := ""
global g_tab := ""
global g_signEditor := ""
global g_problemEditor := ""
global g_monitorEditor := ""
global g_pasteEditor := ""
global g_groupListBox := ""

; --- 設定視窗外觀（GitHub 淺色風格）---
global UI_FONT := "Microsoft JhengHei UI"
global CLR_TEXT := "1F2328"     ; 主文字
global CLR_MUTED := "57606A"    ; 次要說明文字（灰）
global CLR_BTN_FACE := "F6F8FA" ; 一般按鈕底
global CLR_BTN_TEXT := "24292F" ; 一般按鈕字
global CLR_BORDER := "D0D7DE"   ; 邊框灰
global CLR_PRIMARY := "1F883E"  ; 主要動作綠
global CLR_DANGER := "CF222E"   ; 危險動作紅

; ==============================================================================
; 【啟動流程】一律安靜啟動，要改設定請從右下角系統列圖示 →「設定」
; ==============================================================================
LoadSettings()
BuildMenu()
SetupTray()

; ==============================================================================
; 【熱鍵】只保留呼叫主選單這一鍵（其餘獨立熱鍵功能已另移至別的腳本）
; ==============================================================================
#z:: {
    KeyWait("LWin"), KeyWait("z")
    AnythingMenu.Show()
}

; ==============================================================================
; 【保護期間熱鍵】鎖定中吞掉所有實體滑鼠鍵；F8 緊急解鎖
;   只在 g_guarding 為真時生效；平時這些鍵照常運作。
;   （沿用 ClearFlow 做法：不靠 BlockInput，免系統管理員權限）
; ==============================================================================
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

; ==============================================================================
; 【選單建立】
; ==============================================================================
BuildMenu() {
    global AnythingMenu, g_subMenus, g_config

    AnythingMenu := Menu()
    g_subMenus := []
    anyAdded := false

    ; ◎ 快速簽收
    if HasVisible(g_config.sign) {
        AddHeader(AnythingMenu, MENU_HDR_SIGN)
        for it in g_config.sign {
            if (Trim(it.title) = "")
                continue
            AnythingMenu.Add(" " it.title, Action_Sign.Bind(it.code))
        }
        anyAdded := true
    }

    ; ◎ 快速問題
    if HasVisible(g_config.problem) {
        if anyAdded
            AnythingMenu.Add()
        AddHeader(AnythingMenu, MENU_HDR_PROBLEM)
        for it in g_config.problem {
            if (Trim(it.title) = "")
                continue
            AnythingMenu.Add(" " it.title, Action_PP.Bind(it.code))
        }
        anyAdded := true
    }

    ; ◎ 簽收監控人員捷徑
    if MonitorHasVisible(g_config.monitor) {
        if anyAdded
            AnythingMenu.Add()
        AddHeader(AnythingMenu, MENU_HDR_MONITOR)
        for grp in g_config.monitor {
            if (Trim(grp.name) = "" || !HasVisible(grp.items))
                continue
            sub := Menu()
            for it in grp.items {
                if (Trim(it.title) = "")
                    continue
                sub.Add(it.title, Action_TPC.Bind(it.code))
            }
            g_subMenus.Push(sub)
            AnythingMenu.Add(" " grp.name, sub)
        }
        anyAdded := true
    }

    ; ◎ 貼上文本（固定放在最下方；本身就是一個叫出子選單的項目，子選單列出各文本標題）
    if HasVisible(g_config.pastetext) {
        if anyAdded
            AnythingMenu.Add()
        sub := Menu()
        for it in g_config.pastetext {
            if (Trim(it.title) = "")
                continue
            sub.Add(it.title, Action_PasteText.Bind(it.code))
        }
        g_subMenus.Push(sub)
        AnythingMenu.Add(MENU_HDR_PASTE, sub)
        anyAdded := true
    }

    if !anyAdded
        AddHeader(AnythingMenu, MENU_EMPTY)
}

; 加入一個不可點選的分類標題
AddHeader(targetMenu, text) {
    targetMenu.Add(text, (*) => "")
    targetMenu.Disable(text)
}

HasVisible(arr) {
    for it in arr
        if (Trim(it.title) != "")
            return true
    return false
}

MonitorHasVisible(groups) {
    for grp in groups
        if (Trim(grp.name) != "" && HasVisible(grp.items))
            return true
    return false
}

; ==============================================================================
; 【設定檔讀寫】INI：每個分類存一個 Count，再依序存 Title{n}/Code{n}
;   標題與內容寫入前會先「編碼」（把換行等特殊字元轉成安全字串），讀出時再解碼，
;   這樣「貼上文本」的多行內容才能安全塞進單行式的 INI。
; ==============================================================================
LoadSettings() {
    global g_config, INI_PATH
    if !FileExist(INI_PATH) {
        g_config := DefaultConfig()
        return
    }
    g_config := {
        sign: ReadList("Sign"),
        problem: ReadList("Problem"),
        monitor: ReadMonitor(),
        pastetext: ReadList("PasteText")   ; 舊版設定檔沒有此區段時，會得到空清單（可在設定內按「本頁還原預設」帶入範例）
    }
}

ReadList(section) {
    global INI_PATH
    out := []
    count := Integer(IniRead(INI_PATH, section, "Count", "0"))
    Loop count {
        t := IniRead(INI_PATH, section, "Title" A_Index, "")
        c := IniRead(INI_PATH, section, "Code" A_Index, "")
        out.Push({title: DecodeText(t), code: DecodeText(c)})
    }
    return out
}

ReadMonitor() {
    global INI_PATH
    out := []
    gc := Integer(IniRead(INI_PATH, "Monitor", "GroupCount", "0"))
    Loop gc {
        sec := "Monitor.Group" A_Index
        name := DecodeText(IniRead(INI_PATH, sec, "Name", ""))
        out.Push({name: name, items: ReadList(sec)})
    }
    return out
}

SaveSettings() {
    global g_config, INI_PATH
    EnsureIniFile()
    ClearOldSections()
    WriteList("Sign", g_config.sign)
    WriteList("Problem", g_config.problem)
    WriteMonitor(g_config.monitor)
    WriteList("PasteText", g_config.pastetext)
}

WriteList(section, list) {
    global INI_PATH
    IniWrite(list.Length, INI_PATH, section, "Count")
    for i, it in list {
        IniWrite(EncodeText(it.title), INI_PATH, section, "Title" i)
        IniWrite(EncodeText(it.code), INI_PATH, section, "Code" i)
    }
}

WriteMonitor(groups) {
    global INI_PATH
    IniWrite(groups.Length, INI_PATH, "Monitor", "GroupCount")
    for i, grp in groups {
        sec := "Monitor.Group" i
        IniWrite(EncodeText(grp.name), INI_PATH, sec, "Name")
        IniWrite(grp.items.Length, INI_PATH, sec, "Count")
        for j, it in grp.items {
            IniWrite(EncodeText(it.title), INI_PATH, sec, "Title" j)
            IniWrite(EncodeText(it.code), INI_PATH, sec, "Code" j)
        }
    }
}

; 寫入前先清掉舊區段，避免項目（或群組）數量變少時殘留舊資料
ClearOldSections() {
    global INI_PATH
    IniDelete(INI_PATH, "Sign")
    IniDelete(INI_PATH, "Problem")
    IniDelete(INI_PATH, "PasteText")
    oldGC := Integer(IniRead(INI_PATH, "Monitor", "GroupCount", "0"))
    Loop oldGC
        IniDelete(INI_PATH, "Monitor.Group" A_Index)
    IniDelete(INI_PATH, "Monitor")
}

; 確保資料夾存在，並以 UTF-16 建立空檔（寫入 BOM），確保中文跨語系不亂碼
EnsureIniFile() {
    global INI_PATH
    dir := RegExReplace(INI_PATH, "\\[^\\]+$")
    if !DirExist(dir)
        DirCreate(dir)
    if !FileExist(INI_PATH) {
        f := FileOpen(INI_PATH, "w")
        f.WriteUShort(0xFEFF)     ; UTF-16LE BOM = FF FE
        f.Close()
    }
}

; ==============================================================================
; 【文字編碼／解碼】讓含換行的內容能安全存進 INI（INI 一行一個值，不能有真換行）
;   編碼：反斜線→\\、CR→\r、LF→\n（反斜線一定要最先處理，才不會跟後面衝突）
;   解碼：由左往右逐字還原，\\→反斜線、\n→LF、\r→CR
;   對沒有換行/反斜線的一般代碼（如 01、20240513）來說，編碼後完全不變，故四個分類共用無虞。
; ==============================================================================
EncodeText(s) {
    s := StrReplace(s, "\", "\\")
    s := StrReplace(s, "`r", "\r")
    s := StrReplace(s, "`n", "\n")
    return s
}

DecodeText(s) {
    out := "", i := 1, len := StrLen(s)
    while (i <= len) {
        ch := SubStr(s, i, 1)
        if (ch = "\" && i < len) {
            nxt := SubStr(s, i + 1, 1)
            if (nxt = "n")
                out .= "`n", i += 2
            else if (nxt = "r")
                out .= "`r", i += 2
            else if (nxt = "\")
                out .= "\", i += 2
            else
                out .= ch, i += 1
        } else {
            out .= ch, i += 1
        }
    }
    return out
}

; 統一換行為 CRLF（Windows 編輯框與剪貼簿的標準），確保顯示與貼上都正確
NormCRLF(s) {
    s := StrReplace(s, "`r`n", "`n")
    s := StrReplace(s, "`r", "`n")
    s := StrReplace(s, "`n", "`r`n")
    return s
}

; ==============================================================================
; 【設定資料複製】設定視窗在副本上編輯，按「確認」才覆蓋正式設定
; ==============================================================================
CloneList(arr) {
    out := []
    for it in arr
        out.Push({title: it.title, code: it.code})
    return out
}

CloneGroups(groups) {
    out := []
    for grp in groups
        out.Push({name: grp.name, items: CloneList(grp.items)})
    return out
}

CloneConfig(cfg) {
    return {
        sign: CloneList(cfg.sign),
        problem: CloneList(cfg.problem),
        monitor: CloneGroups(cfg.monitor),
        pastetext: CloneList(cfg.pastetext)
    }
}

DefaultConfig() {
    global DEFAULT_SIGN, DEFAULT_PROBLEM, DEFAULT_MONITOR, DEFAULT_PASTETEXT
    return {
        sign: CloneList(DEFAULT_SIGN),
        problem: CloneList(DEFAULT_PROBLEM),
        monitor: CloneGroups(DEFAULT_MONITOR),
        pastetext: CloneList(DEFAULT_PASTETEXT)
    }
}

; ==============================================================================
; 【設定視窗】GitHub 淺色風格：白底、扁平化分頁內按鈕、原生外圍按鈕
;   版面採統一格線：四個分頁等寬、清單與編輯欄左右各留 16px、按鈕列底邊對齊。
; ==============================================================================
ShowSettings(*) {
    global g_settingsGui, g_work, g_config, g_tab
    global g_signEditor, g_problemEditor, g_monitorEditor, g_pasteEditor, g_groupListBox
    global UI_FONT, CLR_TEXT

    ; 視窗已開著就帶到前景，不重複開
    if (g_settingsGui != "" && WinExist("ahk_id " g_settingsGui.Hwnd)) {
        g_settingsGui.Show()
        return
    }

    g_work := CloneConfig(g_config)

    g_settingsGui := Gui("+AlwaysOnTop", UI_SETTINGS_TITLE)
    g_settingsGui.BackColor := "FFFFFF"
    g_settingsGui.SetFont("s10 c" CLR_TEXT, UI_FONT)

    g_tab := g_settingsGui.Add("Tab3", "x16 y16 w568 h508 -Background",
        [TAB_SIGN, TAB_PROBLEM, TAB_MONITOR, TAB_PASTE])
    g_tab.SetFont("s10 bold", UI_FONT)     ; 分頁標題加粗

    ; --- 分頁1：快速簽收 ---
    g_tab.UseTab(1)
    AddHint(g_settingsGui, 32, 50, 536, HINT_SIGN)
    g_signEditor := ListEditor(g_settingsGui, 32, 76, 536, 264, LBL_COL_SIGN)
    g_signEditor.SetModel(g_work.sign)

    ; --- 分頁2：快速問題 ---
    g_tab.UseTab(2)
    AddHint(g_settingsGui, 32, 50, 536, HINT_PROBLEM)
    g_problemEditor := ListEditor(g_settingsGui, 32, 76, 536, 264, LBL_COL_PROBLEM)
    g_problemEditor.SetModel(g_work.problem)

    ; --- 分頁3：簽收監控人員捷徑 ---
    g_tab.UseTab(3)
    AddHint(g_settingsGui, 32, 50, 536, HINT_MONITOR)
    ; +0x100 = LBS_NOINTEGRALHEIGHT：強制清單高度等於 h106，下緣才會和右側三顆按鈕齊平（同組元素）
    g_groupListBox := g_settingsGui.Add("ListBox", "x32 y76 w384 h106 +0x100 BackgroundWhite", [])
    g_groupListBox.OnEvent("Change", (*) => Monitor_OnGroupSelect())
    MakeButton(g_settingsGui, 428, 76, 140, 30, BTN_GRP_ADD).OnEvent("Click", (*) => Monitor_AddGroup())
    MakeButton(g_settingsGui, 428, 114, 140, 30, BTN_GRP_RENAME).OnEvent("Click", (*) => Monitor_RenameGroup())
    MakeButton(g_settingsGui, 428, 152, 140, 30, BTN_GRP_DELETE, "danger").OnEvent("Click", (*) => Monitor_DeleteGroup())
    g_monitorEditor := ListEditor(g_settingsGui, 32, 198, 536, 142, LBL_COL_MONITOR)
    Monitor_RefreshGroups(1)

    ; --- 分頁4：貼上文本（內容欄為可多行輸入框）---
    g_tab.UseTab(4)
    AddHint(g_settingsGui, 32, 50, 536, HINT_PASTE)
    g_pasteEditor := ListEditor(g_settingsGui, 32, 76, 536, 191, LBL_COL_PASTE, 96, true)
    g_pasteEditor.SetModel(g_work.pastetext)

    ; --- 底部共用按鈕（原生按鈕）---
    g_tab.UseTab(0)
    g_settingsGui.Add("Button", "x16 y540 w130 h34", BTN_RESTORE).OnEvent("Click", Settings_RestoreDefault)
    g_settingsGui.Add("Button", "x396 y540 w90 h34", BTN_CANCEL).OnEvent("Click", Settings_Cancel)
    g_settingsGui.Add("Button", "x494 y540 w90 h34 Default", BTN_CONFIRM).OnEvent("Click", Settings_Confirm)

    g_settingsGui.OnEvent("Close", Settings_Cancel)
    g_settingsGui.OnEvent("Escape", Settings_Cancel)

    g_settingsGui.Show("w600 h590")
}

; 分頁頂端的灰色說明文字（小一號字）
AddHint(g, x, y, w, text) {
    global CLR_MUTED
    h := g.Add("Text", "x" x " y" y " w" w, text)
    h.SetFont("s9 c" CLR_MUTED)
    return h
}

; GitHub 風格扁平按鈕：外層 Text 當 1px 灰框，內層 Text 當按鈕面
MakeButton(g, x, y, w, h, label, kind := "secondary") {
    global CLR_BTN_FACE, CLR_BTN_TEXT, CLR_BORDER, CLR_PRIMARY, CLR_DANGER
    if (kind = "primary") {
        bg := CLR_PRIMARY, fg := "FFFFFF", border := CLR_PRIMARY
    } else if (kind = "danger") {
        bg := CLR_BTN_FACE, fg := CLR_DANGER, border := CLR_BORDER
    } else {
        bg := CLR_BTN_FACE, fg := CLR_BTN_TEXT, border := CLR_BORDER
    }
    g.Add("Text", "x" x " y" y " w" w " h" h " Background" border)
    return g.Add("Text", "x" (x+1) " y" (y+1) " w" (w-2) " h" (h-2) " Background" bg " c" fg " Center 0x200", label)
}

; 確認：寫回設定檔、重建選單
Settings_Confirm(*) {
    global g_config, g_work, g_settingsGui
    g_config := g_work
    SaveSettings()
    BuildMenu()
    g_settingsGui.Destroy()
    g_settingsGui := ""
}

; 本頁還原預設：只還原目前所在分頁，要再按「確認」才存檔生效
Settings_RestoreDefault(*) {
    global g_work, g_tab, g_signEditor, g_problemEditor, g_pasteEditor
    global DEFAULT_SIGN, DEFAULT_PROBLEM, DEFAULT_MONITOR, DEFAULT_PASTETEXT
    t := g_tab.Value
    if (t = 1) {
        g_work.sign := CloneList(DEFAULT_SIGN)
        g_signEditor.SetModel(g_work.sign)
    } else if (t = 2) {
        g_work.problem := CloneList(DEFAULT_PROBLEM)
        g_problemEditor.SetModel(g_work.problem)
    } else if (t = 3) {
        g_work.monitor := CloneGroups(DEFAULT_MONITOR)
        Monitor_RefreshGroups(1)
    } else {
        g_work.pastetext := CloneList(DEFAULT_PASTETEXT)
        g_pasteEditor.SetModel(g_work.pastetext)
    }
}

; 取消／關閉：只關視窗、不存檔（丟棄編輯副本）
Settings_Cancel(*) {
    global g_settingsGui
    g_settingsGui.Destroy()
    g_settingsGui := ""
}

; --- 簽收監控群組管理 ---
Monitor_RefreshGroups(selectIdx := 1) {
    global g_groupListBox, g_work
    g_groupListBox.Delete()
    names := []
    for grp in g_work.monitor
        names.Push(grp.name = "" ? LBL_GROUP_UNNAMED : grp.name)
    if names.Length
        g_groupListBox.Add(names)
    if (g_work.monitor.Length > 0) {
        if (selectIdx < 1 || selectIdx > g_work.monitor.Length)
            selectIdx := g_work.monitor.Length
        g_groupListBox.Choose(selectIdx)
    }
    Monitor_OnGroupSelect()
}

Monitor_OnGroupSelect() {
    global g_groupListBox, g_monitorEditor, g_work
    idx := g_groupListBox.Value
    if (idx >= 1 && idx <= g_work.monitor.Length)
        g_monitorEditor.SetModel(g_work.monitor[idx].items)
    else
        g_monitorEditor.SetModel([])
}

Monitor_AddGroup() {
    global g_work, g_settingsGui, MSG_ADD_GROUP_PROMPT
    g_settingsGui.Opt("-AlwaysOnTop")
    ib := InputBox(MSG_ADD_GROUP_PROMPT, TITLE_GRP_ADD, "w300 h130")
    g_settingsGui.Opt("+AlwaysOnTop")
    if (ib.Result != "OK")
        return
    name := Trim(ib.Value)
    if (name = "")
        return
    g_work.monitor.Push({name: name, items: []})
    Monitor_RefreshGroups(g_work.monitor.Length)
}

Monitor_RenameGroup() {
    global g_work, g_groupListBox, g_settingsGui, MSG_RENAME_GROUP_PROMPT
    idx := g_groupListBox.Value
    if (idx < 1)
        return
    g_settingsGui.Opt("-AlwaysOnTop")
    ib := InputBox(MSG_RENAME_GROUP_PROMPT, TITLE_GRP_RENAME, "w300 h130", g_work.monitor[idx].name)
    g_settingsGui.Opt("+AlwaysOnTop")
    if (ib.Result != "OK")
        return
    name := Trim(ib.Value)
    if (name = "")
        return
    g_work.monitor[idx].name := name
    Monitor_RefreshGroups(idx)
}

Monitor_DeleteGroup() {
    global g_work, g_groupListBox, g_settingsGui, MSG_DELETE_GROUP
    idx := g_groupListBox.Value
    if (idx < 1)
        return
    g_settingsGui.Opt("-AlwaysOnTop")
    ans := MsgBox(StrReplace(MSG_DELETE_GROUP, "{1}", g_work.monitor[idx].name), TITLE_GRP_DELETE, "YesNo Icon!")
    g_settingsGui.Opt("+AlwaysOnTop")
    if (ans != "Yes")
        return
    g_work.monitor.RemoveAt(idx)
    Monitor_RefreshGroups(idx)
}

; ==============================================================================
; 【系統列(托盤)選單】
; ==============================================================================
SetupTray() {
    A_TrayMenu.Insert("1&", TRAY_SETTINGS, (*) => ShowSettings())
    A_TrayMenu.Insert("2&")     ; 分隔線
}

; ==============================================================================
; 【防錯：執行前檢查焦點欄位 + 所在視窗】
;   游標必須停在指定 ClassName 的 Edit，且該 Edit 位於「標題含指定關鍵字」的 Window 內，才放行
; ==============================================================================
FocusedEditInWindow(className, winName) {
    try {
        el := UIA.GetFocusedElement()
        if !(el.Type = UIA.Type.Edit && el.ClassName = className)
            return false
        ; 從焦點欄位往上找祖先，看看是否在指定的視窗內
        walker := UIA.ControlViewWalker
        cur := el
        Loop {
            cur := walker.GetParentElement(cur)
            if !IsObject(cur)
                return false                              ; 走到頂端仍沒找到 → 不放行
            if (cur.Type = UIA.Type.Window && InStr(cur.Name, winName))
                return true       ; 視窗標題「包含」關鍵字即可（標題後綴會隨筆數變動）
        }
    } catch {
        return false                                      ; 抓不到焦點元件時，保守起見不執行
    }
}

WarnWrongField(fieldDesc) {
    global MSG_WRONG_FIELD, MSG_TITLE
    ; 0x40000 = 警示窗強制最上層，確保不被 ERP 視窗蓋住
    MsgBox(StrReplace(MSG_WRONG_FIELD, "{1}", fieldDesc), MSG_TITLE, "Icon! 0x40000")
}

; ==============================================================================
; 【執行保護】自動化期間鎖實體滑鼠、游標顯示忙碌轉圈，避免誤觸造成跳窗或錯誤
;   做法沿用 ClearFlow：不靠 BlockInput（免系統管理員權限、較穩定）。
;   滑鼠鍵由上方「#HotIf g_guarding」的熱鍵吞掉；游標用 100ms 計時器持續壓住，
;   避免 UIA／ERP 互動時被系統改回箭頭而閃爍。
;   一律搭配 try/finally 呼叫，確保動作中途出錯時也會 EndGuard() 解鎖。
; ==============================================================================
BeginGuard() {
    global g_guarding
    if g_guarding
        return
    g_guarding := true              ; 開啟後，滑鼠吞鍵熱鍵即生效
    StartCursorLock()
}

EndGuard() {
    global g_guarding
    if !g_guarding
        return
    g_guarding := false             ; 關閉滑鼠吞鍵熱鍵
    StopCursorLock()
}

; 把系統游標換成「忙碌(等待)」轉圈（只替換最常見的三種）
SetBusyCursor() {
    static IDs := [32512, 32513, 32649]   ; 箭頭、I 字游標、手形
    for id in IDs {
        hWait := DllCall("LoadCursor", "Ptr", 0, "Ptr", 32514, "Ptr")   ; IDC_WAIT
        hCopy := DllCall("CopyImage", "Ptr", hWait, "UInt", 2, "Int", 0, "Int", 0, "UInt", 0, "Ptr") ; IMAGE_CURSOR
        DllCall("SetSystemCursor", "Ptr", hCopy, "UInt", id)
    }
}

; 還原系統預設游標（依登錄檔重載，自訂游標配置也會正確還原）
RestoreCursor() {
    DllCall("SystemParametersInfo", "UInt", 0x57, "UInt", 0, "Ptr", 0, "UInt", 0) ; SPI_SETCURSORS
}

; 游標保活：系統會反覆把游標改回箭頭，用 100ms 計時器持續壓住，肉眼看不到閃爍
CursorLockKeepAlive() {
    global g_guarding
    if g_guarding
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

; ==============================================================================
; 【選單動作函式】各動作執行前先過防錯檢查
; ==============================================================================
Action_Sign(category, *) {
    if !FocusedEditInWindow(GUARD_SIGN.class, GUARD_SIGN.win) {
        WarnWrongField(MSG_FIELD_SIGN)
        return
    }
    BeginGuard()
    try {
        SetKeyDelay SysDelay * 0.6
        SendEvent "{End}+{Home}^v{Tab 3}"
        SendText category
        Sleep SysSleep
        SendEvent "{Enter}"
    } finally {
        EndGuard()
    }
}

Action_PP(Ptype, *) {
    if !FocusedEditInWindow(GUARD_PROBLEM.class, GUARD_PROBLEM.win) {
        WarnWrongField(MSG_FIELD_PROBLEM)
        return
    }
    SavedClip := ClipboardAll()      ; 先備份剪貼簿（放在 try 之前，finally 才能保證還原）
    BeginGuard()
    try {
        SetKeyDelay SysDelay
        SendEvent "{End}+{Home}^v{Tab}{Up}{Down 2}{Tab}"
        Sleep SysSleep
        SendText Ptype
        Sleep SysSleep
        SendEvent "{Enter}+{Tab}^c{Tab}{End}+{Home}^v{F3}"
        Sleep SysSleep * 5
    } finally {
        A_Clipboard := SavedClip     ; 不論成功或中途出錯，都還原剪貼簿
        SavedClip := ""
        EndGuard()
    }
}

Action_TPC(Cnumber, *) {
    if !FocusedEditInWindow(GUARD_MONITOR.class, GUARD_MONITOR.win) {
        WarnWrongField(MSG_FIELD_MONITOR)
        return
    }
    BeginGuard()
    try {
        SetKeyDelay SysDelay
        SendEvent "{Tab}{Enter}"
        Sleep SysSleep
        SendText Cnumber
        Sleep SysSleep
        SendEvent "{Enter 2}"
	Sleep 30
        loop 20 {       ; 最多重試約 1 秒，給「六位外派」這種較慢的查詢足夠時間讓按鈕/元素樹就緒
            try {
                btn := UIA.ElementFromHandle(WinActive("A")).FindFirst({Type:"Button", Name:"查詢", ClassName:"TBitBtn"})
                if btn {
                    btn.Invoke()
                    break
                }
            } catch {
                ; 清單重建中時 UIA 可能暫時丟錯，吞掉後繼續重試
            }
            Sleep 50
        }
    } finally {
        EndGuard()
    }
}

; 貼上文本：刻意「不綁定」特定視窗——任何視窗、任何輸入框，只要游標在裡面就能貼。
;   用剪貼簿貼上而非 SendText，是為了「不管當下輸入法是中文或英文都準確輸入」：
;   SendText 的英數字在注音輸入法作用時可能被吃進組字區，剪貼簿貼上則完全繞過輸入法。
Action_PasteText(content, *) {
    if (content = "")
        return
    content := NormCRLF(content)        ; 換行統一成 CRLF，多行貼上才正確

    SavedClip := ClipboardAll()         ; 先備份原剪貼簿（含格式），放在 try 之前以保證還原
    BeginGuard()
    try {
        A_Clipboard := ""               ; 先清空，方便 ClipWait 判斷新內容是否就緒
        A_Clipboard := content
        if !ClipWait(1)                 ; 等剪貼簿確實放好（最多 1 秒）；失敗就放棄（finally 仍會還原並解鎖）
            return
        SetKeyDelay SysDelay
        SendEvent "^v"                  ; 貼上到目前游標所在的輸入框
        Sleep SysSleep * 3              ; 給目標欄位讀取剪貼簿、完成貼上的時間
    } finally {
        A_Clipboard := SavedClip        ; 不論結果都還原原本的剪貼簿內容
        SavedClip := ""
        EndGuard()
    }
}

; ==============================================================================
; 【清單編輯元件】ListView + 兩列編輯欄 + 滿版按鈕列，可變數量
;   contentH／multiline：給「貼上文本」用——把「內容」欄做成較高的可多行輸入框。
; ==============================================================================
class ListEditor {
    model := []
    gui := ""
    lv := ""
    titleEdit := ""
    codeEdit := ""

    __New(g, x, y, w, lvH, col2Label, contentH := 23, multiline := false) {
        this.gui := g

        ; --- 清單 ---
        this.lv := g.Add("ListView", "x" x " y" y " w" w " h" lvH " Grid BackgroundWhite", [LBL_TITLE, col2Label])
        this.lv.ModifyCol(1, Round(w * 0.4))   ; 標題欄約佔 4 成
        this.lv.ModifyCol(2, "AutoHdr")        ; 內容欄自動填滿剩餘寬度（會自動扣掉捲軸），右側不留多餘空白
        this.lv.OnEvent("ItemSelect", (*) => this.OnSelect())

        ; --- 兩列編輯欄：標題一列、代碼/內容一列（欄位滿版）---
        ly1 := y + lvH + 14
        g.Add("Text", "x" x " y" ly1 " w" w, LBL_TITLE)
        this.titleEdit := g.Add("Edit", "x" x " y" (ly1 + 22) " w" w)

        ly2 := ly1 + 60
        g.Add("Text", "x" x " y" ly2 " w" w, col2Label)
        contentOpts := "x" x " y" (ly2 + 22) " w" w
        if multiline
            contentOpts .= " h" contentH " WantReturn VScroll"   ; 高度 > 1 行即為多行輸入框；WantReturn 讓 Enter 換行而非觸發「確認」
        this.codeEdit := g.Add("Edit", contentOpts)

        ; --- 按鈕列：前三顆等寬、後兩顆箭頭固定 40px，五顆排滿整列、右邊不留白 ---
        contentBoxH := multiline ? contentH : 23
        by := ly2 + 22 + contentBoxH + 17
        gap := 8, arrowW := 40
        eqW := (w - 2*arrowW - 4*gap) // 3
        lastEqW := w - 2*arrowW - 4*gap - 2*eqW     ; 餘數補到第三顆，確保剛好滿版
        x1 := x
        x2 := x1 + eqW + gap
        x3 := x2 + eqW + gap
        x4 := x3 + lastEqW + gap
        x5 := x4 + arrowW + gap
        MakeButton(g, x1, by, eqW, 32, BTN_ADD).OnEvent("Click", (*) => this.AddRow())
        MakeButton(g, x2, by, eqW, 32, BTN_SAVE).OnEvent("Click", (*) => this.UpdateRow())
        MakeButton(g, x3, by, lastEqW, 32, BTN_DELETE, "danger").OnEvent("Click", (*) => this.DeleteRow())
        MakeButton(g, x4, by, arrowW, 32, BTN_UP).OnEvent("Click", (*) => this.MoveRow(-1))
        MakeButton(g, x5, by, arrowW, 32, BTN_DOWN).OnEvent("Click", (*) => this.MoveRow(1))
    }

    ; 換綁定的資料陣列並重畫（簽收監控切換群組時會用到）
    SetModel(arr) {
        this.model := arr
        this.Refresh()
        this.titleEdit.Value := ""
        this.codeEdit.Value := ""
    }

    Refresh() {
        this.lv.Delete()
        for it in this.model
            this.lv.Add("", it.title, this.Preview(it.code))   ; 清單只顯示單行預覽（換行壓成空白）
        this.lv.ModifyCol(2, "AutoHdr")   ; 依目前列數/捲軸狀態重算內容欄寬，確保填滿、右側不留白
    }

    ; 清單欄位預覽：把換行壓成空白，避免多行內容在格子裡顯示成方塊
    Preview(s) {
        s := StrReplace(s, "`r`n", " ")
        s := StrReplace(s, "`r", " ")
        s := StrReplace(s, "`n", " ")
        return s
    }

    ; 點選某列 → 把內容載入下方編輯欄（內容轉成 CRLF，多行才會正確顯示）
    OnSelect() {
        row := this.lv.GetNext()
        if !row
            return
        this.titleEdit.Value := this.model[row].title
        this.codeEdit.Value := NormCRLF(this.model[row].code)
    }

    AddRow() {
        t := Trim(this.titleEdit.Value)
        c := Trim(this.codeEdit.Value)
        if (t = "" && c = "")
            return
        this.model.Push({title: t, code: c})
        this.Refresh()
        this.titleEdit.Value := ""
        this.codeEdit.Value := ""
        this.lv.Modify(this.model.Length, "Vis")
    }

    UpdateRow() {
        row := this.lv.GetNext()
        if !row {
            this.Hint(MSG_PICK_ROW)
            return
        }
        this.model[row].title := Trim(this.titleEdit.Value)
        this.model[row].code := Trim(this.codeEdit.Value)
        this.Refresh()
        this.lv.Modify(row, "Select Focus")
    }

    DeleteRow() {
        row := this.lv.GetNext()
        if !row {
            this.Hint(MSG_PICK_ROW)
            return
        }
        this.model.RemoveAt(row)
        this.Refresh()
        this.titleEdit.Value := ""
        this.codeEdit.Value := ""
    }

    MoveRow(dir) {
        row := this.lv.GetNext()
        if !row
            return
        target := row + dir
        if (target < 1 || target > this.model.Length)
            return
        tmp := this.model[row]
        this.model[row] := this.model[target]
        this.model[target] := tmp
        this.Refresh()
        this.lv.Modify(target, "Select Focus")
    }

    ; 提示框（暫時取消設定視窗最上層，避免被蓋住）
    Hint(msg) {
        this.gui.Opt("-AlwaysOnTop")
        MsgBox(msg, TITLE_HINT, "Icon!")
        this.gui.Opt("+AlwaysOnTop")
    }
}
