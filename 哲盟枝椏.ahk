#Requires AutoHotkey v2.0
;@Ahk2Exe-UpdateManifest 1
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
; 清單編輯：沒選取正式項目就按「刪除此項」時的提示
global MSG_PICK_ROW := "請先在上方清單中選擇你要刪除的項目。"
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
global LBL_NEW_ROW       := "＋ 點此新增…" ; 清單最下方固定的「新增列」顯示文字

; 設定表的按鈕文字
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
    {title: "電話無人接", code: "01"},
    {title: "另約派送日期", code: "ct"},
    {title: "客更改地址", code: "ca"},
    {title: "地址錯誤", code: "97"},
    {title: "收件人不在家", code: "36"},
    {title: "包裹破損包裝中", code: "bt"}
]
global DEFAULT_MONITOR := [
    {name: "北市外務", items: [
	{title: "01. 西-梁志強", code: "21192074"}, {title: "02. 西-溫正杭", code: "20240513"}, 
	{title: "03. 西-戴勝堂", code: "20250324"}, {title: "04. 東-郭香蘭", code: "20260305"}, 
	{title: "05. 東-趙克強", code: "20289041"}, {title: "06. 東-牟善賢", code: "20290022"}, 
	{title: "07. 東-詹益全", code: "20296021"}, {title: "08. 東-吳萌瑜", code: "20997092"},
	{title: "09. 東-鄒樂勳", code: "21005222"}, {title: "10. 東-蔡俊傑", code: "20240710"}, 
	{title: "11. 東-譚毓麟", code: "20200103"}
    ]},
    {name: "新北外務", items: [
	{title: "01. 中-林彥廷", code: "21094053"}, {title: "02. 中-高鄭旺", code: "20298022"}, 
	{title: "03. 中-蕭先財", code: "20903101"}, {title: "04. 中-陳育賓", code: "21002102"}, 
	{title: "05. 中-謝明憲", code: "20296012"}, {title: "06. 五-林茂競", code: "20997083"}, 
	{title: "07. 五-張振發", code: "20220418"}, {title: "08. 五-謝文川", code: "20250825"},
	{title: "09. 五-詹錫熏", code: "20251117"}, {title: "10. 五-施啟文", code: "20260602"}, 
	{title: "11. 五-黃雅萍", code: "20997082"}
    ]},
    {name: "六位外派", items: [
	{title: "機車快遞5", code: "MOTO5"}, {title: "機車快遞8", code: "MOTO8"}, 
	{title: "機車快遞10", code: "MOTO10"}, {title: "機車快遞12", code: "MOTO12"}, 
	{title: "機車快遞13", code: "MOTO13"}
    ]}
]

global DEFAULT_PASTETEXT := [
    {title: "另約 7/15 (三)", code: "客戶另約派送日期：7/15 (三)"},
    {title: "客戶更改收件地址：", code: "客戶更改收件地址："}
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

; --- 設定視窗外觀（純白底＋原生按鈕）---
global UI_FONT := "Microsoft JhengHei UI"
global CLR_TEXT := "1F2328"     ; 主文字
global CLR_MUTED := "57606A"    ; 次要說明文字（灰）

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
; 【設定視窗】純白底、全原生按鈕、四個分頁標籤等寬滿版
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

    ; +0x0400 = TCS_FIXEDWIDTH：分頁標籤改為固定等寬（實際寬度於視窗顯示後才量測套用，見 Show 之後的 SizeTabsEqually）
    g_tab := g_settingsGui.Add("Tab3", "x16 y16 w568 h508 -Background +0x0400",
        [TAB_SIGN, TAB_PROBLEM, TAB_MONITOR, TAB_PASTE])
    g_tab.SetFont("s10 bold", UI_FONT)     ; 分頁標題加粗（要先設好字型，之後量到的標籤高度才正確）

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
    ; 群組清單 w340，右側接三顆「新增/命名/刪除」，最右邊一欄放 ▲▼ 讓「群組本身」也能調整排列順序
    ; +0x100 = LBS_NOINTEGRALHEIGHT：強制清單高度等於 h106，下緣才會和右側按鈕齊平（同組元素）
    g_groupListBox := g_settingsGui.Add("ListBox", "x32 y76 w340 h106 +0x100 BackgroundWhite", [])
    g_groupListBox.OnEvent("Change", (*) => Monitor_OnGroupSelect())
    MakeButton(g_settingsGui, 380, 76, 140, 30, BTN_GRP_ADD).OnEvent("Click", (*) => Monitor_AddGroup())
    MakeButton(g_settingsGui, 380, 114, 140, 30, BTN_GRP_RENAME).OnEvent("Click", (*) => Monitor_RenameGroup())
    MakeButton(g_settingsGui, 380, 152, 140, 30, BTN_GRP_DELETE, "danger").OnEvent("Click", (*) => Monitor_DeleteGroup())
    ; 群組排序 ▲▼：放在三顆按鈕右側，上下兩顆各 h50、中間留 6px，下緣對齊清單（y76→y182）
    MakeButton(g_settingsGui, 528, 76, 40, 50, BTN_UP).OnEvent("Click", (*) => Monitor_MoveGroup(-1))
    MakeButton(g_settingsGui, 528, 132, 40, 50, BTN_DOWN).OnEvent("Click", (*) => Monitor_MoveGroup(1))
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

    ; 先以最終尺寸「建立但不顯示」視窗：此時控制項尺寸已定案且含 DPI 縮放，量測才可靠。
    ; 調整完分頁寬度後才真正顯示，畫面一次到位（不會有先畫錯再重繪造成的閃爍或補畫）。
    g_settingsGui.Show("Hide w600 h590")
    SizeTabsEqually(g_tab)
    g_settingsGui.Show()
}

; 讓分頁標籤等寬且佔滿整列
;   ．必須在 Show("Hide") 之後、真正 Show() 之前呼叫，量到的尺寸才正確且不會造成重繪問題
;   ．套用後會回頭驗證最後一個標籤有沒有超出可視範圍，超出就自動縮窄重試
;   ．任何一步量到異常值就直接放棄，退回原生自動寬度（四個標籤仍全部顯示，只是靠左），絕不弄壞版面
SizeTabsEqually(tab) {
    static TCM_GETITEMCOUNT := 0x1304, TCM_GETITEMRECT := 0x130A, TCM_SETITEMSIZE := 0x1329

    n := SendMessage(TCM_GETITEMCOUNT, 0, 0, tab)
    if (n < 1)
        return

    rc := Buffer(16, 0)
    if !DllCall("GetClientRect", "Ptr", tab.Hwnd, "Ptr", rc)
        return
    cw := NumGet(rc, 8, "Int")
    if (cw < 100)                 ; 尺寸異常（未實體化／被縮到極小）→ 放棄，維持原生寬度
        return

    SendMessage(TCM_GETITEMRECT, 0, rc.Ptr, tab)                 ; 取第一個標籤矩形（只拿高度）
    tabH := NumGet(rc, 12, "Int") - NumGet(rc, 4, "Int")
    if (tabH < 8 || tabH > 200)   ; 高度異常也放棄，避免送出垃圾值把標籤撐爆
        return

    ; 逐次加大預留邊距重試：不同 DPI／視覺樣式下，標籤本身的內部邊距不盡相同，
    ; 與其猜一個固定值，不如套用後直接量最後一個標籤是否超界，超界就縮窄再試。
    for pad in [4, 12, 20, 28, 40, 56] {
        tabW := (cw - pad) // n
        if (tabW < 1)
            return
        SendMessage(TCM_SETITEMSIZE, 0, (tabH << 16) | tabW, tab)   ; 寬在低 16 位、高在高 16 位
        SendMessage(TCM_GETITEMRECT, n - 1, rc.Ptr, tab)            ; 量最後一個標籤（索引從 0 起算）
        if (NumGet(rc, 8, "Int") <= cw)                             ; 右緣沒超出可視寬度 → 四個都塞得下，收工
            return
    }
}

; 分頁頂端的灰色說明文字（小一號字）
AddHint(g, x, y, w, text) {
    global CLR_MUTED
    h := g.Add("Text", "x" x " y" y " w" w, text)
    h.SetFont("s9 c" CLR_MUTED)
    return h
}

; 原生標準按鈕（與「本頁還原預設」「確認」同款，有按壓手感）
;   kind 參數保留以相容既有呼叫點；原生按鈕不支援自訂配色，故目前僅作語意標記。
MakeButton(g, x, y, w, h, label, kind := "secondary") {
    return g.Add("Button", "x" x " y" y " w" w " h" h, label)
}

; 確認：整理資料 → 寫回設定檔、重建選單
Settings_Confirm(*) {
    global g_config, g_work, g_settingsGui
    ; 寫回前整理：去除頭尾空白，並剔除「標題與內容皆空」的項目（即時編輯可能留下清空的列）
    g_work.sign := CleanList(g_work.sign)
    g_work.problem := CleanList(g_work.problem)
    g_work.pastetext := CleanList(g_work.pastetext)
    for grp in g_work.monitor {
        grp.name := Trim(grp.name)
        grp.items := CleanList(grp.items)
    }
    g_config := g_work
    SaveSettings()
    BuildMenu()
    g_settingsGui.Destroy()
    g_settingsGui := ""
}

; 去頭尾空白＋剔除全空項目，回傳整理後的新清單
CleanList(arr) {
    out := []
    for it in arr {
        t := Trim(it.title), c := Trim(it.code)
        if (t = "" && c = "")
            continue
        out.Push({title: t, code: c})
    }
    return out
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

Monitor_MoveGroup(dir) {
    global g_work, g_groupListBox
    idx := g_groupListBox.Value
    if (idx < 1)
        return
    target := idx + dir
    if (target < 1 || target > g_work.monitor.Length)
        return
    ; 整個群組物件（含 name 與 items）一起交換，故群組內項目與未提交的編輯都不會遺失
    tmp := g_work.monitor[idx]
    g_work.monitor[idx] := g_work.monitor[target]
    g_work.monitor[target] := tmp
    Monitor_RefreshGroups(target)   ; 重畫並選回移動後的位置，下方項目清單也會跟著切到同一群組
}

; ==============================================================================
; 【系統列(托盤)選單】
; ==============================================================================
SetupTray() {
    A_TrayMenu.Insert("1&", TRAY_SETTINGS, (*) => ShowSettings())
    A_TrayMenu.Insert("2&")     ; 分隔線
    OnMessage(0x404, Tray_OnIconClick)   ; 0x404 = AHK 系統列圖示的通知訊息；讓左鍵單擊也能開啟編輯區
}

; 系統列圖示滑鼠事件：左鍵放開時開啟編輯區（右鍵選單、雙擊維持 AHK 預設，不受影響）
Tray_OnIconClick(wParam, lParam, msg, hwnd) {
    if (lParam = 0x202)   ; WM_LBUTTONUP
        ShowSettings()
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
; 【清單編輯元件】ListView + 兩列編輯欄 + 按鈕列，可變數量
;   ．清單最下方固定有一列「＋ 點此新增…」：點它之後直接在下方編輯欄輸入即可新增項目
;   ．編輯欄一有變動就「即時」寫回清單與暫存副本（g_work）；最後仍須按「確認」才存檔生效
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

        ; 編輯欄一有變動就即時套用（在「新增列」上輸入則自動長出新項目）
        this.titleEdit.OnEvent("Change", (*) => this.OnEdit())
        this.codeEdit.OnEvent("Change", (*) => this.OnEdit())

        ; --- 按鈕列：「刪除此項」吃掉主要寬度，兩顆箭頭固定 40px，排滿整列 ---
        contentBoxH := multiline ? contentH : 23
        by := ly2 + 22 + contentBoxH + 17
        gap := 8, arrowW := 40
        delW := w - 2*arrowW - 2*gap
        MakeButton(g, x, by, delW, 32, BTN_DELETE, "danger").OnEvent("Click", (*) => this.DeleteRow())
        MakeButton(g, x + delW + gap, by, arrowW, 32, BTN_UP).OnEvent("Click", (*) => this.MoveRow(-1))
        MakeButton(g, x + delW + gap + arrowW + gap, by, arrowW, 32, BTN_DOWN).OnEvent("Click", (*) => this.MoveRow(1))
    }

    ; 換綁定的資料陣列並重畫（簽收監控切換群組時會用到）
    SetModel(arr) {
        this.model := arr
        this.Refresh()
        this.titleEdit.Value := ""
        this.codeEdit.Value := ""
    }

    ; 重畫整個清單；最下方固定補一列「新增列」
    Refresh() {
        this.lv.Delete()
        for it in this.model
            this.lv.Add("", it.title, this.Preview(it.code))   ; 清單只顯示單行預覽（換行壓成空白）
        this.lv.Add("", LBL_NEW_ROW, "")
        this.lv.ModifyCol(2, "AutoHdr")   ; 依目前列數/捲軸狀態重算內容欄寬，確保填滿、右側不留白
    }

    ; 清單欄位預覽：把換行壓成空白，避免多行內容在格子裡顯示成方塊
    Preview(s) {
        s := StrReplace(s, "`r`n", " ")
        s := StrReplace(s, "`r", " ")
        s := StrReplace(s, "`n", " ")
        return s
    }

    ; 該列是否為最下方的「新增列」（不在 model 範圍內的那一列）
    IsNewRow(row) => (row > this.model.Length)

    ; 點選某列 → 把內容載入下方編輯欄（點「新增列」則清空編輯欄）
    OnSelect() {
        row := this.lv.GetNext()
        if !row
            return
        t := this.IsNewRow(row) ? "" : this.model[row].title
        c := this.IsNewRow(row) ? "" : NormCRLF(this.model[row].code)
        ; 內容相同就不重設——程式自己觸發的選取（如新增列轉正後）若無條件重設，
        ; 會把使用者打字到一半的游標位置弄跑
        if (this.titleEdit.Value == t && NormCRLF(this.codeEdit.Value) == c)
            return
        this.titleEdit.Value := t
        this.codeEdit.Value := c
    }

    ; 即時套用：把編輯欄目前內容寫回選取列；在「新增列」上輸入第一個字時自動轉為正式項目
    OnEdit() {
        row := this.lv.GetNext()
        if !row {
            ; 沒選取任何列就開始打字 → 視同在「新增列」輸入（但全空白時不動作）
            if (Trim(this.titleEdit.Value) = "" && Trim(this.codeEdit.Value) = "")
                return
            row := this.model.Length + 1
            this.lv.Modify(row, "Select Focus")
        }
        t := this.titleEdit.Value
        c := this.codeEdit.Value
        if this.IsNewRow(row) {
            if (Trim(t) = "" && Trim(c) = "")
                return                                        ; 都還是空的，先不長出項目
            this.model.Push({title: t, code: c})
            this.lv.Modify(row, "", t, this.Preview(c))       ; 新增列「轉正」
            this.lv.Add("", LBL_NEW_ROW, "")                  ; 底部補回一列新增列
            this.lv.ModifyCol(2, "AutoHdr")
        } else {
            this.model[row].title := t
            this.model[row].code := c
            this.lv.Modify(row, "", t, this.Preview(c))       ; 局部更新該列即可，不整份重畫（避免閃爍與選取跳掉）
        }
    }

    DeleteRow() {
        row := this.lv.GetNext()
        if (!row || this.IsNewRow(row)) {
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
        if (!row || this.IsNewRow(row))
            return
        target := row + dir
        if (target < 1 || target > this.model.Length)     ; 「新增列」永遠固定在最下方，不參與排序
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
