#NoEnv
#SingleInstance Force
SetBatchLines, -1

NotesDir := A_MyDocuments "\Fines Notes"
if !InStr(FileExist(NotesDir), "D")
    FileCreateDir, %NotesDir%

NotesFile := NotesDir "\finnotes_data.txt"
OldNotesFile := A_ScriptDir "\fines_notes_v2.txt"

if FileExist(OldNotesFile) {
    if !FileExist(NotesFile)
        FileMove, %OldNotesFile%, %NotesFile%, 1
}

if !FileExist(NotesFile)
    FileAppend, , %NotesFile%, UTF-8

QuickHtmlPath := A_Temp "\fines_quick_ui.html"
BoardHtmlPath := A_Temp "\fines_board_ui.html"

ActiveContext := "Система"
QuickGuiOpen := 0
BoardGuiOpen := 0

Menu, Tray, NoStandard
Menu, Tray, Add, Новая заметка (Alt + V), OpenQuickNote
Menu, Tray, Add, Все заметки (Alt + B), OpenBoard
Menu, Tray, Add
Menu, Tray, Add, Открыть папку с данными, OpenDataFolder
Menu, Tray, Add, Выход, GuiClose

; Включаем нормальную работу Enter, Ctrl+Enter и клавиш редактирования внутри ActiveX
OnMessage(0x0100, "WB_KeyHandler")
OnMessage(0x0104, "WB_KeyHandler")

GoSub, OpenBoard
return

WB_KeyHandler(wParam, lParam, msg, hwnd) {
    global WBQuick, QuickGuiOpen
    if (QuickGuiOpen = 1) {
        if (wParam = 27) { ; Esc
            SetTimer, DoQuickCancel, -10
            return 0
        }
        if (wParam = 13 && GetKeyState("Ctrl", "P")) { ; Ctrl + Enter
            SetTimer, DoQuickSave, -10
            return 0
        }
        try {
            pipa := ComObjQuery(WBQuick, "{00000117-0000-0000-C000-000000000046}")
            VarSetCapacity(kMsg, 48)
            NumPut(hwnd, kMsg)
            NumPut(msg, kMsg, A_PtrSize)
            NumPut(wParam, kMsg, A_PtrSize * 2)
            NumPut(lParam, kMsg, A_PtrSize * 3)
            r := DllCall(NumGet(NumGet(1*pipa) + 5 * A_PtrSize), "Ptr", pipa, "Ptr", &kMsg)
            ObjRelease(pipa)
            if (r = 0)
                return 0
        }
    }
}

OpenDataFolder:
    Run, explorer.exe "%NotesDir%"
return

!v::
OpenQuickNote:
    if (QuickGuiOpen = 1) {
        WinActivate, FinesQuickInput
        return
    }
    WinGetTitle, WinTitle, A
    WinGet, ProcName, ProcessName, A
    StringReplace, ProcClean, ProcName, .exe, , All
    if (WinTitle != "" && ProcClean != "AutoHotkey" && ProcClean != "FinNotes")
        ActiveContext := ProcClean
    else
        ActiveContext := "Система"

    QuickGuiOpen := 1

    quickHtml =
    ( %
    <!DOCTYPE html>
    <html>
    <head>
    <meta charset="UTF-8">
    <meta http-equiv="X-UA-Compatible" content="IE=edge">
    <style>
        body {
            background-color: #121212;
            color: #ffffff;
            font-family: 'Segoe UI', sans-serif;
            margin: 0;
            padding: 16px;
            overflow: hidden;
            -ms-user-select: none;
            user-select: none;
            border: 1px solid #2e2e2e;
            box-sizing: border-box;
            height: 100vh;
        }
        .top-bar {
            font-size: 13px;
            font-weight: bold;
            color: #87CEEB;
            margin-bottom: 12px;
            letter-spacing: 0.5px;
        }
        .editor {
            width: 100%;
            height: 220px;
            background-color: #1e1e1e;
            border: 1px solid #383838;
            border-radius: 6px;
            color: #ffffff;
            font-family: 'Segoe UI', sans-serif;
            font-size: 14px;
            line-height: 1.5;
            padding: 12px;
            box-sizing: border-box;
            resize: none;
            outline: none;
        }
        .editor:focus {
            border-color: #87CEEB;
        }
        .bottom-bar {
            margin-top: 14px;
            text-align: right;
        }
        .hint {
            float: left;
            font-size: 11px;
            color: #666666;
            line-height: 32px;
        }
        .btn {
            display: inline-block;
            padding: 7px 20px;
            border-radius: 6px;
            font-size: 13px;
            font-weight: bold;
            cursor: pointer;
            margin-left: 8px;
        }
        .btn-save {
            background-color: #87CEEB;
            color: #121212;
            border: 1px solid #87CEEB;
        }
        .btn-cancel {
            background-color: #1e1e1e;
            color: #cccccc;
            border: 1px solid #3d3d3d;
        }
    </style>
    <script>
        function doSave() {
            document.title = "qcmd:save";
        }
        function doCancel() {
            document.title = "qcmd:cancel";
        }
        window.onload = function() {
            document.getElementById('noteArea').focus();
        };
    </script>
    </head>
    <body>
        <div id="ctxBar" class="top-bar">FINNOTES</div>
        <textarea id="noteArea" class="editor" placeholder="Пиши заметку здесь... Enter — новый абзац"></textarea>
        <div class="bottom-bar">
            <span class="hint">Enter — абзац | Ctrl+Enter — сохранить | Esc — отмена</span>
            <span class="btn btn-save" onclick="doSave()">Сохранить</span>
            <span class="btn btn-cancel" onclick="doCancel()">Отмена</span>
        </div>
    </body>
    </html>
    )

    FileDelete, %QuickHtmlPath%
    FileAppend, %quickHtml%, %QuickHtmlPath%, UTF-8

    Gui, Quick:New, -DPIScale -Caption +AlwaysOnTop
    Gui, Quick:Color, 121212
    Gui, Quick:Margin, 0, 0
    Gui, Quick:Add, ActiveX, w540 h320 vWBQuick, Shell.Explorer
    WBQuick.Silent := True
    WBQuick.Navigate(QuickHtmlPath)
    while WBQuick.ReadyState != 4
        Sleep, 10

    try WBQuick.Document.getElementById("ctxBar").innerHTML := "FINNOTES &nbsp;|&nbsp; Контекст: [" . ActiveContext . "]"

    SetTimer, WatchQuickCmd, 60
    Gui, Quick:Show, w540 h320 Center, FinesQuickInput
    WinActivate, FinesQuickInput
    try WBQuick.Document.getElementById("noteArea").focus()
return

WatchQuickCmd:
    if (QuickGuiOpen = 0)
        return
    try {
        qTitle := WBQuick.Document.title
        if (qTitle = "qcmd:cancel") {
            GoSub, DoQuickCancel
        }
        else if (qTitle = "qcmd:save") {
            GoSub, DoQuickSave
        }
    }
return

DoQuickCancel:
    if (QuickGuiOpen = 0)
        return
    SetTimer, WatchQuickCmd, Off
    Gui, Quick:Destroy
    QuickGuiOpen := 0
return

DoQuickSave:
    if (QuickGuiOpen = 0)
        return
    SetTimer, WatchQuickCmd, Off
    RawText := ""
    try RawText := WBQuick.Document.getElementById("noteArea").value
    Gui, Quick:Destroy
    QuickGuiOpen := 0

    CleanText := Trim(RawText, " `t`r`n")
    if (CleanText != "") {
        StringReplace, CleanText, CleanText, |, /, All
        StringReplace, CleanText, CleanText, §, , All
        StringReplace, CleanText, CleanText, `r`n, \n, All
        StringReplace, CleanText, CleanText, `n, \n, All

        FormatTime, TimeStr, , dd.MM.yyyy HH:mm
        DefaultTitle := "Заметка [" . ActiveContext . "]"
        Record := DefaultTitle . "|" . TimeStr . "|" . CleanText . "§"
        FileAppend, %Record%, %NotesFile%, UTF-8
        SoundBeep, 1000, 90
    }
    GoSub, OpenBoard
return



!b::
    GoSub, OpenBoard
return

OpenBoard:
    if (BoardGuiOpen = 1) {
        GoSub, RefreshBoardData
        Gui, Board:Show, w715 h540, FinNotes
        WinActivate, FinNotes
        return
    }
    BoardGuiOpen := 1

    Gui, Board:New, -DPIScale
    Gui, Board:Color, 121212
    Gui, Board:Margin, 0, 0
    Gui, Board:Add, ActiveX, w715 h540 vWBBoard, Shell.Explorer
    WBBoard.Silent := True

    GoSub, RefreshBoardData

    SetTimer, WatchBoardCmd, 100
    Gui, Board:Show, w715 h540, FinNotes
    WinActivate, FinNotes
return

RefreshBoardData:
    FileRead, RawData, *P65001 %NotesFile%
    CardsHtml := ""

    if (Trim(RawData, " `t`r`n§") = "") {
        CardsHtml := "<div class='empty'>Заметок пока нет. Нажми <b>Alt + V</b> или кнопку «+ Новая заметка».</div>"
    } else {
        Items := StrSplit(RawData, "§")
        MaxIdx := Items.Length()
        Loop, %MaxIdx%
        {
            idx := MaxIdx - A_Index + 1
            it := Items[idx]
            if (it = "")
                continue
            Parts := StrSplit(it, "|")
            nTitle := Parts.1
            nDate := Parts.2
            nBody := Parts.3

            StringReplace, nTitle, nTitle, &amp;, &, All
            StringReplace, nTitle, nTitle, &, &amp;, All
            StringReplace, nTitle, nTitle, ", &quot;, All
            StringReplace, nTitle, nTitle, <, &lt;, All
            StringReplace, nTitle, nTitle, >, &gt;, All

            StringReplace, nBody, nBody, &, &amp;, All
            StringReplace, nBody, nBody, <, &lt;, All
            StringReplace, nBody, nBody, >, &gt;, All
            StringReplace, nBody, nBody, \n, <br>, All

            jsIdx := idx - 1
            CardsHtml .= "<div class='card'>"
            CardsHtml .= "<div class='card-head'>"
            CardsHtml .= "<input class='title-input' type='text' value=""" . nTitle . """ placeholder='*введите название*' onchange='saveTitle(" . jsIdx . ", this)'>"
            CardsHtml .= "<span class='card-date'>(" . nDate . ")</span>"
            CardsHtml .= "</div>"
            CardsHtml .= "<div class='card-body'>" . nBody . "</div>"
            CardsHtml .= "<div class='card-foot'>"
            CardsHtml .= "<span class='mini-btn' onclick=""sendCmd('copy:" . jsIdx . "')"">Копировать</span>"
            CardsHtml .= "<span class='mini-btn del-btn' onclick=""sendCmd('del:" . jsIdx . "')"">Удалить</span>"
            CardsHtml .= "</div></div>"
        }
    }

    boardHtml =
    ( %
    <!DOCTYPE html>
    <html>
    <head>
    <meta charset="UTF-8">
    <meta http-equiv="X-UA-Compatible" content="IE=edge">
    <style>
        body { background-color: #121212; color: #ffffff; font-family: 'Segoe UI', sans-serif; margin: 0; padding: 0; -ms-user-select: none; user-select: none; overflow-x: hidden; }
        .header-bar { background-color: #181818; border-bottom: 2px solid #2e2e2e; padding: 14px 22px; height: 28px; }
        .header-title { float: left; font-size: 18px; font-weight: 800; color: #87CEEB; letter-spacing: 1px; line-height: 28px; }
        .header-actions { float: right; }
        .btn-top { background-color: #222222; border: 1px solid #3d3d3d; color: #ffffff; padding: 5px 14px; border-radius: 6px; font-size: 12px; font-weight: bold; cursor: pointer; margin-left: 6px; display: inline-block; }
        .btn-top:hover { border-color: #87CEEB; color: #87CEEB; }
        .grid { padding: 18px; }
        .card { float: left; width: 325px; height: 230px; background-color: #1a1a1a; border: 2px solid #333333; border-radius: 8px; margin: 0 14px 16px 0; box-sizing: border-box; position: relative; }
        .card:hover { border-color: #87CEEB; }
        .card-head { border-bottom: 2px solid #2e2e2e; padding: 8px 10px; height: 24px; background-color: #202020; border-radius: 6px 6px 0 0; }
        .title-input { float: left; width: 155px; background: transparent; border: none; border-bottom: 1px dashed #555555; color: #ffffff; font-family: 'Segoe UI', sans-serif; font-size: 13px; font-weight: bold; outline: none; padding: 1px 2px; }
        .title-input:focus { border-bottom: 1px solid #87CEEB; color: #87CEEB; }
        .card-date { float: right; font-size: 11px; color: #888888; line-height: 22px; }
        .card-body { padding: 10px 12px; height: 145px; overflow-y: auto; font-size: 13px; color: #e0e0e0; line-height: 1.45; word-wrap: break-word; -ms-user-select: text; user-select: text; }
        .card-foot { position: absolute; bottom: 6px; right: 8px; }
        .mini-btn { background-color: #252525; border: 1px solid #3d3d3d; color: #aaaaaa; padding: 2px 8px; border-radius: 4px; font-size: 11px; cursor: pointer; margin-left: 4px; }
        .mini-btn:hover { color: #87CEEB; border-color: #87CEEB; }
        .del-btn:hover { color: #ff4444; border-color: #ff4444; }
        .empty { text-align: center; color: #666666; margin-top: 120px; font-size: 15px; }
    </style>
    <script>
        var renameIdx = -1;
        var renameVal = "";
        function sendCmd(c) { document.title = "bcmd:" + c; }
        function saveTitle(idx, inputEl) {
            renameIdx = idx;
            renameVal = inputEl.value;
            document.title = "bcmd:rename";
        }
    </script>
    </head>
    <body>
        <div class="header-bar">
            <div class="header-title">ЗАМЕТКИ</div>
            <div class="header-actions">
                <span class="btn-top" onclick="sendCmd('new')">+ Новая заметка (Alt+V)</span>
                <span class="btn-top" onclick="sendCmd('clear')">Очистить все</span>
            </div>
        </div>
        <div class="grid">CARDS_PLACEHOLDER</div>
    </body>
    </html>
    )

    StringReplace, FinalHtml, boardHtml, CARDS_PLACEHOLDER, %CardsHtml%, All
    FileDelete, %BoardHtmlPath%
    FileAppend, %FinalHtml%, %BoardHtmlPath%, UTF-8
    WBBoard.Navigate(BoardHtmlPath)
return

WatchBoardCmd:
    if (BoardGuiOpen = 0)
        return
    try {
        bTitle := WBBoard.Document.title
        if (bTitle = "" || bTitle = "about:blank")
            return
        if InStr(bTitle, "bcmd:") {
            cmd := SubStr(bTitle, 6)
            WBBoard.Document.title := ""

            if (cmd = "new") {
                GoSub, OpenQuickNote
            }
            else if (cmd = "clear") {
                FileDelete, %NotesFile%
                FileAppend, , %NotesFile%, UTF-8
                GoSub, RefreshBoardData
                SoundBeep, 600, 120
            }
            else if (cmd = "rename") {
                rIdx := WBBoard.Document.parentWindow.renameIdx + 1
                newTitle := WBBoard.Document.parentWindow.renameVal
                StringReplace, newTitle, newTitle, |, /, All
                StringReplace, newTitle, newTitle, §, , All
                if (Trim(newTitle) = "")
                    newTitle := "Без названия"

                FileRead, RawData, *P65001 %NotesFile%
                Items := StrSplit(RawData, "§")
                NewFile := ""
                for i, it in Items {
                    if (it = "")
                        continue
                    if (i = rIdx) {
                        Parts := StrSplit(it, "|")
                        NewFile .= newTitle . "|" . Parts.2 . "|" . Parts.3 . "§"
                    } else {
                        NewFile .= it . "§"
                    }
                }
                FileDelete, %NotesFile%
                FileAppend, %NewFile%, %NotesFile%, UTF-8
                SoundBeep, 900, 70
            }
            else if InStr(cmd, "copy:") {
                cIdx := SubStr(cmd, 6) + 1
                FileRead, RawData, *P65001 %NotesFile%
                Items := StrSplit(RawData, "§")
                if (Items.HasKey(cIdx) && Items[cIdx] != "") {
                    Parts := StrSplit(Items[cIdx], "|")
                    txt := Parts.3
                    StringReplace, txt, txt, \n, `r`n, All
                    Clipboard := txt
                    SoundBeep, 1200, 100
                }
            }
            else if InStr(cmd, "del:") {
                dIdx := SubStr(cmd, 5) + 1
                FileRead, RawData, *P65001 %NotesFile%
                Items := StrSplit(RawData, "§")
                NewFile := ""
                for i, it in Items {
                    if (i != dIdx && it != "")
                        NewFile .= it . "§"
                }
                FileDelete, %NotesFile%
                FileAppend, %NewFile%, %NotesFile%, UTF-8
                GoSub, RefreshBoardData
                SoundBeep, 700, 100
            }
        }
    }
return

BoardGuiClose:
    SetTimer, WatchBoardCmd, Off
    Gui, Board:Destroy
    BoardGuiOpen := 0
return

GuiClose:
    ExitApp
