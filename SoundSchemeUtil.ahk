#Warn
#Requires AutoHotkey v2.0
#NoTrayIcon
#SingleInstance Force

;@Ahk2Exe-SetCompanyName Expertcoderz
;@Ahk2Exe-SetDescription SoundSchemeUtil
;@Ahk2Exe-SetVersion 1.0.0

SZ_TABLE := {
    ; Menus
    Menu_File: "&File",
    Menu_Options: "&Options",
    Menu_Tools: "&Tools",
    Menu_Help: "&Help",
    ; File Menu
    Menu_File_Exit: "E&xit",
    ; Tools Menu
    Menu_Tools_ControlPanel: "&Sound settings in Control Panel",
    ; Help Menu
    Menu_Help_OnlineHelp: "&Online Help",
    Menu_Help_Report: "&Report Bug",
    Menu_Help_About: "&About"
}

FILE_EXT := "soundscheme"

A_ScriptName := "SoundSchemeUtil"

/*
This is so we can add the future ability to
operate on different users' sound schemes. [TODO]
*/
target_hive := "HKEY_CURRENT_USER"

selected_scheme := ""

checkSchemeExists(scheme) {
    Loop Reg target_hive "\AppEvents\Schemes\Names", "K" {
        if A_LoopRegName = scheme
            return true
    }
    return false
}

schemeNameIsSpecial(scheme) =>
    scheme = ".Default" || scheme = ".None" || scheme = ".Modified" || scheme = ".Current"

showChildGui(gui) {
    local posX, posY
    MainGui.GetPos &posX, &posY
    gui.Show "x" posX " y" posY
}

MainGui := Gui("-MinimizeBox")
MainGui.OnEvent "Escape", CloseGui

FileMenu := Menu()
FileMenu.Add SZ_TABLE.Menu_File_Exit, CloseGui

ToolsMenu := Menu()
ToolsMenu.Add SZ_TABLE.Menu_Tools_ControlPanel, (*) => Run("mmsys.cpl")
ToolsMenu.SetIcon SZ_TABLE.Menu_Tools_ControlPanel, "mmsys.cpl"

HelpMenu := Menu()
HelpMenu.Add SZ_TABLE.Menu_Help_OnlineHelp
    , (*) => Run("https://github.com/Expertcoderz/SoundSchemeUtil#readme")
HelpMenu.Add SZ_TABLE.Menu_Help_Report
    , (*) => Run("https://github.com/Expertcoderz/SoundSchemeUtil/issues/new/choose")
HelpMenu.Add
HelpMenu.Add SZ_TABLE.Menu_Help_About, AboutOpen

Menus := MenuBar()
Menus.Add SZ_TABLE.Menu_File, FileMenu
Menus.Add SZ_TABLE.Menu_Tools, ToolsMenu
Menus.Add SZ_TABLE.Menu_Help, HelpMenu
MainGui.MenuBar := Menus

MainGui.AddText "Section xm ym", "Installed sound schemes:"
MainGui.AddListView("xs w140 h180 -Hdr -Multi +Sort vSoundSchemeList", ["Name"])
    .OnEvent("ItemSelect", ListSelectionChanged)

MainGui.AddButton("Section yp w75 Disabled vRenameButton", "&Rename")
    .OnEvent("Click", SchemeRename)
MainGui.AddButton("xs wp Disabled vDeleteButton", "&Delete")
    .OnEvent("Click", SchemeDelete)
MainGui.AddButton("xs wp Disabled vApplyButton", "&Apply")
    .OnEvent("Click", SchemeApply)
MainGui.AddButton("xs wp Disabled vExportButton", "&Export")
    .OnEvent("Click", SchemeExport)

MainGui.AddButton("xs yp+42 wp", "&Import")
    .OnEvent("Click", SchemeImport)
MainGui.AddButton("xs wp", "Re&fresh")
    .OnEvent("Click", ListRefresh)

MainGui.AddStatusBar "vStatusBar"
MainGui["StatusBar"].SetParts(175)
MainGui["StatusBar"].SetText(" Current: ?")
MainGui["StatusBar"].SetText("? sound(s)", 2)

MainGui.Show
ListRefresh

ListRefresh(*) {
    MainGui["SoundSchemeList"].Delete()

    ListSelectionChanged

    Loop Reg target_hive "\AppEvents\Schemes\Names", "K"
        MainGui["SoundSchemeList"].Add(, A_LoopRegName)

    MainGui["StatusBar"].SetText(" Current: " RegRead(target_hive "\AppEvents\Schemes", , ".Default"))

    local sound_count := 0
    Loop Reg target_hive "\AppEvents\Schemes\Apps", "K" {
        Loop Reg A_LoopRegKey "\" A_LoopRegName, "K" {
            Loop Reg A_LoopRegKey "\" A_LoopRegName, "K" {
                if A_LoopRegName = ".Current" && RegRead(, , "") {
                    sound_count++
                    break
                }
            }
        }
    }
    MainGui["StatusBar"].SetText(sound_count " sound(s)", 2)
}

ListSelectionChanged(*) {
    local selected_num := MainGui["SoundSchemeList"].GetNext()
    global selected_scheme := selected_num ? MainGui["SoundSchemeList"].GetText(selected_num) : ""

    local action
    for action in ["Rename", "Delete"] {
        MainGui[action "Button"].Enabled := selected_num
            && selected_scheme != ".Default"
            && selected_scheme != ".None"
            && selected_scheme != ".Modified"
    }
    for action in ["Apply", "Export"]
        MainGui[action "Button"].Enabled := selected_num
}

SchemeRename(*) {
    static SchemeRenamePromptGui
    if !IsSet(SchemeRenamePromptGui) {
        SchemeRenamePromptGui := Gui("-SysMenu +Owner" MainGui.Hwnd, "Rename Sound Scheme")
        SchemeRenamePromptGui.OnEvent "Escape", PromptClose
        SchemeRenamePromptGui.OnEvent "Close", PromptClose

        SchemeRenamePromptGui.AddText "w206 r2 vPromptText"
        SchemeRenamePromptGui.AddEdit "wp vSchemeNameEdit"

        SchemeRenamePromptGui.AddButton("w100 Default", "OK")
            .OnEvent("Click", PromptSubmit)
        SchemeRenamePromptGui.AddButton("yp wp", "Cancel")
            .OnEvent("Click", PromptClose)
    }

    SchemeRenamePromptGui["PromptText"].Text := "The sound scheme '" selected_scheme "' will be`nrenamed to:"
    SchemeRenamePromptGui["SchemeNameEdit"].Value := ""
    SchemeRenamePromptGui.Opt "-Disabled"
    MainGui.Opt "+Disabled"
    showChildGui SchemeRenamePromptGui

    PromptSubmit(*) {
        local new_name := SchemeRenamePromptGui["SchemeNameEdit"].Value

        SchemeRenamePromptGui.Opt "+Disabled"

        if !checkSchemeExists(selected_scheme)
            return MsgBox("The sound scheme '" selected_scheme "' does not exist.", , "Iconx")

        if schemeNameIsSpecial(new_name)
            return MsgBox("This scheme name is not allowed.", , "Iconx")

        if RegRead(target_hive "\AppEvents\Schemes", , ".Default") = selected_scheme
            RegWrite new_name, "REG_SZ", target_hive "\AppEvents\Schemes"

        RegDeleteKey target_hive "\AppEvents\Schemes\Names\" selected_scheme
        RegCreateKey target_hive "\AppEvents\Schemes\Names\" new_name

        Loop Reg target_hive "\AppEvents\Schemes\Apps", "K" {
            Loop Reg A_LoopRegKey "\" A_LoopRegName, "K" {
                Loop Reg A_LoopRegKey "\" A_LoopRegName, "K" {
                    if A_LoopRegName = selected_scheme {
                        RegCreateKey A_LoopRegKey "\" new_name
                        RegWrite RegRead(), "REG_SZ", A_LoopRegKey "\" new_name
                        RegDeleteKey
                        break
                    }
                }
            }
        }

        ListRefresh
        PromptClose
    }

    PromptClose(*) {
        SchemeRenamePromptGui.Hide
        MainGui.Opt "-Disabled"
        WinActivate "ahk_id " MainGui.Hwnd
    }
}

SchemeDelete(*) {
    if schemeNameIsSpecial(selected_scheme)
        return MsgBox("The specified sound scheme ('" selected_scheme "') cannot be deleted.", , "Iconx")

    if RegRead(target_hive "\AppEvents\Schemes", , ".Default") = selected_scheme
        /*
            If the scheme to delete is currently applied,
            then mark the current scheme to become "(Modified)".
        */
        RegWrite ".Modified", "REG_SZ", target_hive "\AppEvents\Schemes"

    local scheme_existed := checkSchemeExists(selected_scheme)
    if scheme_existed {
        RegDeleteKey target_hive "\AppEvents\Schemes\Names\" selected_scheme

        Loop Reg target_hive "\AppEvents\Schemes\Apps", "K" {
            Loop Reg A_LoopRegKey "\" A_LoopRegName, "K" {
                Loop Reg A_LoopRegKey "\" A_LoopRegName, "K" {
                    if A_LoopRegName = selected_scheme {
                        RegDeleteKey
                        break
                    }
                }
            }
        }
    }

    ListRefresh
}

SchemeApply(*) {
    if !checkSchemeExists(selected_scheme)
        return MsgBox("The sound scheme '" selected_scheme "' does not exist.", , "Iconx")

    RegWrite selected_scheme, "REG_SZ", target_hive "\AppEvents\Schemes"

    Loop Reg target_hive "\AppEvents\Schemes\Apps", "K" {
        Loop Reg A_LoopRegKey "\" A_LoopRegName, "K" {
            Loop Reg A_LoopRegKey "\" A_LoopRegName, "K" {
                if A_LoopRegName = selected_scheme {
                    RegWrite RegRead(), "REG_SZ", A_LoopRegKey "\.Current"
                    break
                }
            }
        }
    }

    ListRefresh
}

SchemeExport(*) {
    local file_location := FileSelect("S16", A_WorkingDir "\" selected_scheme "." FILE_EXT
        , "Export Windows Sound Scheme", "Sound Scheme Files (*." FILE_EXT ")"
    )
    if !file_location
        return

    local content := ""

    Loop Reg target_hive "\AppEvents\Schemes\Apps", "K" {
        local category := A_LoopRegName
        Loop Reg A_LoopRegKey "\" A_LoopRegName, "K" {
            local event := A_LoopRegName
            Loop Reg A_LoopRegKey "\" A_LoopRegName, "K" {
                if A_LoopRegName = selected_scheme {
                    content .= Format(
                        "`n[AppEvents\Schemes\Apps\{}\{}]`nDefaultValue={}`n",
                        category, event, RegRead()
                    )
                }
            }
        }
    }

    if FileExist(file_location)
        FileDelete file_location

    FileAppend content, file_location, "`n"
}

SchemeImport(*) {
    ; Allow selection of multiple files to batch-import
    local file_locations := FileSelect("M",
        , "Import Windows Sound Scheme(s)", "Sound Scheme Files (*." FILE_EXT ")"
    )

    local file_location
    for file_location in file_locations {
        local scheme
        SplitPath file_location, , , , &scheme    ; get file name w/o extension and dot

        if schemeNameIsSpecial(scheme) {
            MsgBox "The sound scheme '" scheme "' must be renamed to something else before import.", , "Iconx"
            continue
        }

        if checkSchemeExists(scheme) && MsgBox("The sound scheme '" scheme "' already exists; would you like to overwrite it?", , "YesNo Icon?") != "Yes" {
            MsgBox "Export cancelled for:`n" file_location
            continue
        }

        local scheme_data := Map()
        /*
            Here we parse and gather the sound scheme data so validation can be done
            prior to actually writing it to the registry, lest the file is corrupt.
        
            scheme_data map item format example:
                key:    ".Default\LowBatteryAlarm"
                value:  "C:\Windows\Media\Characters\Windows Battery Low.wav"
            parsed from INI format:
            ```
                [AppEvents\Schemes\Apps\.Default\LowBatteryAlarm]
                DefaultValue=C:\Windows\Media\Characters\Windows Battery Low.wav
            ```
        */
        local current_header
        local import_failed := false
        Loop Parse FileRead(file_location), "`n`r" {
            if !A_LoopField || SubStr(A_LoopField, 1, 1) = ";"
                ; Ignore blank lines and comments as per the INI file format.
                continue

            importFail() {
                MsgBox "Error parsing sound scheme file.`n`nLine: " A_Index, , "Iconx"
                import_failed := true
            }

            local header_match
            if RegExMatch(A_LoopField, "^\[AppEvents\\Schemes\\Apps\\(.+\\.+)\]$", &header_match) {
                current_header := header_match.1
            } else {
                local path_match
                if !(current_header && RegExMatch(A_LoopField, "^DefaultValue=(.+)$", &path_match)) {
                    importFail
                    break
                }

                scheme_data[current_header] := path_match.1
            }
        }

        if import_failed
            continue

        RegCreateKey target_hive "\AppEvents\Schemes\Names\" scheme

        local header, sound_path
        for header, sound_path in scheme_data {
            local key := target_hive "\AppEvents\Schemes\Apps\" header
            RegCreateKey key
            RegWrite sound_path, "REG_SZ", key
        }
    }

    ListRefresh
}

AboutOpen(*) {
    MainGui.Opt "+Disabled"

    static AboutGui
    if !IsSet(AboutGui) {
        AboutGui := Gui("-MinimizeBox +Owner" MainGui.Hwnd, "About SoundSchemeUtil")
        AboutGui.OnEvent "Escape", AboutClose
        AboutGui.OnEvent "Close", AboutClose

        AboutGui.AddPicture "w40 h40", A_IsCompiled ? A_ScriptFullPath : A_ProgramFiles "\AutoHotkey\v2\AutoHotkey.exe"
        AboutGui.SetFont "s12 bold"
        AboutGui.AddText "xp+50 yp", "SoundSchemeUtil version " (A_IsCompiled ? SubStr(FileGetVersion(A_ScriptFullPath), 1, -2) : "?")
        AboutGui.SetFont
        AboutGui.AddText "xp wp", "An open-source utility for managing and exporting UI sound schemes in Windows."
        AboutGui.AddLink "xp", "<a href=`"https://github.com/Expertcoderz/SoundSchemeUtil`">https://github.com/Expertcoderz/SoundSchemeUtil</a>"
    }

    showChildGui AboutGui

    AboutClose(*) {
        AboutGui.Hide
        MainGui.Opt "-Disabled"
        WinActivate "ahk_id " MainGui.Hwnd
    }
}

CloseGui(*) {
    ExitApp
}
