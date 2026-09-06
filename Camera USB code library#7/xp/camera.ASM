
format PE GUI 4.0
entry codestart

include '%fasminc%\win32a.inc'

  IDD_MAIN		       =  100
  WM_CAP_DRIVER_CONNECT        =  WM_USER + 10
  WM_CAP_DRIVER_DISCONNECT     =  WM_USER + 11
  WM_CAP_FILE_SAVEDIB	       =  WM_USER + 25
  WM_CAP_SET_PREVIEW	       =  WM_USER + 50
  WM_CAP_SET_PREVIEWRATE       =  WM_USER + 52
  WM_CAP_SET_SCALE	       =  WM_USER + 53
  ID_RUN		       =  201
  ID_OFF		       =  202
  ID_PHOTO		       =  203
  _camtitle		       db 'image camera'

  _filename  db 'FOTO.JPG'     ; Filename
  nDevice    dd   0	       ; Device Number -> It can range from 0 through 9
  nFPS	     dd   1	       ; Frames per second. Must be 1000/FPS. E.g. 20 FPS = 50

section '.data' data readable writeable
  hInstance	dd ?
  hWebcam	dd ?

section '.code' code readable executable
  codestart:
    invoke  GetModuleHandle, 0
    mov     [hInstance], eax
    invoke  DialogBoxParam, eax, IDD_MAIN, HWND_DESKTOP, MainDlg, 0
    invoke  ExitProcess, 0

  proc MainDlg, hdlg, msg, wparam, lparam
    push    ebx esi edi
    cmp     [msg], WM_INITDIALOG
    je	    .wminitdlg
    cmp     [msg], WM_COMMAND
    je	    .wmcommand
    cmp     [msg], WM_CLOSE
    je	    .wmclose
    xor     eax, eax
    jmp     .finish
    .wminitdlg:
      invoke  capCreateCaptureWindow, _camtitle, WS_VISIBLE + WS_CHILD, 10, 10,\
					296, 252, [hdlg], 0
      mov     [hWebcam], eax
      jmp     .finish
    .wmcommand:
      cmp     [wparam], BN_CLICKED shl 16 + ID_RUN
      je      .startbutton
      cmp     [wparam], BN_CLICKED shl 16 + ID_OFF
      je      .stopbutton
      cmp     [wparam], BN_CLICKED shl 16 + ID_PHOTO
      je      .clickbutton
    .wmclose:
      invoke  SendMessage, [hWebcam], WM_CAP_DRIVER_DISCONNECT, _camtitle, 0
      invoke  EndDialog, [hdlg], 0
    .finish:
      pop     edi esi ebx
      return
    .startbutton:
      invoke  SendMessage,  [hWebcam], WM_CAP_DRIVER_CONNECT, [nDevice], 0
      invoke  SendMessage,  [hWebcam], WM_CAP_SET_SCALE, TRUE, 0
      invoke  SendMessage,  [hWebcam], WM_CAP_SET_PREVIEWRATE, [nFPS], 0
      invoke  SendMessage,  [hWebcam], WM_CAP_SET_PREVIEW, TRUE, 0
      jmp     .finish
    .stopbutton:
      invoke  SendMessage, [hWebcam], WM_CAP_DRIVER_DISCONNECT, _camtitle, 0
      jmp     .finish
    .clickbutton:
      invoke  SendMessage, [hWebcam], WM_CAP_FILE_SAVEDIB, 0, _filename
      jmp     .finish
    endp

section '.idata' import data readable writeable

  library kernel, 'KERNEL32.DLL',\
	  user,   'USER32.DLL',\
	  avicap, 'AVICAP32.DLL'

  import  kernel,\
	  GetModuleHandle,'GetModuleHandleA',\
	  ExitProcess,	  'ExitProcess'

  import  user,\
	  DialogBoxParam, 'DialogBoxParamA',\
	  EndDialog,	  'EndDialog',\
	  SendMessage,	  'SendMessageA'

  import  avicap,\
	  capCreateCaptureWindow, 'capCreateCaptureWindowA'

section '.rsrc' resource data readable
  directory	RT_DIALOG, dialogs
  resource	dialogs,\
		IDD_MAIN, LANG_ENGLISH + SUBLANG_DEFAULT, main_dialog
  dialog	main_dialog, 'Project <Image Sensor Camera>', 0, 0, 350, 200, WS_CAPTION + WS_POPUP + WS_SYSMENU +\
							    DS_MODALFRAME+ DS_CENTER
		dialogitem 'STATIC','&Project Building in Beer-Sheva College, ',-1,210,10,170,8,WS_VISIBLE
		dialogitem 'STATIC','&as project for practical engineer. ',-1,220,20,170,8,WS_VISIBLE
		dialogitem 'STATIC','&For start - connect camera in port USB, ',-1,210,30,170,8,WS_VISIBLE
		dialogitem 'STATIC','&control button from menu of the program ',-1,210,40,170,8,WS_VISIBLE
		dialogitem 'BUTTON', 'RUN IMAGE CAMERA', ID_RUN,  7, 165, 85, 15, WS_VISIBLE + WS_TABSTOP
		dialogitem 'BUTTON', 'OFF LINE DEVICE',  ID_OFF,  100, 165, 85, 15, WS_VISIBLE + WS_TABSTOP
		dialogitem 'BUTTON', 'TAKE PHOTO BY CLICK', ID_PHOTO, 20, 182, 153, 13, WS_VISIBLE + WS_TABSTOP
  enddialog


