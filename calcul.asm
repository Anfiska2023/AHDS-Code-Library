format PE GUI 4.0
entry start

include 'win32a.inc'

; ------------------------------------------------------------------------------
; MACROS PERSONNALISÉES
; ------------------------------------------------------------------------------
macro MOVmd Var1, Var2 {
    push    Var2
    pop     Var1
}

; ==============================================================================
; SECTION CODE (.text) - Instructions et logique du programme
; ==============================================================================
section '.text' code readable executable

start:
    ; Initialisation des contrôles communs Windows
    invoke  InitCommonControls
    invoke  GetModuleHandle, 0
    mov     [hInst], eax
    invoke  GetCommandLine
    mov     [CommandLine], eax

    ; Lancement de la boucle principale de l'application
    invoke  WinMain, [hInst], NULL, [CommandLine], SW_SHOWDEFAULT
    invoke  ExitProcess, [msg.wParam]

; ------------------------------------------------------------------------------
; Procédure principale de la fenêtre (WinMain)
; ------------------------------------------------------------------------------
proc WinMain hinst, hPrevInst, CmdLine, CmdShow
    ; Enregistrement de la classe de fenêtre
    mov     [wc.style], CS_HREDRAW or CS_VREDRAW or CS_GLOBALCLASS
    mov     [wc.lpfnWndProc], WndProc
    mov     [wc.cbClsExtra], 0
    mov     [wc.cbWndExtra], 0
    mov     eax, [hInst]
    mov     [wc.hInstance], eax
    invoke  LoadIcon, eax, 101
    mov     [wc.hIcon], eax
    invoke  LoadCursor, 0, IDC_ARROW
    mov     [wc.hCursor], eax
    mov     [wc.hbrBackground], COLOR_BTNFACE + 1
    mov     [wc.lpszMenuName], 0
    mov     [wc.lpszClassName], class
    invoke  RegisterClass, wc

    ; Chargement du menu principal
    invoke  LoadMenu, [hInst], 102
    mov     [hMenu], eax

    ; Création de la fenêtre principale
    invoke  CreateWindowEx, 0, class, TB, \
            WS_OVERLAPPED or WS_CAPTION or WS_SYSMENU or WS_MINIMIZEBOX, \
            200, 68, 460, 262, NULL, [hMenu], [hinst], NULL
    mov     [hWnd], eax

    invoke  ShowWindow, [hWnd], SW_SHOWNORMAL
    invoke  UpdateWindow, [hWnd]
    invoke  SetWindowPos, [hWnd], HWND_TOPMOST, 0, 0, 0, 0, \
            SWP_NOMOVE or SWP_NOSIZE or SWP_SHOWWINDOW

    ; Chargement des raccourcis clavier (Accelerators)
    invoke  LoadAccelerators, [hInst], 2007
    mov     [hAccel], eax

.BeginLoop:
    invoke  GetMessage, msg, 0, 0, 0
    cmp     eax, 0
    je      .EndLoop
    invoke  TranslateAccelerator, [hWnd], [hAccel], msg
    cmp     eax, 0
    jne     .BeginLoop
    invoke  TranslateMessage, msg
    invoke  DispatchMessage, msg
    jmp     .BeginLoop

.EndLoop:
    ret
endp

; ------------------------------------------------------------------------------
; Procédure de gestion des messages de la fenêtre (WndProc)
; ------------------------------------------------------------------------------
proc WndProc hwnd, wmsg, wparam, lparam
    push    ebx edi esi

    mov     eax, [wmsg]
    cmp     eax, WM_CREATE
    je      .wmcreate
    cmp     eax, WM_COMMAND
    je      .wmcommand
    cmp     eax, WM_CLOSE
    je      .wmdestroy
    cmp     eax, WM_NOTIFY
    je      .returnP
    cmp     eax, WM_INITMENUPOPUP
    je      .wminitmenupopup
    cmp     eax, WM_KEYDOWN
    jne     .defwndproc

    invoke  SetFocus, [hEdit]
    jmp     .defwndproc

.wmcommand:
    mov     eax, [wparam]
    cwde
    cmp     eax, 6003               ; IDM_CLOSE
    je      .wmdestroy
    cmp     eax, 6004               ; IDM_CUT
    je      .idmcut
    cmp     eax, 6005               ; IDM_COPY
    je      .idmcopy
    cmp     eax, 6006               ; IDM_PASTE
    je      .idmpaste
    cmp     eax, 6026               ; IDM_INFO
    je      .idminfo
    cmp     eax, 6027               ; IDM_ABOUT
    je      .idmabout
    cmp     eax, 1
    je      .wmbs
    cmp     eax, 2
    je      .wmce
    cmp     eax, 3
    je      .wmclr

    cmp     eax, 19
    jne     @f
    mov     [T], 1
    invoke  SendMessage, [hRad], BM_SETCHECK, BST_UNCHECKED, 0
@@:
    cmp     eax, 20
    jne     @f
    mov     [T], 2
    invoke  SendMessage, [hDeg], BM_SETCHECK, BST_UNCHECKED, 0
@@:
    ; Sélection des bases numériques (Dec, Hex, Oct, Bin)
    and     [sw2], 0
    cmp     eax, 21
    jne     .chk_hex
    cmp     [Base], 10
    je      .chk_base_end
    MOVmd   [PrevBase], [Base]
    mov     [Base], 10
    mov     [sw2], 10
    call    DsplyConv
    jmp     .chk_base_end

.chk_hex:
    cmp     eax, 22
    jne     .chk_oct
    cmp     [Base], 16
    je      .chk_base_end
    MOVmd   [PrevBase], [Base]
    mov     [Base], 16
    mov     [sw2], 16
    call    DsplyConv
    jmp     .chk_base_end

.chk_oct:
    cmp     eax, 23
    jne     .chk_bin
    cmp     [Base], 8
    je      .chk_base_end
    MOVmd   [PrevBase], [Base]
    mov     [Base], 8
    mov     [sw2], 8
    call    DsplyConv
    jmp     .chk_base_end

.chk_bin:
    cmp     eax, 24
    jne     .chk_base_end
    cmp     [Base], 2
    je      .chk_base_end
    MOVmd   [PrevBase], [Base]
    mov     [Base], 2
    mov     [sw2], 2
    call    DsplyConv

.chk_base_end:
    cmp     eax, 20
    jbe     @f
    cmp     eax, 25
    jae     @f
    and     [I], 0
@@:
    cmp     eax, 43
    jne     @f
    and     [Float], 0
    invoke  SendMessage, [hFloat], BM_GETCHECK, 0, 0
    cmp     eax, 1
    jne     .wmclr
    or      [Float], 1
    jmp     .wmclr
@@:
    cmp     eax, 50
    jne     .defwndproc
    and     [ArcOn], 0
    invoke  SendMessage, [hArc], BM_GETCHECK, 0, 0
    cmp     eax, 1
    jne     .defwndproc
    or      [ArcOn], 1
    jmp     .defwndproc

.wmcreate:
    invoke  GetSysColor, COLOR_MENU
    mov     [BackGC], eax

    invoke  lstrcpy, lf.lfFaceName, FontName
    mov     [lf.lfHeight], -12
    mov     [lf.lfWeight], 500
    invoke  CreateFontIndirect, lf
    mov     [hFont], eax

    invoke  lstrcpy, lf.lfFaceName, FontName1
    mov     [lf.lfHeight], -12
    mov     [lf.lfWeight], 500
    invoke  CreateFontIndirect, lf
    mov     [hDspF], eax

    ; Création des éléments de l'interface utilisateur (boutons, zones de texte)
    invoke  CreateWindowEx, NULL, Butt, float, WS_CHILD or WS_VISIBLE or BS_AUTOCHECKBOX, \
            4, 4, 130, 12, [hwnd], 43, [hInst], NULL
    mov     [hFloat], eax
    invoke  SendMessage, [hFloat], WM_SETFONT, [hFont], 0

    invoke  CreateWindowEx, WS_EX_CLIENTEDGE, EditPT, NULL, \
            WS_CHILD or WS_VISIBLE or WS_BORDER or ES_RIGHT or ES_AUTOHSCROLL or ES_SAVESEL, \
            135, 0, 315, 22, [hwnd], 44, [hInst], NULL
    mov     [hEdit], eax
    invoke  SetWindowLong, [hEdit], GWL_WNDPROC, EditProc
    mov     [SubEdit], eax

    invoke  CreateWindowEx, NULL, Butt, arc, WS_CHILD or WS_VISIBLE or BS_AUTOCHECKBOX, \
            182, 32, 40, 12, [hwnd], 50, [hInst], NULL
    mov     [hArc], eax
    invoke  SendMessage, [hArc], WM_SETFONT, [hFont], 0

    invoke  CreateWindowEx, WS_EX_CLIENTEDGE, EditPT, NULL, \
            WS_CHILD or WS_VISIBLE or WS_BORDER or ES_CENTER or ES_READONLY, \
            239, 26, 25, 21, [hwnd], 88, [hInst], NULL
    mov     [hMem], eax

    invoke  CreateWindowEx, NULL, Butt, BackS, WS_CHILD or WS_VISIBLE, \
            271, 26, 80, 20, [hwnd], 1, [hInst], NULL
    mov     [hBkSp], eax
    invoke  SendMessage, [hBkSp], WM_SETFONT, [hFont], 0

    invoke  CreateWindowEx, WS_EX_CLIENTEDGE, EditPT, NULL, \
            WS_CHILD or WS_VISIBLE or WS_BORDER or ES_CENTER or ES_READONLY, \
            363, 26, 25, 21, [hwnd], 89, [hInst], NULL
    mov     [hOpr], eax

    invoke  CreateWindowEx, NULL, Butt, CE, WS_CHILD or WS_VISIBLE, \
            399, 26, 20, 20, [hwnd], 2, [hInst], NULL
    mov     [hCE], eax
    invoke  SendMessage, [hCE], WM_SETFONT, [hFont], 0

    invoke  CreateWindowEx, NULL, Butt, CLR, WS_CHILD or WS_VISIBLE, \
            429, 26, 20, 20, [hwnd], 3, [hInst], NULL
    mov     [hCLR], eax
    invoke  SendMessage, [hCLR], WM_SETFONT, [hFont], 0

    ; Boîtes de groupe et boutons radio
    invoke  CreateWindowEx, NULL, Butt, 0, WS_CHILD or WS_VISIBLE or BS_GROUPBOX, \
            178, 43, 85, 28, [hwnd], 14, [hInst], NULL
    invoke  CreateWindowEx, NULL, Butt, 0, WS_CHILD or WS_VISIBLE or BS_GROUPBOX, \
            271, 43, 178, 28, [hwnd], 15, [hInst], NULL

    xor     ebx, ebx
    mov     [XP], 182
    mov     [N], 19

.BuildRadio:
    cmp     [N], 21
    jge     .radio_btn
    invoke  CreateWindowEx, NULL, Butt, DegT + ebx, WS_CHILD or WS_VISIBLE or BS_AUTOCHECKBOX, \
            [XP], 55, 39, 12, [hwnd], [N], [hInst], NULL
    sub     [XP], 3
    jmp     .radio_set

.radio_btn:
    invoke  CreateWindowEx, NULL, Butt, DegT + ebx, WS_CHILD or WS_VISIBLE or BS_AUTORADIOBUTTON, \
            [XP], 55, 40, 12, [hwnd], [N], [hInst], NULL

.radio_set:
    mov     [hDeg + ebx], eax
    invoke  SendMessage, dword [hDeg + ebx], WM_SETFONT, [hFont], 0
    cmp     [N], 24
    jge     .radio_done
    add     ebx, 4
    add     [N], 1
    cmp     [N], 21
    jne     @f
    add     [XP], 13
@@:
    add     [XP], 43
    jmp     .BuildRadio

.radio_done:
    invoke  SendMessage, [hDeg], BM_SETCHECK, BST_CHECKED, 0
    invoke  SendMessage, [hDec], BM_SETCHECK, BST_CHECKED, 0

    ; Construction des barres d'outils (Toolbars)
    xor     ebx, ebx
    mov     [XP], 178
    mov     [YP], 74
    mov     [Row], 0
    mov     [I], 9
    mov     [N], 17
    mov     [W], 272

.BuildTB:
    invoke  CreateWindowEx, NULL, Stat, 0, WS_CHILD or WS_VISIBLE, \
            [XP], [YP], [W], 24, [hwnd], 1, [hInst], NULL
    mov     [hTB01], eax
    invoke  SetWindowLong, [hTB01], GWL_WNDPROC, ToolbarProc
    mov     [SubTool], eax
    invoke  CreateToolbarEx, [hTB01], WS_CHILD or WS_VISIBLE or CCS_NODIVIDER, \
            dword [IDT + ebx], [I], [hInst], dword [IDT + ebx], dword [tb + ebx], [N], \
            16, 16, 16, 16, dword [tbl + ebx]
    cmp     [Row], 4
    jge     .tb_done
    add     ebx, 4
    add     [YP], 29
    add     [Row], 1
    jmp     .BuildTB

.tb_done:
    and     [I], 0

    ; Zone d'affichage graphique
    invoke  CreateWindowEx, NULL, Butt, 0, WS_CHILD or WS_VISIBLE or BS_GROUPBOX, \
            4, 18, 161, 196, [hwnd], 55, [hInst], NULL
    mov     [hDspl], eax
    jmp     .returnP

.wminitmenupopup:
    invoke  SendMessage, [hEdit], EM_GETSEL, w1, w2
    mov     eax, [w1]
    cmp     [w2], eax
    jbe     .popup_gray
    invoke  EnableMenuItem, [hMenu], 6004, MF_BYCOMMAND or MF_ENABLED
    invoke  EnableMenuItem, [hMenu], 6005, MF_BYCOMMAND or MF_ENABLED
    jmp     .returnP
.popup_gray:
    invoke  EnableMenuItem, [hMenu], 6004, MF_BYCOMMAND or MF_GRAYED
    invoke  EnableMenuItem, [hMenu], 6005, MF_BYCOMMAND or MF_GRAYED
    jmp     .returnP

.idmcut:
    invoke  SendMessage, [hEdit], WM_CUT, 0, 0
    jmp     .wmclr

.idmcopy:
    invoke  SendMessage, [hEdit], WM_COPY, 0, 0
    jmp     .returnP

.idmpaste:
    call    ClearValues
    invoke  SendMessage, [hEdit], WM_PASTE, 0, 0
    jmp     .returnP

.idminfo:
    invoke  MessageBox, NULL, Info, AppName, MB_OK
    jmp     .returnP

.idmabout:
    invoke  DialogBoxParam, [hInst], 2000, [hwnd], InfoAbDlg, 0
    jmp     .returnP

.wmbs:
    invoke  SendMessage, [hEdit], WM_GETTEXT, 35, Buff
    invoke  lstrlen, Buff
    or      eax, eax
    jz      .returnP
    invoke  lstrcpyn, ConvO, Buff, eax
    invoke  SendMessage, [hEdit], WM_SETTEXT, NULL, ConvO
    invoke  SendMessage, [hEdit], EM_SETSEL, 33, 33
    invoke  SetFocus, [hWnd]
    invoke  lstrcpy, Buff, ConvO
    call    AsciiToBase
    invoke  lstrcpy, Buff, ConvO
    call    AsciiToFloat
    mov     edx, RNum10
    call    FloatToAscii
    call    Display
    jmp     .returnP

.wmce:
    mov     byte [ConvO], 0
    invoke  SendMessage, [hEdit], WM_SETTEXT, NULL, ConvO
    invoke  SetFocus, [hWnd]
    jmp     .returnP

.wmclr:
    call    ClearValues
    jmp     .returnP

.defwndproc:
    invoke  DefWindowProc, [hwnd], [wmsg], [wparam], [lparam]
    pop     esi edi ebx
    ret

.wmdestroy:
    invoke  PostQuitMessage, 0
.returnP:
    xor     eax, eax
    pop     esi edi ebx
    ret
endp

; ------------------------------------------------------------------------------
; Procédure pour effacer les valeurs de la calculatrice
; ------------------------------------------------------------------------------
proc ClearValues
    mov     byte [ConvO], 0
    mov     byte [ConvI], 0
    mov     byte [Buff], 0
    mov     byte [LBuff], 0
    mov     byte [RBuff], 0
    mov     byte [PLBuff], 0
    mov     byte [PRBuff], 0
    and     [HPress], 0
    and     [NPress], 0
    and     [RPress], 0
    and     [BPress], 0
    and     [DP], 0
    invoke  SendMessage, [hEdit], WM_SETTEXT, NULL, ConvO
    invoke  SetFocus, [hWnd]
    invoke  SendMessage, [hOpr], WM_SETTEXT, NULL, Clear
    mov     [Len], 0
    invoke  CLRMW, R, 32
    call    Display
    and     [First], 0
    fldz
    fstp    tbyte [RNum10]
    fldz
    fstp    tbyte [RWrk10]
    ret
endp

; ------------------------------------------------------------------------------
; Procédure de la boîte de dialogue "À Propos" (About)
; ------------------------------------------------------------------------------
proc InfoAbDlg hdlg, wmsg, wparam, lparam
    cmp     [wmsg], WM_COMMAND
    jne     .AboutDone
    mov     eax, [wparam]
    cmp     eax, 1
    je      .AboutClose
    cmp     eax, 2
    jne     .AboutDone
.AboutClose:
    invoke  EndDialog, [hdlg], [wparam]
    mov     eax, TRUE
    ret
.AboutDone:
    mov     eax, FALSE
    ret
endp

; ------------------------------------------------------------------------------
; Procédure de traitement des entrées du clavier
; ------------------------------------------------------------------------------
proc EditProc hwnd, wmsg, wparam, lparam
    mov     [Key], 0
    cmp     [wmsg], WM_KEYDOWN
    jne     @f
    invoke  SendMessage, [hEdit], EM_GETSEL, w1, w2
    mov     eax, [w1]
    cmp     [w2], eax
    jbe     @f
    cmp     [wparam], 17
    je      @f
    call    ClearValues
@@:
    cmp     [wmsg], WM_PASTE
    jne     @f
    call    ClearValues
    mov     [Key], 288
    jmp     .pass
@@:
    cmp     [wmsg], WM_CHAR
    jne     @f
    cmp     [wparam], 2bh
    jne     .chk_mul
    mov     [wmsg], WM_KEYUP
    mov     [wparam], 6bh
    jmp     @f
.chk_mul:
    cmp     [wparam], 2ah
    jne     @f
    mov     [wmsg], WM_KEYUP
    mov     [wparam], 6ah
@@:
    cmp     [wmsg], WM_KEYUP
    jne     .pass

    invoke  SendMessage, [hEdit], WM_GETTEXT, 35, Buff
    invoke  lstrlen, Buff
    cmp     eax, 16
    jbe     @f
    cmp     [BPress], 3
    jne     @f
    invoke  MessageBeep, MB_OK
    mov     byte [Buff + 15], 0
    invoke  SendMessage, [hEdit], WM_SETTEXT, NULL, Buff
@@:
    cmp     [wparam], 2fh
    jbe     .chk_numpad
    cmp     [wparam], 3ah
    jae     .chk_numpad
    MOVmd   [Key], [wparam]
    sub     [Key], 48
    add     [Key], 200
    jmp     .pass

.chk_numpad:
    cmp     [wparam], 5fh
    jbe     .chk_alpha
    cmp     [wparam], 6ah
    jae     .chk_alpha
    MOVmd   [Key], [wparam]
    sub     [Key], 96
    add     [Key], 200
    jmp     .pass

.chk_alpha:
    cmp     [wparam], 40h
    jbe     .chk_symbols
    cmp     [wparam], 47h
    jae     .chk_symbols
    MOVmd   [Key], [wparam]
    sub     [Key], 55
    add     [Key], 200
    jmp     .pass

.chk_symbols:
    cmp     [wparam], 6eh
    je      .key_dot
    cmp     [wparam], 0beh
    jne     .chk_plus
.key_dot:
    mov     [Key], 216
    jmp     .pass
.chk_plus:
    cmp     [wparam], 6bh
    jne     .chk_minus
    mov     [Key], 218
    jmp     .pass
.chk_minus:
    cmp     [wparam], 6dh
    je      .key_sub
    cmp     [wparam], 0bdh
    jne     .chk_star
.key_sub:
    mov     [Key], 219
    jmp     .pass
.chk_star:
    cmp     [wparam], 6ah
    je      .key_mul
    cmp     [wparam], 0bah
    jne     .chk_slash
.key_mul:
    mov     [Key], 220
    jmp     .pass
.chk_slash:
    cmp     [wparam], 6fh
    je      .key_div
    cmp     [wparam], 0bfh
    jne     .chk_eq
.key_div:
    mov     [Key], 221
    jmp     .pass
.chk_eq:
    cmp     [wparam], 0dh
    je      .key_equal
    cmp     [wparam], 0bbh
    jne     .pass
.key_equal:
    mov     [Key], 222

.pass:
    invoke  CallWindowProc, [SubEdit], [hwnd], [wmsg], [wparam], [lparam]
    cmp     [wmsg], WM_CUT
    jne     @f
    call    ClearValues
@@:
    cmp     [Key], 0
    jbe     @f
    call    ToolbarProc
@@:
    ret
endp

; ------------------------------------------------------------------------------
; Traitement des clics sur les boutons de la barre d'outils
; ------------------------------------------------------------------------------
proc ToolbarProc hwnd, wmsg, wparam, lparam
    push    ebx ecx edx esi edi

    cmp     [wmsg], WM_COMMAND
    je      .start_proc
    cmp     [Key], 0
    ja      .start_proc
    jmp     .GetOut

.start_proc:
    invoke  SendMessage, [hOpr], WM_SETTEXT, NULL, Clear
    cmp     [Key], 0
    jbe     @f
    MOVmd   [wparam], [Key]
    mov     [Key], 0
    invoke  SetFocus, [hWnd]
@@:
    invoke  SendMessage, [hEdit], WM_GETTEXT, 35, ConvO
    invoke  SendMessage, [hEdit], WM_GETTEXT, 35, Buff
    cmp     byte [Buff], '*'
    je      .GetOut

    mov     eax, [wparam]
    mov     [N], 0

    cmp     eax, 288
    jne     .chk_base_input
    mov     byte [ConvI], 0
    invoke  lstrlen, Buff
    mov     esi, eax
    xor     edi, edi
    mov     eax, '0'
    mov     ecx, '0'
    mov     edx, '0'

    cmp     [Base], 10
    je      .base_10_16
    cmp     [Base], 16
    je      .base_10_16
    cmp     [Base], 2
    je      .base_2
    cmp     [Base], 8
    je      .base_8
    jmp     .paste_loop

.base_10_16:
    mov     ebx, '9'
    cmp     [Base], 16
    jne     .paste_loop
    mov     ecx, 'A'
    mov     edx, 'F'
    jmp     .paste_loop
.base_2:
    mov     ebx, '1'
    jmp     .paste_loop
.base_8:
    mov     ebx, '7'

.paste_loop:
    or      esi, esi
    jz      .DecP
    cmp     byte [Buff + edi], 90
    jbe     @f
    sub     byte [Buff + edi], 32
    sub     byte [ConvO + edi], 32
@@:
    mov     bl, byte [Buff + edi]
    ; Vérification de la plage des caractères collés
    inc     edi
    dec     esi
    jmp     .paste_loop

.chk_base_input:
    cmp     [Base], 10
    je      .is_dec_oct
    cmp     [Base], 8
    jne     @f
.is_dec_oct:
    or      [N], 1
@@:
    ; Traitement du pavé numérique
    cmp     eax, 200
    jl      .chk_mem
    cmp     eax, 216
    jg      .chk_mem

.btn_digit:
    mov     eax, [wparam]
    sub     eax, 200
    cmp     eax, 16
    jne     .fmt_digit
    cmp     [DP], 0
    jne     .dot_empty
    mov     byte [ConvI], '.'
    mov     byte [ConvI+1], 0
    jmp     .DecP
.dot_empty:
    mov     byte [ConvI], 0
    jmp     .DecP

.fmt_digit:
    mov     ebx, FmtA
    cmp     [Base], 16
    jne     @f
    mov     ebx, FmtH
@@:
    cinvoke wsprintf, ConvI, ebx, eax

.DecP:
    cmp     byte [ConvO], '0'
    jne     @f
    cmp     byte [ConvO + 1], 0
    jne     @f
    mov     byte [ConvO], 0
@@:
    invoke  lstrcat, ConvO, ConvI
    invoke  SendMessage, [hEdit], WM_SETTEXT, NULL, ConvO
    invoke  SendMessage, [hEdit], EM_SETSEL, 34, 34
    invoke  lstrcpyn, Buff, ConvO, 34
    call    AsciiToBase
    invoke  lstrcpyn, Buff, ConvO, 34
    call    AsciiToFloat
    mov     edx, RNum10
    call    FloatToAscii
    call    Display
    mov     eax, [wparam]

.chk_mem:
    cmp     eax, 226                ; IDB_BUTMC
    jne     .chk_mr
    and     [StoreFlag], 0
    fldz
    fstp    tbyte [RMem10]
    invoke  CLRMW, MEM, 12
    invoke  SendMessage, [hMem], WM_SETTEXT, NULL, Clear

.chk_mr:
    cmp     eax, 227                ; IDB_BUTMR
    jne     .chk_ms
    cmp     [BPress], 0
    jne     .mr_calc
    fld     tbyte [RMem10]
    fstp    tbyte [RNum10]
    fld     tbyte [RMem10]
    fstp    tbyte [RWrk10]
    jmp     .mr_disp
.mr_calc:
    fld     tbyte [RNum10]
    fstp    tbyte [RWrk10]
    fld     tbyte [RMem10]
    fstp    tbyte [RNum10]
.mr_disp:
    mov     edx, RNum10
    call    FloatToAscii
    MOVmd   [MEM + 40], [SubZero]
    invoke  CopyMW, R, MEM, 12
    call    BaseToAscii
    invoke  SendMessage, [hEdit], WM_SETTEXT, NULL, ConvO
    invoke  SendMessage, [hEdit], EM_SETSEL, 33, 33
    call    Display

.chk_ms:
    cmp     eax, 228                ; IDB_BUTMS
    jne     .chk_pi
.StoreMem:
    mov     [StoreFlag], 1
    fld     tbyte [RNum10]
    fstp    tbyte [RMem10]
    invoke  CopyMW, MEM, R, 12
    invoke  SendMessage, [hMem], WM_SETTEXT, NULL, M
    call    StoreCLR
    jmp     .GetOut

.chk_pi:
    cmp     eax, 234                ; IDB_BUTPI
    jne     .chk_trig
    fldpi
    fstp    tbyte [RNum10]
    mov     edx, RNum10
    call    FloatToAscii
    invoke  SendMessage, [hEdit], WM_SETTEXT, NULL, Pi
    invoke  SendMessage, [hEdit], EM_SETSEL, 33, 33
    invoke  lstrcpy, Buff, Pi
    call    AsciiToBase
    call    Display

.chk_trig:
    ; Fonctions trigonométriques (Sin, Cos, Tan, etc.)
    cmp     eax, 235
    jl      .chk_eq
    cmp     eax, 240
    jg      .chk_eq

    finit
    fld     tbyte [RNum10]
    cmp     [T], 1
    jne     @f
    fld     tbyte [RDeg10]
    fmul    st0, st1
@@:
    cmp     eax, 235                ; SIN
    jne     .chk_cos
    cmp     [ArcOn], 0
    jne     .asin
    fsin
    jmp     .trig_done
.asin:
    fld     st0
    fmul
    fld     st0
    fld1
    fsubr
    fdiv
    fsqrt
    fld1
    fpatan
    jmp     .trig_done

.chk_cos:
    cmp     eax, 236                ; COS
    jne     .chk_tan
    cmp     [ArcOn], 0
    jne     .acos
    fcos
    jmp     .trig_done
.acos:
    fld     st0
    fmul
    fld     st0
    fld1
    fsubr
    fdivr
    fsqrt
    fld1
    fpatan
    jmp     .trig_done

.chk_tan:
    cmp     eax, 237                ; TAN
    jne     .trig_done
    fptan
    fstp    st0

.trig_done:
    fstp    tbyte [RNum10]
    mov     edx, RNum10
    call    FloatToAscii
    jmp     .FromSQ

.chk_eq:
    cmp     eax, 222                ; IDB_BUTEQ
    jne     .GetOut
    invoke  SendMessage, [hOpr], WM_SETTEXT, NULL, EO

.FP:
    finit
    fld     tbyte [RNum10]
    fld     tbyte [RWrk10]
    cmp     [BPress], 1
    jne     .eq_sub
    fadd    st0, st1
    jmp     .eq_store
.eq_sub:
    cmp     [BPress], 2
    jne     .eq_mul
    fsub    st0, st1
    jmp     .eq_store
.eq_mul:
    cmp     [BPress], 3
    jne     .eq_div
    fmul    st0, st1
    jmp     .eq_store
.eq_div:
    cmp     [BPress], 4
    jne     .eq_store
    fdiv    st0, st1

.eq_store:
    fstp    tbyte [RNum10]
    fld     tbyte [RNum10]
    fstp    tbyte [RWrk10]
    mov     edx, RNum10
    call    FloatToAscii

.FromSQ:
    invoke  SendMessage, [hEdit], WM_SETTEXT, NULL, ConvO
    invoke  SendMessage, [hEdit], EM_SETSEL, 33, 33
    and     [First], 0
    and     [HPress], 0
    and     [NPress], 0
    and     [RPress], 0
    and     [BPress], 0
    and     [DP], 0
    invoke  SendMessage, [hEdit], WM_GETTEXT, 34, Buff
    call    AsciiToBase
    call    BaseToAscii
    call    Display

.GetOut:
    invoke  CallWindowProc, [SubTool], [hwnd], [wmsg], [wparam], [lparam]
    pop     edi esi edx ecx ebx
    ret
endp

; ------------------------------------------------------------------------------
; Routines auxiliaires de calculs et de conversions
; ------------------------------------------------------------------------------
proc StoreCLR
    cmp     [First], 0
    jne     @f
    invoke  SendMessage, [hEdit], WM_GETTEXT, 35, ConvH
    invoke  lstrcpy, HLBuff, LBuff
    invoke  lstrcpy, HRBuff, RBuff
    invoke  lstrlen, RBuff
    mov     [HLen], eax
    invoke  CopyMW, PT, R, 12
    fld     tbyte [RNum10]
    fstp    tbyte [RWrk10]
    or      [First], 1
@@:
    mov     byte [ConvO], 0
    invoke  SendMessage, [hEdit], WM_SETTEXT, NULL, ConvO
    and     [sw1], 0
    and     [DP], 0
    ret
endp

proc AsciiToBase
    push    ebx edi
    and     [DP], 0
    and     [Pos], 0
    and     [cnt], 0
    invoke  CLRMW, R, 32
    invoke  lstrlen, Buff
    mov     ecx, Buff
    xor     edx, edx

.a2b_loop:
    or      eax, eax
    jz      .a2b_done
    cmp     byte [ecx], 2eh
    jne     @f
    or      [Pos], 1
    or      [cnt], 1
    or      [DP], 1
    jmp     .a2b_next
@@:
    cmp     byte [ecx], 2dh
    jne     @f
    or      dword [R + 44], 1
    jmp     .a2b_next
@@:
    movzx   ebx, byte [ecx]
    sub     ebx, '0'
.a2b_next:
    inc     ecx
    inc     edx
    dec     eax
    jmp     .a2b_loop

.a2b_done:
    MOVmd   [HBase], [Base]
    pop     edi ebx
    ret
endp

proc BaseToAscii
    push    esi edi
    mov     [DecPos], 0
    push    [Base]
    cmp     [sw2], 0
    je      @f
    MOVmd   [Base], [sw2]
@@:
    invoke  lstrcpy, ConvO, ConvI
    pop     [Base]
    pop     edi esi
    ret
endp

proc CLRMW To:DWORD, Num:DWORD
    pushad
    xor     eax, eax
    mov     ebx, [To]
    mov     ecx, [Num]
.loop:
    mov     dword [ebx + eax], 0
    add     eax, 4
    loop    .loop
    popad
    ret
endp

proc CopyMW To:DWORD, From:DWORD, Num:DWORD
    pushad
    xor     eax, eax
    mov     edx, [To]
    mov     ebx, [From]
    mov     ecx, [Num]
.loop:
    push    dword [ebx + eax]
    pop     dword [edx + eax]
    add     eax, 4
    loop    .loop
    popad
    ret
endp

proc Display
    push    ebx edx esi edi
    invoke  GetDC, [hDspl]
    mov     [hEDC], eax
    invoke  GetClientRect, [hDspl], rect
    invoke  CreateSolidBrush, [BackGC]
    invoke  FillRect, [hEDC], rect, eax
    invoke  SetBkColor, [hEDC], [BackGC]
    invoke  SetTextColor, [hEDC], [HeadC]
    invoke  TextOut, [hEDC], 64, 10, DecT, 3
    invoke  TextOut, [hEDC], 64, 40, HexT, 3
    invoke  TextOut, [hEDC], 64, 70, OctT, 3
    invoke  TextOut, [hEDC], 64, 100, BinT, 3
    invoke  ReleaseDC, [hWnd], [hEDC]
    pop     edi esi edx ebx
    ret
endp

proc DsplyConv
    call    BaseToAscii
    ret
endp

proc AsciiToFloat
    pushad
    invoke  lstrlen, Buff
    or      eax, eax
    jz      .done
    finit
    fldz
.done:
    popad
    ret
endp

proc FloatToAscii
    push    ebx edx esi edi
    invoke  CopyMW, Sav, R, 12
    mov     byte [PLBuff], 0
    mov     byte [PRBuff], 0
    mov     esi, PRBuff
    mov     ebx, edx
    fldcw   [CWNoRound]
    fld     tbyte [ebx]
    fstp    tbyte [RNum10]
    invoke  lstrcpy, ConvO, PLBuff
    pop     edi esi edx ebx
    ret
endp

; ==============================================================================
; SECTION DONNÉES (.data) - Variables initialisées et non initialisées
; ==============================================================================
section '.data' data readable writeable

FontName    db 'Courier New',0
FontNamep   db 'Courier',0
FontName1   db 'Times New Roman',0
FmtA        db '%lu',0
FmtH        db '%lX',0

AppName     db 'ASM CALCULATOR',0
class       db 'Calculator',0
TB02class   db 'TB01',0
ToolClass   db 'ToolbarWindow32',0
ErrorMsg    db '** The output is out of range **            ',0
szPaste     db 'Your Paste Selection Is Out Of',0Dh,0Ah,'Range For The Base Setting!',0
TB          db ' CALCULATOR  in Assembler',0
Info        db 'Most of the functions are self explanatory.',0Dh,0Ah,0

EditPT      db 'EDIT',0
Butt        db 'BUTTON',0
Stat        db 'STATIC',0
float       db 'Floating Point',0
arc         db 'Arc',0
BackS       db 'Back Space',0
CE          db 'CE',0
CLR         db 'C',0
DegT        db 'Deg',0
RadT        db 'Rad',0
DecT        db 'Dec',0
HexT        db 'Hex',0
OctT        db 'Oct',0
BinT        db 'Bin',0
Pi          db '3.141592653589793238',0
Period      db '.',0
Zero        db '0',0
One         db '1',0
M           db 'M',0
PO          db '+',0
SO          db '-',0
MO          db 'x',0
DO          db '/',0
EO          db '=',0

CW          dw 10
CWRound     dw 037fh
CWNoRound   dw 0f7fh
RDeg10      dt 0.01745329252
RRad10      dt 57.2957795130

HeadC       dd 00ff0000h
TextC       dd 00000000h
BackGC      dd 00b1987ch
Base        dd 10
T           dd 1

IDT         dd 301, 302, 303, 304, 305

; Boutons pour la barre d'outils
tb1:
    dd 0, 235, TBSTATE_ENABLED, TBSTYLE_BUTTON, 0, 0
    dd 0, 0, TBSTATE_ENABLED, TBSTYLE_SEP, 0, 0
    dd 1, 240, TBSTATE_ENABLED, TBSTYLE_BUTTON, 0, 0
    dd 0, 0, TBSTATE_ENABLED, TBSTYLE_SEP, 0, 0
    dd 2, 226, TBSTATE_ENABLED, TBSTYLE_BUTTON, 0, 0
    dd 0, 0, TBSTATE_ENABLED, TBSTYLE_SEP, 0, 0
    dd 3, 207, TBSTATE_ENABLED, TBSTYLE_BUTTON, 0, 0
    dd 0, 0, TBSTATE_ENABLED, TBSTYLE_SEP, 0, 0
    dd 4, 208, TBSTATE_ENABLED, TBSTYLE_BUTTON, 0, 0
    dd 0, 0, TBSTATE_ENABLED, TBSTYLE_SEP, 0, 0
    dd 5, 209, TBSTATE_ENABLED, TBSTYLE_BUTTON, 0, 0
    dd 0, 0, TBSTATE_ENABLED, TBSTYLE_SEP, 0, 0
    dd 6, 218, TBSTATE_ENABLED, TBSTYLE_BUTTON, 0, 0
    dd 0, 0, TBSTATE_ENABLED, TBSTYLE_SEP, 0, 0
    dd 7, 223, TBSTATE_ENABLED, TBSTYLE_BUTTON, 0, 0
    dd 0, 0, TBSTATE_ENABLED, TBSTYLE_SEP, 0, 0
    dd 8, 231, TBSTATE_ENABLED, TBSTYLE_BUTTON, 0, 0
tbl1 = ($ - tb1)

tb          dd tb1, tb1, tb1, tb1, tb1
tbl         dd tbl1, tbl1, tbl1, tbl1, tbl1

; Buffers non initialisés
PLBuff      rb 50
PRBuff      rb 50
HLBuff      rb 50
HRBuff      rb 50
LBuff       rb 50
RBuff       rb 50
ConvH       rb 120
ConvI       rb 120
ConvO       rb 120
Buff        rb 120
Clear       rb 50
Zeros       rb 64

RNum10      dt ?
RWrk10      dt ?
RMem10      dt ?
QW          dq ?

A           rd 8
B           rd 8
D           rd 12
R           rd 12
R2          rd 4
R3          rd 4
R4          rd 8
R5          rd 10
PT          rd 12
MEM         rd 12
Sav         rd 12
RH          rd 12

hInst       dd ?
hWnd        dd ?
hMenu       dd ?
hAccel      dd ?
hFont       dd ?
hDspF       dd ?
CommandLine dd ?
hEDC        dd ?
hEdit       dd ?
hDspl       dd ?
hFloat      dd ?
hArc        dd ?
hMem        dd ?
hBkSp       dd ?
hOpr        dd ?
hCE         dd ?
hCLR        dd ?
hDeg        dd ?
hRad        dd ?
hDec        dd ?
hHex        dd ?
hOct        dd ?
hBin        dd ?
hTB01       dd ?
SubEdit     dd ?
SubTool     dd ?

Float       dd ?
First       dd ?
sw1         dd ?
sw2         dd ?
sw3         dd ?
Min         dd ?
Key         dd ?
HPress      dd ?
NPress      dd ?
RPress      dd ?
BPress      dd ?
Len         dd ?
HLen        dd ?
w1          dd ?
w2          dd ?
XP          dd ?
YP          dd ?
ArcOn       dd ?
Row         dd ?
Col         dd ?
Pos         dd ?
DecPos      dd ?
DP          dd ?
I           dd ?
N           dd ?
W           dd ?
HBase       dd ?
PrevBase    dd ?
StoreFlag   dd ?
SubZero     dd ?

wc          WNDCLASS
msg         MSG
lf          LOGFONT
rect        RECT

; ==============================================================================
; SECTION IMPORTS (.idata) - Fonctions API des DLLs Windows
; ==============================================================================
section '.idata' import data readable

library kernel32, 'KERNEL32.DLL', \
        user32,   'USER32.DLL', \
        gdi32,    'GDI32.DLL', \
        comctl32, 'COMCTL32.DLL'

import kernel32, \
       GetModuleHandle, 'GetModuleHandleA', \
       GetCommandLine,  'GetCommandLineA', \
       ExitProcess,     'ExitProcess', \
       lstrcpy,         'lstrcpyA', \
       lstrcat,         'lstrcatA', \
       lstrlen,         'lstrlenA', \
       lstrcpyn,        'lstrcpynA'

import user32, \
       RegisterClass,        'RegisterClassA', \
       CreateWindowEx,       'CreateWindowExA', \
       ShowWindow,           'ShowWindow', \
       UpdateWindow,         'UpdateWindow', \
       SetWindowPos,         'SetWindowPos', \
       GetMessage,           'GetMessageA', \
       TranslateMessage,     'TranslateMessage', \
       DispatchMessage,      'DispatchMessageA', \
       PostQuitMessage,      'PostQuitMessage', \
       DefWindowProc,        'DefWindowProcA', \
       LoadIcon,             'LoadIconA', \
       LoadCursor,           'LoadCursorA', \
       LoadMenu,             'LoadMenuA', \
       LoadAccelerators,     'LoadAcceleratorsA', \
       TranslateAccelerator, 'TranslateAcceleratorA', \
       SendMessage,          'SendMessageA', \
       SetFocus,             'SetFocus', \
       GetSysColor,          'GetSysColor', \
       SetWindowLong,        'SetWindowLongA', \
       EnableMenuItem,       'EnableMenuItem', \
       MessageBox,           'MessageBoxA', \
       DialogBoxParam,       'DialogBoxParamA', \
       EndDialog,            'EndDialog', \
       CallWindowProc,       'CallWindowProcA', \
       MessageBeep,          'MessageBeep', \
       GetDC,                'GetDC', \
       ReleaseDC,            'ReleaseDC', \
       GetClientRect,        'GetClientRect', \
       FillRect,             'FillRect', \
       wsprintf,             'wsprintfA'

import gdi32, \
       CreateFont,         'CreateFontA', \
       CreateFontIndirect, 'CreateFontIndirectA', \
       CreateSolidBrush,   'CreateSolidBrush', \
       SetBkColor,         'SetBkColor', \
       SetTextColor,       'SetTextColor', \
       TextOut,            'TextOutA'

import comctl32, \
       InitCommonControls, 'InitCommonControls', \
       CreateToolbarEx,    'CreateToolbarEx'

; ==============================================================================
; SECTION RESSOURCES (.rsrc) - Icône, images, menus et boîtes de dialogue
; ==============================================================================
section '.rsrc' resource data readable

directory RT_MENU, menus, \
          RT_DIALOG, dialogs, \
          RT_ACCELERATOR, accelerators, \
          RT_BITMAP, bitmaps, \
          RT_GROUP_ICON, group_icons, \
          RT_ICON, icons

; --- Définition des menus ---
resource menus, 102, LANG_NEUTRAL, main_menu

menu main_menu
     menuitem '&Close', 6003
     menupopup '&Edit'
         menuitem '&Cut#tCtrl+x', 6004
         menuitem '&Copy#tCtrl+c', 6005
         menuitem '&Paste#tCtrl+v', 6006
     endp
     menupopup '&Information'
         menuitem '&Info', 6026
         menuitem '&About', 6027
     endp

; --- Raccourcis clavier (Accelerators) ---
resource accelerators, 2007, LANG_NEUTRAL, main_accel

accelerator main_accel, \
    FVIRTKEY + FCONTROL, 'X', 6004, \
    FVIRTKEY + FCONTROL, 'C', 6005, \
    FVIRTKEY + FCONTROL, 'V', 6006, \
    FVIRTKEY, VK_BACK, 1

; --- Boîte de dialogue "À Propos" ---
resource dialogs, 2000, LANG_NEUTRAL, about_dlg

dialog about_dlg, 'About Calculator', 50, 136, 194, 112, WS_MODALFRAME + WS_3DLOOK + WS_POPUP + WS_CAPTION + WS_SYSMENU
  dialogitem 'STATIC', 'This calculator program was used FASM assembler...', -1, 32, 5, 134, 36, WS_VISIBLE + SS_CENTER
  dialogitem 'EDIT', 'Any comments, send me anisovandre@gmail.com', 501, 46, 31, 107, 20, WS_CHILD + WS_VISIBLE + WS_BORDER + ES_CENTER + ES_MULTILINE
  dialogitem 'STATIC', 'Write your next Windows program in FASM.', -1, 47, 57, 105, 28, WS_VISIBLE + SS_SUNKEN + WS_BORDER
  dialogitem 'BUTTON', 'OK', IDOK, 73, 92, 50, 14, WS_VISIBLE + BS_DEFPUSHBUTTON
enddialog

; --- Images de la barre d'outils (.bmp) ---
resource bitmaps, \
         301, LANG_NEUTRAL, bmp1, \
         302, LANG_NEUTRAL, bmp2, \
         303, LANG_NEUTRAL, bmp3, \
         304, LANG_NEUTRAL, bmp4, \
         305, LANG_NEUTRAL, bmp5

bmp1: file 'Toolbar01.bmp':14
bmp2: file 'Toolbar02.bmp':14
bmp3: file 'Toolbar03.bmp':14
bmp4: file 'Toolbar04.bmp':14
bmp5: file 'Toolbar05.bmp':14

; --- Icône du programme (.ico) ---
resource group_icons, 101, LANG_NEUTRAL, main_icon
resource icons, 1, LANG_NEUTRAL, icon_data

icon_data: file 'Calc.ico':22
main_icon: data 0,1,0,1,0,32,32,0,0,0,0,0,0,0,0,0,0,1,0