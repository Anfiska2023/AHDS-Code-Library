format PE GUI 4.0
entry codestart

include 'C:\fasmw17164\INCLUDE\win32a.inc'

; ============================================================================
; CONSTANTES ET IDENTIFIANTS DES CONTRÔLES
; ============================================================================
IDD_MAIN                = 100
ID_RUN                  = 201
ID_OFF                  = 202
ID_PHOTO                = 203
IDC_CANVAS              = 204
IDR_CAM_DLL             = 500   ; Identifiant de la ressource DLL embarquée

section '.data' data readable writeable

  hInstance             dd ?
  hDlgMain              dd ?
  hCamDll               dd ?
  hCanvas               dd ?

  pfnStartCapture       dd ?
  pfnStopCapture        dd ?
  pfnTakePhoto          dd ?

  _fnStart              db 'StartCameraCapture', 0
  _fnStop               db 'StopCameraCapture', 0
  _fnPhoto              db 'TakeCameraPhoto', 0

  szTempPath            rb MAX_PATH
  szDllPath             rb MAX_PATH
  _dllFileName          db 'camlib1.dll', 0

  _errExtractMsg        db 'Impossible de prendre le fichier camlib1.dll dans les ressources !', 0
  _errDllMsg            db 'Impossible de charger camlib1.dll !', 0
  _errCaption           db 'Erreur', 0

section '.code' code readable executable

  codestart:
    invoke  GetModuleHandle, 0
    mov     [hInstance], eax

    ; 1. Extraction de camlib1.dll depuis les ressources vers le dossier temporaire %TEMP%
    call    ExtractDllFromResources
    test    eax, eax
    jz      .err_extract

    ; 2. Chargement de la DLL extraite
    invoke  LoadLibrary, szDllPath
    mov     [hCamDll], eax
    test    eax, eax
    jz      .err_dll

    ; 3. Importation des adresses des fonctions
    invoke  GetProcAddress, [hCamDll], _fnStart
    mov     [pfnStartCapture], eax

    invoke  GetProcAddress, [hCamDll], _fnStop
    mov     [pfnStopCapture], eax

    invoke  GetProcAddress, [hCamDll], _fnPhoto
    mov     [pfnTakePhoto], eax

    ; 4. Lancement de la boîte de dialogue principale
    invoke  DialogBoxParam, [hInstance], IDD_MAIN, HWND_DESKTOP, MainDlg, 0

    ; 5. Déchargement de la DLL et suppression du fichier temporaire à la fermeture
    cmp     [hCamDll], 0
    jz      .clean_file
    invoke  FreeLibrary, [hCamDll]

  .clean_file:
    invoke  DeleteFile, szDllPath
    invoke  ExitProcess, 0

  .err_extract:
    invoke  MessageBox, 0, _errExtractMsg, _errCaption, MB_ICONERROR
    invoke  ExitProcess, 1

  .err_dll:
    invoke  MessageBox, 0, _errDllMsg, _errCaption, MB_ICONERROR
    invoke  ExitProcess, 1

; ============================================================================
; PROCÉDURE D'EXTRACTION DE LA DLL DEPUIS LES RESSOURCES
; ============================================================================
proc ExtractDllFromResources
    push    ebx esi edi
    local   hRes dd ?, hResData dd ?, dwSize dd ?, hFile dd ?, dwWritten dd ?

    ; Obtention du chemin du dossier temporaire %TEMP%
    invoke  GetTempPath, MAX_PATH, szTempPath
    test    eax, eax
    jz      .fail

    ; Construction du chemin complet : %TEMP%\camlib1.dll
    invoke  lstrcpy, szDllPath, szTempPath
    invoke  lstrcat, szDllPath, _dllFileName

    ; Recherche de la ressource dans l'exécutable
    invoke  FindResource, [hInstance], IDR_CAM_DLL, RT_RCDATA
    mov     [hRes], eax
    test    eax, eax
    jz      .fail

    ; Chargement de la ressource en mémoire
    invoke  LoadResource, [hInstance], [hRes]
    mov     [hResData], eax
    test    eax, eax
    jz      .fail

    ; Obtention de la taille de la DLL en octets
    invoke  SizeofResource, [hInstance], [hRes]
    mov     [dwSize], eax
    test    eax, eax
    jz      .fail

    ; Obtention du pointeur vers les données en mémoire
    invoke  LockResource, [hResData]
    mov     esi, eax
    test    eax, eax
    jz      .fail

    ; Création du fichier camlib1.dll sur le disque
    invoke  CreateFile, szDllPath, GENERIC_WRITE, 0, 0, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, 0
    mov     [hFile], eax
    cmp     eax, INVALID_HANDLE_VALUE
    je      .fail

    ; Écriture des octets depuis la mémoire vers le fichier
    lea     eax, [dwWritten]
    invoke  WriteFile, [hFile], esi, [dwSize], eax, 0
    invoke  CloseHandle, [hFile]

    mov     eax, 1
    jmp     .finish

  .fail:
    xor     eax, eax

  .finish:
    pop     edi esi ebx
    ret
endp

; ============================================================================
; GESTIONNAIRE DE MESSAGES DE LA BOÎTE DE DIALOGUE
; ============================================================================
proc MainDlg, hdlg, msg, wparam, lparam
    push    ebx esi edi

    cmp     [msg], WM_INITDIALOG
    je      .wminitdlg
    cmp     [msg], WM_COMMAND
    je      .wmcommand
    cmp     [msg], WM_CLOSE
    je      .wmclose

    xor     eax, eax
    jmp     .finish

    .wminitdlg:
      mov     eax, [hdlg]
      mov     [hDlgMain], eax
      invoke  GetDlgItem, [hdlg], IDC_CANVAS
      mov     [hCanvas], eax
      jmp     .finish

    .wmcommand:
      mov     eax, [wparam]
      and     eax, 0FFFFh

      cmp     eax, ID_RUN
      je      .startbutton
      cmp     eax, ID_OFF
      je      .stopbutton
      cmp     eax, ID_PHOTO
      je      .photobutton
      jmp     .finish

    .startbutton:
      cmp     [pfnStartCapture], 0
      jz      .finish
      push    [hCanvas]
      call    [pfnStartCapture]
      jmp     .finish

    .stopbutton:
      cmp     [pfnStopCapture], 0
      jz      .finish
      call    [pfnStopCapture]
      jmp     .finish

    .photobutton:
      cmp     [pfnTakePhoto], 0
      jz      .finish
      call    [pfnTakePhoto]
      jmp     .finish

    .wmclose:
      cmp     [pfnStopCapture], 0
      jz      .end_dlg
      call    [pfnStopCapture]
    .end_dlg:
      invoke  EndDialog, [hdlg], 0

    .finish:
      pop     edi esi ebx
      ret
endp

; ============================================================================
; TABLE D'IMPORTATION DES BIBLIOTHÈQUES SYSTÈME
; ============================================================================
section '.idata' import data readable writeable

  library kernel, 'KERNEL32.DLL',\
          user,   'USER32.DLL'

  import  kernel,\
          GetModuleHandle, 'GetModuleHandleA',\
          LoadLibrary,     'LoadLibraryA',\
          GetProcAddress,  'GetProcAddress',\
          FreeLibrary,     'FreeLibrary',\
          GetTempPath,     'GetTempPathA',\
          lstrcpy,         'lstrcpyA',\
          lstrcat,         'lstrcatA',\
          FindResource,    'FindResourceA',\
          LoadResource,    'LoadResource',\
          SizeofResource,  'SizeofResource',\
          LockResource,    'LockResource',\
          CreateFile,      'CreateFileA',\
          WriteFile,       'WriteFile',\
          CloseHandle,     'CloseHandle',\
          DeleteFile,      'DeleteFileA',\
          ExitProcess,     'ExitProcess'

  import  user,\
          DialogBoxParam,  'DialogBoxParamA',\
          EndDialog,       'EndDialog',\
          GetDlgItem,      'GetDlgItem',\
          MessageBox,      'MessageBoxA'

; ============================================================================
; INCLUSION DE LA DLL DANS LES RESSOURCES (Syntaxe directe)
; ============================================================================
section '.rsrc' resource data readable
  directory RT_DIALOG, dialogs,\
            RT_RCDATA, rcdata

  resource  dialogs,\
            IDD_MAIN, LANG_ENGLISH + SUBLANG_DEFAULT, main_dialog

  resource  rcdata,\
            IDR_CAM_DLL, LANG_NEUTRAL, dll_entry

  dll_entry:
    dd RVA dll_bytes, dll_bytes_end - dll_bytes, 0, 0

  dll_bytes:
    file 'camlib1.dll'
  dll_bytes_end:

  dialog    main_dialog, 'Project <Image Sensor Camera Win10>', 0, 0, 350, 200, WS_CAPTION + WS_POPUP + WS_SYSMENU + DS_MODALFRAME + DS_CENTER
            dialogitem 'STATIC', '', IDC_CANVAS, 10, 10, 200, 145, WS_VISIBLE + SS_SUNKEN
            dialogitem 'STATIC', '&Media Foundation Engine', -1, 220, 10, 120, 8, WS_VISIBLE
            dialogitem 'STATIC', '&Compatible with UVC', -1, 220, 22, 120, 8, WS_VISIBLE
            dialogitem 'BUTTON', 'RUN IMAGE CAMERA', ID_RUN, 7, 165, 85, 15, WS_VISIBLE + WS_TABSTOP
            dialogitem 'BUTTON', 'OFF LINE DEVICE', ID_OFF, 100, 165, 85, 15, WS_VISIBLE + WS_TABSTOP
            dialogitem 'BUTTON', 'TAKE PHOTO BY CLICK', ID_PHOTO, 20, 182, 153, 13, WS_VISIBLE + WS_TABSTOP
  enddialog