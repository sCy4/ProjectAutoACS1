#Requires AutoHotkey v2.0
#Include UIA.ahk

; ==============================================================================
; ★【可自行修改區】平常維護主要改這上半段就好★
; ==============================================================================

; --- 按鍵延遲 ---
global SysDelay := 60
global SysSleep := 50

; --- 提示與警示訊息（可自由修改文字）---
global MSG_TITLE := "哲盟枝椏"
; 游標不在正確的視窗/欄位時的警示；{1} 會替換成下面對應的欄位說明
global MSG_WRONG_FIELD := "尚未在正確的視窗點選正確的輸入欄位，已取消執行。`n`n請先用滑鼠點一下{1}，再執行此功能。"
global MSG_FIELD_SIGN    := "「簽收」視窗中的單號欄位"
global MSG_FIELD_PROBLEM := "「問題件管理」視窗中的單號欄位"
global MSG_FIELD_MONITOR := "「簽收監控」視窗中的輸入欄位"
; 清單編輯：沒選取列就按「保存修改／刪除此項」時的提示
global MSG_PICK_ROW := "請先在上方清單點選一列。"
; 刪除群組的二次確認；{1} 會替換成群組名稱
global MSG_DELETE_GROUP := "確定要刪除群組「{1}」？`n群組內的所有項目也會一併刪除。"
; 新增／重新命名群組的輸入框提示
global MSG_ADD_GROUP_PROMPT    := "請輸入新群組名稱："
global MSG_RENAME_GROUP_PROMPT := "請輸入新的群組名稱："

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
    {title: "1. 已簽收",            code: "已簽收"},
    {title: "2. 櫃台簽收",          code: "櫃台簽收"},
    {title: "3. 已放置客戶指定位置", code: "已放置客戶指定位置"}
]
global DEFAULT_PROBLEM := [
    {title: "1. 電話無人接",        code: "01"},
    {title: "2. 收件人另約派送日期", code: "ct"},
    {title: "3. 地址錯誤",          code: "97"},
    {title: "4. 收件人更改派送地址", code: "ca"},
    {title: "5. 收件人不在家",      code: "36"}
]
global DEFAULT_MONITOR := [
    {name: "北市十位外務", items: [
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
; ==============================================================================
; ★【可自行修改區結束】以下為程式邏輯，非必要不用動★
; ==============================================================================

global g_config := ""        ; 目前生效的設定 {sign, problem, monitor}
global g_work := ""          ; 設定視窗的暫存編輯副本（按「確認」才寫回 g_config）

global AnythingMenu := ""    ; 主選單（每次設定變更後重建）
global g_subMenus := []      ; 保留監控子選單參考，避免被回收

; 設定視窗的物件參考
global g_settingsGui := ""
global g_tab := ""
global g_signEditor := ""
global g_problemEditor := ""
global g_monitorEditor := ""
global g_groupListBox := ""

; --- 設定視窗外觀（GitHub 淺色風格）---
global UI_FONT := "Microsoft JhengHei UI"
global CLR_TEXT := "1F2328"     ; 主文字
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
; 【選單建立】
; ==============================================================================
BuildMenu() {
    global AnythingMenu, g_subMenus, g_config

    AnythingMenu := Menu()
    g_subMenus := []
    anyAdded := false

    ; ◎ 快速簽收
    if HasVisible(g_config.sign) {
        AddHeader(AnythingMenu, "◎ 快速簽收")
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
        AddHeader(AnythingMenu, "◎ 快速問題")
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
        AddHeader(AnythingMenu, "◎ 簽收監控人員捷徑")
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

    if !anyAdded
        AddHeader(AnythingMenu, "（尚未設定任何項目，請從右下角圖示開啟設定）")
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
; ==============================================================================
LoadSettings() {
    global g_config, INI_PATH
    if !FileExist(INI_PATH) {
        g_config := DefaultConfig()
        return
    }
    g_config := {sign: ReadList("Sign"), problem: ReadList("Problem"), monitor: ReadMonitor()}
}

ReadList(section) {
    global INI_PATH
    out := []
    count := Integer(IniRead(INI_PATH, section, "Count", "0"))
    Loop count {
        t := IniRead(INI_PATH, section, "Title" A_Index, "")
        c := IniRead(INI_PATH, section, "Code" A_Index, "")
        out.Push({title: t, code: c})
    }
    return out
}

ReadMonitor() {
    global INI_PATH
    out := []
    gc := Integer(IniRead(INI_PATH, "Monitor", "GroupCount", "0"))
    Loop gc {
        sec := "Monitor.Group" A_Index
        name := IniRead(INI_PATH, sec, "Name", "")
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
}

WriteList(section, list) {
    global INI_PATH
    IniWrite(list.Length, INI_PATH, section, "Count")
    for i, it in list {
        IniWrite(it.title, INI_PATH, section, "Title" i)
        IniWrite(it.code, INI_PATH, section, "Code" i)
    }
}

WriteMonitor(groups) {
    global INI_PATH
    IniWrite(groups.Length, INI_PATH, "Monitor", "GroupCount")
    for i, grp in groups {
        sec := "Monitor.Group" i
        IniWrite(grp.name, INI_PATH, sec, "Name")
        IniWrite(grp.items.Length, INI_PATH, sec, "Count")
        for j, it in grp.items {
            IniWrite(it.title, INI_PATH, sec, "Title" j)
            IniWrite(it.code, INI_PATH, sec, "Code" j)
        }
    }
}

; 寫入前先清掉舊區段，避免項目（或群組）數量變少時殘留舊資料
ClearOldSections() {
    global INI_PATH
    IniDelete(INI_PATH, "Sign")
    IniDelete(INI_PATH, "Problem")
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
    return {sign: CloneList(cfg.sign), problem: CloneList(cfg.problem), monitor: CloneGroups(cfg.monitor)}
}

DefaultConfig() {
    global DEFAULT_SIGN, DEFAULT_PROBLEM, DEFAULT_MONITOR
    return {sign: CloneList(DEFAULT_SIGN), problem: CloneList(DEFAULT_PROBLEM), monitor: CloneGroups(DEFAULT_MONITOR)}
}

; ==============================================================================
; 【設定視窗】GitHub 淺色風格：白底、扁平化分頁內按鈕、原生外圍按鈕
; ==============================================================================
ShowSettings(*) {
    global g_settingsGui, g_work, g_config, g_tab
    global g_signEditor, g_problemEditor, g_monitorEditor, g_groupListBox
    global UI_FONT, CLR_TEXT

    ; 視窗已開著就帶到前景，不重複開
    if (g_settingsGui != "" && WinExist("ahk_id " g_settingsGui.Hwnd)) {
        g_settingsGui.Show()
        return
    }

    g_work := CloneConfig(g_config)

    g_settingsGui := Gui("+AlwaysOnTop", MSG_TITLE " - 設定")
    g_settingsGui.BackColor := "FFFFFF"
    g_settingsGui.SetFont("s10 c" CLR_TEXT, UI_FONT)

    g_tab := g_settingsGui.Add("Tab3", "x16 y16 w520 h508 -Background", ["快速簽收", "快速問題", "簽收監控人員捷徑"])
    g_tab.SetFont("s10 bold", UI_FONT)     ; 分頁標題加粗

    ; --- 分頁1：快速簽收 ---
    g_tab.UseTab(1)
    g_signEditor := ListEditor(g_settingsGui, 32, 60, 488, 280, "輸入文字")
    g_signEditor.SetModel(g_work.sign)

    ; --- 分頁2：快速問題 ---
    g_tab.UseTab(2)
    g_problemEditor := ListEditor(g_settingsGui, 32, 60, 488, 280, "代碼")
    g_problemEditor.SetModel(g_work.problem)

    ; --- 分頁3：簽收監控人員捷徑 ---
    g_tab.UseTab(3)
    g_groupListBox := g_settingsGui.Add("ListBox", "x32 y60 w340 h106 BackgroundWhite", [])
    g_groupListBox.OnEvent("Change", (*) => Monitor_OnGroupSelect())
    MakeButton(g_settingsGui, 380, 60, 140, 30, "新增群組").OnEvent("Click", (*) => Monitor_AddGroup())
    MakeButton(g_settingsGui, 380, 98, 140, 30, "重新命名").OnEvent("Click", (*) => Monitor_RenameGroup())
    MakeButton(g_settingsGui, 380, 136, 140, 30, "刪除群組", "danger").OnEvent("Click", (*) => Monitor_DeleteGroup())
    g_monitorEditor := ListEditor(g_settingsGui, 32, 186, 488, 150, "代碼")
    Monitor_RefreshGroups(1)

    ; --- 底部共用按鈕（原生按鈕）---
    g_tab.UseTab(0)
    g_settingsGui.Add("Button", "x16 y540 w130 h34", "本頁還原預設").OnEvent("Click", Settings_RestoreDefault)
    g_settingsGui.Add("Button", "x346 y540 w90 h34", "取消").OnEvent("Click", Settings_Cancel)
    g_settingsGui.Add("Button", "x446 y540 w90 h34 Default", "確認").OnEvent("Click", Settings_Confirm)

    g_settingsGui.OnEvent("Close", Settings_Cancel)
    g_settingsGui.OnEvent("Escape", Settings_Cancel)

    g_settingsGui.Show("w552 h590")
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
    global g_work, g_tab, g_signEditor, g_problemEditor
    global DEFAULT_SIGN, DEFAULT_PROBLEM, DEFAULT_MONITOR
    t := g_tab.Value
    if (t = 1) {
        g_work.sign := CloneList(DEFAULT_SIGN)
        g_signEditor.SetModel(g_work.sign)
    } else if (t = 2) {
        g_work.problem := CloneList(DEFAULT_PROBLEM)
        g_problemEditor.SetModel(g_work.problem)
    } else {
        g_work.monitor := CloneGroups(DEFAULT_MONITOR)
        Monitor_RefreshGroups(1)
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
        names.Push(grp.name = "" ? "（未命名）" : grp.name)
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
    ib := InputBox(MSG_ADD_GROUP_PROMPT, "新增群組", "w300 h130")
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
    ib := InputBox(MSG_RENAME_GROUP_PROMPT, "重新命名群組", "w300 h130", g_work.monitor[idx].name)
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
    ans := MsgBox(StrReplace(MSG_DELETE_GROUP, "{1}", g_work.monitor[idx].name), "刪除群組", "YesNo Icon!")
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
    A_TrayMenu.Insert("1&", "設定", (*) => ShowSettings())
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
; 【選單動作函式】各動作執行前先過防錯檢查
; ==============================================================================
Action_Sign(category, *) {
    if !FocusedEditInWindow(GUARD_SIGN.class, GUARD_SIGN.win) {
        WarnWrongField(MSG_FIELD_SIGN)
        return
    }
    SetKeyDelay SysDelay * 0.6
    SendEvent "{End}+{Home}^v{Tab 3}"
    SendText category
    Sleep SysSleep
    SendEvent "{Enter}"
}

Action_PP(Ptype, *) {
    if !FocusedEditInWindow(GUARD_PROBLEM.class, GUARD_PROBLEM.win) {
        WarnWrongField(MSG_FIELD_PROBLEM)
        return
    }
    SavedClip := ClipboardAll()
    SetKeyDelay SysDelay
    SendEvent "{End}+{Home}^v{Tab}{Up}{Down 2}{Tab}"
    Sleep SysSleep
    SendText Ptype
    Sleep SysSleep
    SendEvent "{Enter}+{Tab}^c{Tab}{End}+{Home}^v{F3}"
    Sleep SysSleep * 5
    A_Clipboard := SavedClip
    SavedClip := ""
}

Action_TPC(Cnumber, *) {
    if !FocusedEditInWindow(GUARD_MONITOR.class, GUARD_MONITOR.win) {
        WarnWrongField(MSG_FIELD_MONITOR)
        return
    }
    SetKeyDelay SysDelay
    SendEvent "{Tab}{Enter}"
    Sleep SysSleep
    SendText Cnumber
    Sleep SysSleep
    SendEvent "{Enter 2}"
}

; ==============================================================================
; 【清單編輯元件】ListView + 兩列編輯欄 + 滿版按鈕列，可變數量
; ==============================================================================
class ListEditor {
    model := []
    gui := ""
    lv := ""
    titleEdit := ""
    codeEdit := ""

    __New(g, x, y, w, lvH, col2Label) {
        this.gui := g

        ; --- 清單 ---
        this.lv := g.Add("ListView", "x" x " y" y " w" w " h" lvH " Grid BackgroundWhite", ["標題", col2Label])
        this.lv.ModifyCol(1, w - 150)
        this.lv.ModifyCol(2, 126)
        this.lv.OnEvent("ItemSelect", (*) => this.OnSelect())

        ; --- 兩列編輯欄：標題一列、代碼/輸入文字一列（欄位滿版，文字不再擠出框外）---
        ly1 := y + lvH + 14
        g.Add("Text", "x" x " y" ly1 " w" w, "標題")
        this.titleEdit := g.Add("Edit", "x" x " y" (ly1 + 22) " w" w)
        ly2 := ly1 + 60
        g.Add("Text", "x" x " y" ly2 " w" w, col2Label)
        this.codeEdit := g.Add("Edit", "x" x " y" (ly2 + 22) " w" w)

        ; --- 按鈕列：前三顆等寬、後兩顆箭頭固定 40px，五顆排滿整列、右邊不留白 ---
        by := ly2 + 62
        gap := 8, arrowW := 40
        eqW := (w - 2*arrowW - 4*gap) // 3
        lastEqW := w - 2*arrowW - 4*gap - 2*eqW     ; 餘數補到第三顆，確保剛好滿版
        x1 := x
        x2 := x1 + eqW + gap
        x3 := x2 + eqW + gap
        x4 := x3 + lastEqW + gap
        x5 := x4 + arrowW + gap
        MakeButton(g, x1, by, eqW, 32, "新增").OnEvent("Click", (*) => this.AddRow())
        MakeButton(g, x2, by, eqW, 32, "保存修改").OnEvent("Click", (*) => this.UpdateRow())
        MakeButton(g, x3, by, lastEqW, 32, "刪除此項", "danger").OnEvent("Click", (*) => this.DeleteRow())
        MakeButton(g, x4, by, arrowW, 32, "▲").OnEvent("Click", (*) => this.MoveRow(-1))
        MakeButton(g, x5, by, arrowW, 32, "▼").OnEvent("Click", (*) => this.MoveRow(1))
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
            this.lv.Add("", it.title, it.code)
    }

    ; 點選某列 → 把內容載入下方編輯欄
    OnSelect() {
        row := this.lv.GetNext()
        if !row
            return
        this.titleEdit.Value := this.model[row].title
        this.codeEdit.Value := this.model[row].code
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
        MsgBox(msg, "提示", "Icon!")
        this.gui.Opt("+AlwaysOnTop")
    }
}
