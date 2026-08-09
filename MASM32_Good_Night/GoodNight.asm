.386
.model  flat,stdcall
option  casemap:none

;---- Include files -----------------------------------------------
include \masm32\include\windows.inc
include \masm32\include\user32.inc
include \masm32\include\kernel32.inc
include \masm32\include\advapi32.inc
include \masm32\include\shell32.inc
include \masm32\include\masm32.inc

;---- Lib files ---------------------------------------------------
includelib  \masm32\lib\user32.lib
includelib  \masm32\lib\kernel32.lib
includelib  \masm32\lib\advapi32.lib
includelib  \masm32\lib\shell32.lib
includelib  \masm32\lib\masm32.lib



;---- Func prototype ----------------------------------------------
DlgProc proto   :DWORD,:DWORD,:DWORD,:DWORD
AboutProc proto :DWORD,:DWORD,:DWORD,:DWORD
EnableWindows   proto :HWND, :BOOL


;Macros------------------------------------------------------------
; ---------------------
; literal string MACRO
; ---------------------
literal MACRO quoted_text:VARARG
LOCAL local_text
.data
    local_text db quoted_text,0
align 4
.code
EXITM <local_text>
ENDM
; --------------------------------
; string address in INVOKE format
; --------------------------------
SADD MACRO quoted_text:VARARG
    EXITM <ADDR literal(quoted_text)>
ENDM


.const ;-----------------------------------------------------------
WM_SHELLNOTIFY  equ WM_USER+5

IDC_TIME        equ 1001
IDC_GO          equ 1002
IDC_EXIT        equ 1003
IDC_MIN         equ 1004
IDC_RESET       equ 1005
IDC_SHUTDOWN    equ 1006
IDC_REBOOT      equ 1007

IDM_RESTORE     equ 1501
IDM_ABOUT       equ 1502
IDM_RESET       equ 1503
IDM_EXIT        equ 1504

ID_TIMER        equ 2001    ;Timer Identificator

IDI_SLEEP       equ 3001
IDI_TRAY        equ 0

IDB_MIN         equ 3501

TIME_INTERVAL   equ 1000   ;1 second
BUFF_SIZE       equ 12      

IDD_ABOUT       equ 10000
IDC_ABOUT_OK    equ 10001


.data ;-----------------------------------------------------------
DlgName     db  "MainDlg",0
lpszName    db  "Good Night v1.0",0
ddSeconds   dd  0
ddAction    dd  EWX_SHUTDOWN or EWX_FORCE



.data? ;-----------------------------------------------------------
hInstance       HINSTANCE           ?
TimeLeft        DWORD               ?       ;in minutes
buffer          db                  BUFF_SIZE dup(?)
hToken 	    dd                  ?
tp              TOKEN_PRIVILEGES    <>
note            NOTIFYICONDATA      <>
hPopupMenu      dd                  ?
hBtnMin         dd                  ?
lpszSeconds     db                  4   dup(?)
lpszCaption     db                  32  dup(?) 
hMainIcon       dd                  ?



.code ;-----------------------------------------------------------
start:
invoke  GetModuleHandle, NULL
mov     hInstance, eax
invoke  DialogBoxParam, hInstance, ADDR DlgName, NULL, ADDR DlgProc, NULL
invoke  ExitProcess, eax

; ллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллл
DlgProc proc    hWnd:HWND, uMsg:UINT, wParam:WPARAM, lParam:LPARAM
LOCAL   pt:POINT

.IF uMsg==WM_INITDIALOG
    invoke  GetDlgItem, hWnd, IDC_SHUTDOWN
    invoke  SendMessage, eax, BM_SETCHECK, BST_CHECKED, 0

    invoke  GetDlgItem, hWnd, IDC_MIN
    push    eax
    invoke  LoadBitmap, hInstance, IDB_MIN
    pop     edx
    invoke  SendMessage, edx , BM_SETIMAGE, IMAGE_BITMAP, eax

    
    invoke  LoadIcon, hInstance, IDI_SLEEP
    mov     hMainIcon, eax
    invoke  SendMessage, hWnd, WM_SETICON, ICON_BIG, eax

    invoke  CreatePopupMenu
    mov     hPopupMenu, eax
    invoke  AppendMenu,hPopupMenu,MF_STRING,IDM_RESTORE, SADD("&Main window")
    invoke  AppendMenu,hPopupMenu,MF_STRING,IDM_RESET, SADD("&Reset timer")
    invoke  AppendMenu,hPopupMenu,MF_SEPARATOR, NULL, NULL
    invoke  AppendMenu,hPopupMenu,MF_STRING,IDM_ABOUT, SADD("&About ...")
    invoke  AppendMenu,hPopupMenu,MF_SEPARATOR, NULL, NULL
    invoke  AppendMenu,hPopupMenu,MF_STRING,IDM_EXIT, SADD("E&xit")

    mov     note.cbSize,sizeof NOTIFYICONDATA
    push    hWnd
    pop     note.hwnd
    mov     note.uID,IDI_TRAY
    mov     note.uFlags,NIF_ICON+NIF_MESSAGE+NIF_TIP
    mov     note.uCallbackMessage,WM_SHELLNOTIFY
    push    hMainIcon
    pop     note.hIcon
    invoke  lstrcpy,addr note.szTip, ADDR lpszName
    invoke  Shell_NotifyIcon,NIM_ADD,addr note

.ELSEIF uMsg==WM_CLOSE
    invoke  Shell_NotifyIcon,NIM_DELETE,addr note
    invoke  DestroyMenu, hPopupMenu
    invoke  KillTimer, hWnd, ID_TIMER
    invoke  EndDialog, hWnd, NULL

.ELSEIF uMsg==WM_SIZE
    .if wParam==SIZE_MINIMIZED
        invoke  ShowWindow,hWnd,SW_MINIMIZE ;Minimizing a window speeds up system performance
        invoke  ShowWindow,hWnd,SW_HIDE
    .endif

.ELSEIF uMsg==WM_COMMAND
    mov eax,wParam
    .if lParam==0
        .if ax==IDM_RESTORE
            invoke  ShowWindow,hWnd,SW_RESTORE
            
        .elseif ax==IDM_RESET
            invoke  SendMessage, hWnd, WM_COMMAND, IDC_RESET, 1
            
        .elseif ax==IDM_ABOUT
            invoke  DialogBoxParam, hInstance, IDD_ABOUT, NULL, ADDR AboutProc, NULL
        .else
            invoke  SendMessage, hWnd, WM_CLOSE, NULL, NULL
        .endif
    .else
        .if ax==IDC_GO
            invoke  GetDlgItemInt, hWnd, IDC_TIME, NULL, FALSE
            mov     TimeLeft, eax
            invoke  SetTimer, hWnd, ID_TIMER, TIME_INTERVAL, NULL
            invoke  SendMessage, hWnd, WM_TIMER, ID_TIMER, NULL
            invoke  EnableWindows, hWnd, FALSE

        .elseif ax==IDC_RESET
            mov     dword ptr ddSeconds, 0
            invoke  KillTimer, hWnd, ID_TIMER
            invoke  SetDlgItemInt, hWnd, IDC_TIME, 0, FALSE
            invoke  SendMessage, hWnd, WM_SETTEXT, NULL, ADDR lpszName
            invoke  lstrcpy,addr note.szTip,addr lpszName
            invoke  Shell_NotifyIcon,NIM_MODIFY,addr note
            invoke  EnableWindows, hWnd, TRUE
            invoke  GetDlgItem, hWnd, IDC_TIME
            invoke  SetFocus, eax
            
        .elseif ax==IDC_MIN
            invoke  SendMessage, hWnd, WM_SIZE, SIZE_MINIMIZED, 0
            
        .elseif ax==IDC_EXIT
            invoke  SendMessage, hWnd, WM_CLOSE, NULL, NULL
            
        .elseif ax==IDC_SHUTDOWN
            mov     ddAction, EWX_SHUTDOWN or EWX_FORCE
            
        .elseif ax==IDC_REBOOT
            mov     ddAction, EWX_REBOOT or EWX_FORCE
        .endif    
    .endif

.ELSEIF uMsg==WM_SHELLNOTIFY
    .if wParam==IDI_TRAY
        .if lParam==WM_RBUTTONDOWN
            invoke  GetCursorPos,addr pt
            invoke  SetForegroundWindow,hWnd
            invoke  TrackPopupMenu,hPopupMenu,TPM_RIGHTALIGN,pt.x,pt.y,NULL,hWnd,NULL
            invoke  PostMessage,hWnd,WM_NULL,0,0
        .elseif lParam==WM_LBUTTONDOWN
            invoke  SendMessage, hWnd, WM_COMMAND, IDM_RESTORE, 0
        .endif
    .endif


.ELSEIF uMsg==WM_TIMER
    .if wParam==ID_TIMER
        .if TimeLeft==-1
            call    ShutDownProc
            invoke  PostMessage, hWnd, WM_CLOSE, NULL, NULL            
        .elseif
            invoke  SetDlgItemInt, hWnd, IDC_TIME, TimeLeft, FALSE
            invoke  GetDlgItemText, hWnd, IDC_TIME, ADDR buffer, BUFF_SIZE-1
            mov     lpszCaption,0
            invoke  lstrcat, ADDR lpszCaption, SADD("Left: ")
            invoke  lstrcat, ADDR lpszCaption, ADDR buffer
            invoke  lstrcat, ADDR lpszCaption, SADD(":")
            mov     dword ptr lpszSeconds, 00000000h 
            invoke  udw2str, ddSeconds, ADDR lpszSeconds
            invoke  lstrcat, ADDR lpszCaption, ADDR lpszSeconds 
            invoke  SendMessage, hWnd, WM_SETTEXT, 0, ADDR lpszCaption
            invoke  lstrcpy,addr note.szTip,addr lpszCaption
            invoke  Shell_NotifyIcon,NIM_MODIFY,addr note
            .if ddSeconds==0
                mov     ddSeconds, 60
                dec     TimeLeft
            .endif
            dec     ddSeconds
        .endif
    .endif
    
.ELSE
    mov     eax, FALSE
    ret
.ENDIF

mov     eax, TRUE
ret
DlgProc endp
; ллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллл

; ллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллл
AboutProc   proc    hWnd:HWND, uMsg:UINT, wParam:WPARAM, lParam:LPARAM
.IF uMsg==WM_COMMAND
    mov     eax, wParam
    .if ax==IDC_ABOUT_OK
        invoke  SendMessage, hWnd, WM_CLOSE, 0, 0
    .endif
    
.ELSEIF uMsg==WM_CLOSE
    invoke  EndDialog, hWnd, NULL
    
.ELSE
    mov     eax, FALSE
    ret
.ENDIF

mov     eax, TRUE
ret
AboutProc   endp
; ллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллл

; ллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллл
ShutDownProc    proc
	invoke GetVersion
	test eax, 80000000h
	jnz @F
	invoke GetCurrentProcess
	invoke OpenProcessToken, eax, TOKEN_ADJUST_PRIVILEGES+TOKEN_QUERY, ADDR hToken
	invoke LookupPrivilegeValue, 0, SADD("SeShutdownPrivilege"), ADDR tp.Privileges[0].Luid
	mov tp.PrivilegeCount, 1
	mov tp.Privileges[0].Attributes, SE_PRIVILEGE_ENABLED
	invoke AdjustTokenPrivileges, hToken, FALSE, ADDR tp, 0, NULL, 0
@@:	invoke ExitWindowsEx, ddAction, 0ffffh
ret
ShutDownProc    endp
; ллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллл

; ллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллл
EnableWindows  proc   hWnd:HWND, bEnable:BOOL
      invoke  GetDlgItem, hWnd, IDC_SHUTDOWN
      invoke  EnableWindow, eax, bEnable
      invoke  GetDlgItem, hWnd, IDC_REBOOT
      invoke  EnableWindow, eax, bEnable
      invoke  GetDlgItem, hWnd, IDC_GO
      invoke  EnableWindow, eax, bEnable
      invoke  GetDlgItem, hWnd, IDC_TIME
      invoke  EnableWindow, eax, bEnable
ret
EnableWindows   endp
; ллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллл
end start