; ============================================================================
; APPLICATION : Good Night v1.0
; DESCRIPTION : Minuteur d'extinction / redémarrage du système pour Windows
; ASSEMBLEUR  : Flat Assembler (FASM)
; REMARQUE    : Tout le code et les ressources sont regroupés dans ce seul fichier.
; ============================================================================

; Définition du format de fichier exécutable (Portable Executable pour GUI Windows 32 bits)
format PE GUI 4.0
entry start ; Définit l'étiquette 'start' comme point d'entrée du programme

; Inclusion des définitions standards de l'API Windows pour FASM
include 'win32a.inc'

; ============================================================================
; DEFINITION DES CONSTANTES (IDENTIFIANTS ET MESSAGES)
; ============================================================================

; Message personnalisé pour les notifications de l'icône dans la barre des tâches
WM_SHELLNOTIFY  = WM_USER + 5

; Identifiants des contrôles de la fenêtre principale
IDC_TIME        = 1001      ; Champ de saisie du temps (minutes)
IDC_GO          = 1002      ; Bouton Lancer (GO)
IDC_EXIT        = 1003      ; Bouton Quitter (Exit)
IDC_MIN         = 1004      ; Bouton Réduire (Min)
IDC_RESET       = 1005      ; Bouton Réinitialiser (Reset)
IDC_SHUTDOWN    = 1006      ; Bouton radio Extinction (Shutdown)
IDC_REBOOT      = 1007      ; Bouton radio Redémarrage (Reboot)

; Identifiants des options du menu contextuel (System Tray)
IDM_RESTORE     = 1501      ; Menu : Restaurer la fenêtre
IDM_ABOUT       = 1502      ; Menu : À propos
IDM_RESET       = 1503      ; Menu : Réinitialiser
IDM_EXIT        = 1504      ; Menu : Quitter

; Identifiants des ressources et minuteur
ID_TIMER        = 2001      ; Identifiant du minuteur Windows
IDI_SLEEP       = 3001      ; Identifiant de l'icône principale
IDI_TRAY        = 0         ; Identifiant de l'icône dans le Tray
IDB_MIN         = 3501      ; Identifiant de l'image du bouton réduction

TIME_INTERVAL   = 1000      ; Intervalle du minuteur : 1000 millisecondes (1 seconde)
BUFF_SIZE       = 12        ; Taille du tampon texte pour la conversion

; Identifiants de la boîte de dialogue "À propos"
IDD_ABOUT       = 10000     ; Boîte de dialogue À propos
IDC_ABOUT_OK    = 10001     ; Bouton OK de la boîte À propos

; ============================================================================
; SECTION DES DONNEES INITIALISEES ET NON INITIALISEES
; ============================================================================
section '.data' data readable writeable

  DlgName       db "MainDlg", 0                             ; Nom de la ressource du dialogue principal
  lpszName      db "Good Night v1.0", 0                     ; Titre par défaut de l'application
  ddSeconds     dd 0                                        ; Compteur des secondes restantes (0 à 59)
  ddAction      dd EWX_SHUTDOWN or EWX_FORCE                ; Action système par défaut (Extinction forcée)

  ; Chaînes de caractères pour le menu contextuel et les affichages
  szMainWin     db "&Main window", 0                        ; Option menu : Fenêtre principale
  szResetTimer  db "&Reset timer", 0                        ; Option menu : Réinitialiser
  szAbout       db "&About ...", 0                          ; Option menu : À propos
  szExit        db "E&xit", 0                               ; Option menu : Quitter
  szLeft        db "Left: ", 0                              ; Texte du temps restant
  szColon       db ":", 0                                   ; Séparateur minute/seconde
  szShutdownPriv db "SeShutdownPrivilege", 0                ; Nom du privilège d'extinction Windows NT

  ; Variables de travail globales (non initialisées)
  hInstance     dd ?                                        ; Handle de l'instance du module
  TimeLeft      dd ?                                        ; Temps restant en minutes
  buffer        rb BUFF_SIZE                                ; Tampon de conversion numérique en texte
  hToken        dd ?                                        ; Handle du jeton d'accès utilisateur (NT)
  tp            TOKEN_PRIVILEGES                            ; Structure de privilèges pour l'arrêt système
  note          NOTIFYICONDATA                              ; Structure pour l'icône de notification (Tray)
  hPopupMenu    dd ?                                        ; Handle du menu contextuel
  hBtnMin       dd ?                                        ; Handle du bouton de réduction
  lpszSeconds   rb 4                                        ; Tampon texte pour les secondes
  lpszCaption   rb 32                                       ; Tampon texte pour le titre dynamique
  hMainIcon     dd ?                                        ; Handle de l'icône chargée

; ============================================================================
; SECTION DU CODE EXECUTABLE (INSTRUCTIONS ASSEMBLEUR)
; ============================================================================
section '.code' code readable executable

; Point d'entrée de l'application
start:
    invoke  GetModuleHandle, NULL                           ; Récupère le handle de l'instance actuelle
    mov     [hInstance], eax                                ; Sauvegarde le handle d'instance
    invoke  DialogBoxParam, [hInstance], DlgName, NULL, DlgProc, NULL ; Crée et affiche la boîte de dialogue
    invoke  ExitProcess, eax                                ; Quitte le programme en retournant le code d'erreur

; ----------------------------------------------------------------------------
; Procédure de traitement des messages de la boîte de dialogue principale
; ----------------------------------------------------------------------------
proc DlgProc hWnd, uMsg, wParam, lParam
    local pt:POINT                                          ; Variable locale pour les coordonnées de la souris

    ; Structure conditionnelle d'aiguillage des messages Windows
    cmp     [uMsg], WM_INITDIALOG                          ; Le dialogue vient d'être créé ?
    je      .wm_initdialog
    cmp     [uMsg], WM_CLOSE                               ; Demande de fermeture de la fenêtre ?
    je      .wm_close
    cmp     [uMsg], WM_SIZE                                ; Changement de taille (réduction) ?
    je      .wm_size
    cmp     [uMsg], WM_COMMAND                             ; Action sur un bouton ou menu ?
    je      .wm_command
    cmp     [uMsg], WM_SHELLNOTIFY                         ; Événement sur l'icône du Tray ?
    je      .wm_shellnotify
    cmp     [uMsg], WM_TIMER                               ; Signal du minuteur (chaque seconde) ?
    je      .wm_timer

    xor     eax, eax                                        ; Retourne FALSE pour les messages non traités
    ret

; Initialisation des composants de l'interface
.wm_initdialog:
    invoke  GetDlgItem, [hWnd], IDC_SHUTDOWN               ; Récupère le bouton radio 'Shutdown'
    invoke  SendMessage, eax, BM_SETCHECK, BST_CHECKED, 0   ; Coche l'option 'Shutdown' par défaut

    invoke  GetDlgItem, [hWnd], IDC_MIN                     ; Récupère le bouton de réduction
    push    eax                                             ; Empile le handle du bouton
    invoke  LoadBitmap, [hInstance], IDB_MIN               ; Charge l'image BMP du bouton
    pop     edx                                             ; Dépile le handle du bouton dans EDX
    invoke  SendMessage, edx, BM_SETIMAGE, IMAGE_BITMAP, eax ; Applique l'image BMP sur le bouton

    invoke  LoadIcon, [hInstance], IDI_SLEEP                ; Charge l'icône de l'application
    mov     [hMainIcon], eax                                ; Enregistre le handle de l'icône
    invoke  SendMessage, [hWnd], WM_SETICON, ICON_BIG, eax  ; Applique l'icône à la fenêtre

    ; Création du menu contextuel du System Tray
    invoke  CreatePopupMenu                                 ; Crée un menu contextuel vide
    mov     [hPopupMenu], eax                               ; Sauvegarde le handle du menu
    invoke  AppendMenu, [hPopupMenu], MF_STRING, IDM_RESTORE, szMainWin ; Ajoute 'Main window'
    invoke  AppendMenu, [hPopupMenu], MF_STRING, IDM_RESET, szResetTimer ; Ajoute 'Reset timer'
    invoke  AppendMenu, [hPopupMenu], MF_SEPARATOR, NULL, NULL           ; Ajoute une ligne de séparation
    invoke  AppendMenu, [hPopupMenu], MF_STRING, IDM_ABOUT, szAbout     ; Ajoute 'About ...'
    invoke  AppendMenu, [hPopupMenu], MF_SEPARATOR, NULL, NULL           ; Ajoute une ligne de séparation
    invoke  AppendMenu, [hPopupMenu], MF_STRING, IDM_EXIT, szExit       ; Ajoute 'Exit'

    ; Configuration de l'icône dans la zone de notification (System Tray)
    mov     [note.cbSize], sizeof.NOTIFYICONDATA            ; Taille de la structure
    push    [hWnd]
    pop     [note.hwnd]                                     ; Associe le handle de fenêtre
    mov     [note.uID], IDI_TRAY                            ; ID de l'icône dans le tray
    mov     [note.uFlags], NIF_ICON + NIF_MESSAGE + NIF_TIP ; Activer icône, messages et info-bulle
    mov     [note.uCallbackMessage], WM_SHELLNOTIFY         ; Message personnalisé à recevoir
    push    [hMainIcon]
    pop     [note.hIcon]                                    ; Applique l'icône
    invoke  lstrcpy, note.szTip, lpszName                   ; Définit le texte de l'info-bulle
    invoke  Shell_NotifyIcon, NIM_ADD, note                 ; Ajoute l'icône dans la barre des tâches

    mov     eax, TRUE                                       ; Retourne TRUE pour confirmer le traitement
    ret

; Destruction et libération lors de la fermeture
.wm_close:
    invoke  Shell_NotifyIcon, NIM_DELETE, note              ; Supprime l'icône du System Tray
    invoke  DestroyMenu, [hPopupMenu]                       ; Détruit le menu contextuel en mémoire
    invoke  KillTimer, [hWnd], ID_TIMER                     ; Arrête le minuteur s'il est actif
    invoke  EndDialog, [hWnd], NULL                         ; Ferme la boîte de dialogue
    mov     eax, TRUE
    ret

; Masquage de la fenêtre lors de la réduction
.wm_size:
    cmp     [wParam], SIZE_MINIMIZED                        ; La fenêtre est-elle réduite ?
    jne     @f
    invoke  ShowWindow, [hWnd], SW_MINIMIZE                 ; Réduit la fenêtre
    invoke  ShowWindow, [hWnd], SW_HIDE                     ; Masque complètement la fenêtre (visible dans le Tray)
@@:
    mov     eax, TRUE
    ret

; Traitement des clics sur les menus et boutons
.wm_command:
    mov     eax, [wParam]                                   ; Récupère l'ID de la commande
    cmp     [lParam], 0                                     ; Si lParam == 0, la commande provient du menu
    jne     .control_msg

    ; --- Traitement des éléments du menu ---
    movzx   eax, ax
    cmp     eax, IDM_RESTORE
    je      .idm_restore
    cmp     eax, IDM_RESET
    je      .idm_reset
    cmp     eax, IDM_ABOUT
    je      .idm_about
    
    invoke  SendMessage, [hWnd], WM_CLOSE, NULL, NULL       ; Option 'Exit' du menu
    mov     eax, TRUE
    ret

.idm_restore:
    invoke  ShowWindow, [hWnd], SW_RESTORE                  ; Restaure l'affichage de la fenêtre
    mov     eax, TRUE
    ret
.idm_reset:
    invoke  SendMessage, [hWnd], WM_COMMAND, IDC_RESET, 1   ; Déclenche l'action du bouton Reset
    mov     eax, TRUE
    ret
.idm_about:
    invoke  DialogBoxParam, [hInstance], IDD_ABOUT, NULL, AboutProc, NULL ; Ouvre la fenêtre À propos
    mov     eax, TRUE
    ret

    ; --- Traitement des clics sur les boutons de l'interface ---
.control_msg:
    movzx   eax, ax
    cmp     eax, IDC_GO
    je      .idc_go
    cmp     eax, IDC_RESET
    je      .idc_reset
    cmp     eax, IDC_MIN
    je      .idc_min
    cmp     eax, IDC_EXIT
    je      .idc_exit
    cmp     eax, IDC_SHUTDOWN
    je      .idc_shutdown
    cmp     eax, IDC_REBOOT
    je      .idc_reboot
    
    mov     eax, TRUE
    ret

; Bouton GO : Démarrer le décompte
.idc_go:
    invoke  GetDlgItemInt, [hWnd], IDC_TIME, NULL, FALSE    ; Lit les minutes saisies par l'utilisateur
    mov     [TimeLeft], eax                                 ; Enregistre le temps en minutes
    invoke  SetTimer, [hWnd], ID_TIMER, TIME_INTERVAL, NULL ; Démarre le minuteur (1 tick par seconde)
    invoke  SendMessage, [hWnd], WM_TIMER, ID_TIMER, NULL   ; Exécute le premier tick immédiatement
    stdcall EnableWindows, [hWnd], FALSE                    ; Désactive les champs de l'IHM pendant le décompte
    mov     eax, TRUE
    ret

; Bouton RESET : Réinitialiser le minuteur
.idc_reset:
    mov     dword [ddSeconds], 0                            ; Remet les secondes à zéro
    invoke  KillTimer, [hWnd], ID_TIMER                     ; Arrête le minuteur
    invoke  SetDlgItemInt, [hWnd], IDC_TIME, 0, FALSE       ; Remet le champ à 0
    invoke  SendMessage, [hWnd], WM_SETTEXT, NULL, lpszName ; Restaure le titre de fenêtre par défaut
    invoke  lstrcpy, note.szTip, lpszName                   ; Restaure le texte de l'info-bulle du Tray
    invoke  Shell_NotifyIcon, NIM_MODIFY, note              ; Met à jour l'info-bulle du Tray
    stdcall EnableWindows, [hWnd], TRUE                     ; Réactive les contrôles de l'interface
    invoke  GetDlgItem, [hWnd], IDC_TIME                   ; Récupère le champ texte
    invoke  SetFocus, eax                                   ; Met le focus du curseur sur le champ texte
    mov     eax, TRUE
    ret

; Bouton de réduction
.idc_min:
    invoke  SendMessage, [hWnd], WM_SIZE, SIZE_MINIMIZED, 0 ; Simule un événement de réduction
    mov     eax, TRUE
    ret

; Bouton Quitter
.idc_exit:
    invoke  SendMessage, [hWnd], WM_CLOSE, NULL, NULL       ; Envoie le message de fermeture
    mov     eax, TRUE
    ret

; Bouton Radio Shutdown
.idc_shutdown:
    mov     [ddAction], EWX_SHUTDOWN or EWX_FORCE           ; Définit l'action sur Arrêt système forcé
    mov     eax, TRUE
    ret

; Bouton Radio Reboot
.idc_reboot:
    mov     [ddAction], EWX_REBOOT or EWX_FORCE             ; Définit l'action sur Redémarrage système forcé
    mov     eax, TRUE
    ret

; Gestion des clics de souris sur l'icône du Tray
.wm_shellnotify:
    cmp     [wParam], IDI_TRAY                             ; Vérifie que l'événement vient de notre icône
    jne     .shell_end
    cmp     [lParam], WM_RBUTTONDOWN                       ; Clic droit ?
    je      .tray_rbutton
    cmp     [lParam], WM_LBUTTONDOWN                       ; Clic gauche ?
    je      .tray_lbutton
    jmp     .shell_end

; Affichage du menu contextuel au clic droit
.tray_rbutton:
    lea     eax, [pt]
    invoke  GetCursorPos, eax                               ; Récupère la position actuelle du curseur
    invoke  SetForegroundWindow, [hWnd]                     ; Met la fenêtre au premier plan
    invoke  TrackPopupMenu, [hPopupMenu], TPM_RIGHTALIGN, [pt.x], [pt.y], NULL, [hWnd], NULL ; Affiche le menu
    invoke  PostMessage, [hWnd], WM_NULL, 0, 0              ; Envoie un message nul pour libérer le menu
    jmp     .shell_end

; Restauration au clic gauche
.tray_lbutton:
    invoke  SendMessage, [hWnd], WM_COMMAND, IDM_RESTORE, 0 ; Restaure la fenêtre principale
.shell_end:
    mov     eax, TRUE
    ret

; Exécution à chaque seconde (Signal WM_TIMER)
.wm_timer:
    cmp     [wParam], ID_TIMER                              ; Vérifie l'identifiant du minuteur
    jne     .timer_end

    cmp     [TimeLeft], -1                                  ; Le temps est-il écoulé ?
    jne     .timer_tick

    stdcall ShutDownProc                                    ; Déclenche l'extinction/redémarrage du PC
    invoke  PostMessage, [hWnd], WM_CLOSE, NULL, NULL       ; Ferme l'application
    jmp     .timer_end

; Actualisation de l'affichage du compte à rebours
.timer_tick:
    invoke  SetDlgItemInt, [hWnd], IDC_TIME, [TimeLeft], FALSE ; Met à jour la valeur des minutes
    invoke  GetDlgItemText, [hWnd], IDC_TIME, buffer, BUFF_SIZE - 1 ; Lit la valeur sous forme de texte
    mov     byte [lpszCaption], 0                           ; Reinitialise la chaîne de titre
    invoke  lstrcat, lpszCaption, szLeft                    ; Concatène "Left: "
    invoke  lstrcat, lpszCaption, buffer                    ; Concatène les minutes
    invoke  lstrcat, lpszCaption, szColon                   ; Concatène ":"
    mov     dword [lpszSeconds], 0                          ; Vide le tampon des secondes
    
    cinvoke wsprintf, lpszSeconds, "%02d", [ddSeconds]      ; Formate les secondes sur 2 chiffres (ex: 05)

    invoke  lstrcat, lpszCaption, lpszSeconds               ; Concatène les secondes
    invoke  SendMessage, [hWnd], WM_SETTEXT, 0, lpszCaption ; Met à jour la barre de titre de la fenêtre
    invoke  lstrcpy, note.szTip, lpszCaption                ; Met à jour le texte de l'info-bulle du Tray
    invoke  Shell_NotifyIcon, NIM_MODIFY, note              ; Applique la modification de l'info-bulle

    cmp     [ddSeconds], 0                                  ; Vérifie si la minute actuelle est terminée
    jne     .dec_sec
    mov     [ddSeconds], 60                                 ; Réinitialise les secondes à 60
    dec     [TimeLeft]                                      ; Décrémente d'une minute
.dec_sec:
    dec     [ddSeconds]                                     ; Décrémente d'une seconde

.timer_end:
    mov     eax, TRUE
    ret
endp

; ----------------------------------------------------------------------------
; Procédure pour la boîte de dialogue "À propos"
; ----------------------------------------------------------------------------
proc AboutProc hWnd, uMsg, wParam, lParam
    cmp     [uMsg], WM_COMMAND                             ; Interaction avec un bouton ?
    je      .wm_command
    cmp     [uMsg], WM_CLOSE                               ; Fermeture de la boîte ?
    je      .wm_close

    xor     eax, eax
    ret

.wm_command:
    movzx   eax, ax
    cmp     eax, IDC_ABOUT_OK                              ; Clic sur le bouton OK ?
    jne     @f
    invoke  SendMessage, [hWnd], WM_CLOSE, 0, 0             ; Ferme la boîte
@@:
    mov     eax, TRUE
    ret

.wm_close:
    invoke  EndDialog, [hWnd], NULL                         ; Détruit la boîte de dialogue À propos
    mov     eax, TRUE
    ret
endp

; ----------------------------------------------------------------------------
; Procédure d'arrêt du système Windows (Gestion des privilèges)
; ----------------------------------------------------------------------------
proc ShutDownProc
    invoke  GetVersion                                     ; Récupère la version de Windows
    test    eax, 80000000h                                  ; Teste si nous sommes sous Windows 9x ou NT
    jnz     .win9x                                          ; Si Win9x, pas besoin de privilèges d'accès

    ; Activation des privilèges d'arrêt système pour Windows NT / 2000 / XP et versions ultérieures
    invoke  GetCurrentProcess                               ; Récupère le handle du processus actuel
    invoke  OpenProcessToken, eax, TOKEN_ADJUST_PRIVILEGES + TOKEN_QUERY, hToken ; Ouvre le jeton d'accès
    invoke  LookupPrivilegeValue, 0, szShutdownPriv, tp.Privileges ; Obtient le LUID pour SeShutdownPrivilege
    mov     [tp.PrivilegeCount], 1                          ; Définit 1 seul privilège à modifier
    mov     [tp.Privileges+8], SE_PRIVILEGE_ENABLED         ; Active ce privilège
    invoke  AdjustTokenPrivileges, [hToken], FALSE, tp, 0, NULL, 0 ; Applique le privilège au processus

.win9x:
    invoke  ExitWindowsEx, [ddAction], 0FFFFh               ; Exécute l'ordre d'arrêt ou de redémarrage
    ret
endp

; ----------------------------------------------------------------------------
; Activer ou désactiver les champs de l'interface graphique
; ----------------------------------------------------------------------------
proc EnableWindows hWnd, bEnable
    invoke  GetDlgItem, [hWnd], IDC_SHUTDOWN
    invoke  EnableWindow, eax, [bEnable]                    ; Active/Désactive l'option Shutdown
    invoke  GetDlgItem, [hWnd], IDC_REBOOT
    invoke  EnableWindow, eax, [bEnable]                    ; Active/Désactive l'option Reboot
    invoke  GetDlgItem, [hWnd], IDC_GO
    invoke  EnableWindow, eax, [bEnable]                    ; Active/Désactive le bouton GO
    invoke  GetDlgItem, [hWnd], IDC_TIME
    invoke  EnableWindow, eax, [bEnable]                    ; Active/Désactive le champ de saisie
    ret
endp

; ============================================================================
; SECTION IMPORT : DEFINITION DES BIBLIOTHEQUES DYNAMIQUES (DLL)
; ============================================================================
section '.idata' import data readable

  ; Déclaration des bibliothèques système nécessaires
  library kernel32, 'KERNEL32.DLL', \
          user32,   'USER32.DLL', \
          advapi32, 'ADVAPI32.DLL', \
          shell32,  'SHELL32.DLL'

  ; Inclusions des définitions de fonctions API fournies par FASM
  include 'api\kernel32.inc'
  include 'api\user32.inc'
  include 'api\advapi32.inc'
  include 'api\shell32.inc'

; ============================================================================
; SECTION RESSOURCES INTÉGRÉES (DIALOGUES, BOUTONS, ICÔNES ET BITMAPS)
; ============================================================================
section '.rsrc' resource data readable

  ; Table des répertoires de ressources
  directory RT_DIALOG, dialogs, \
            RT_ICON, icons, \
            RT_GROUP_ICON, group_icons, \
            RT_BITMAP, bitmaps

  ; Liste des boîtes de dialogue
  resource dialogs, \
           100, dlg_main, \
           10000, dlg_about

  ; Liste des icônes individuelles
  resource icons, \
           1, icon_data

  ; Liste des groupes d'icônes
  resource group_icons, \
           3001, icon_group

  ; Liste des images Bitmap
  resource bitmaps, \
           3501, bmp_min

  ; --------------------------------------------------------------------------
  ; Description de l'interface graphique : Boîte de dialogue principale
  ; --------------------------------------------------------------------------
  dialog dlg_main, 'Good Night v1.0', 6, 5, 110, 75, DS_MODALFRAME or WS_POPUP or WS_CAPTION or WS_SYSMENU
    dialogitem 'STATIC', 'after:', IDC_STC1, 10, 40, 22, 9, WS_VISIBLE
    dialogitem 'EDIT', '0', IDC_TIME, 38, 36, 44, 15, WS_VISIBLE or WS_BORDER or ES_NUMBER or ES_RIGHT
    dialogitem 'STATIC', 'min.', IDC_STC2, 88, 40, 16, 9, WS_VISIBLE
    dialogitem 'BUTTON', 'GO', IDC_GO, 4, 57, 38, 15, WS_VISIBLE or BS_DEFPUSHBUTTON
    dialogitem 'BUTTON', 'Reset', IDC_RESET, 44, 57, 32, 15, WS_VISIBLE
    dialogitem 'BUTTON', 'Exit', IDC_EXIT, 78, 57, 28, 15, WS_VISIBLE
    dialogitem 'BUTTON', '', IDC_MIN, 84, 1, 22, 19, WS_VISIBLE or BS_BITMAP
    dialogitem 'BUTTON', 'Shutdown', IDC_SHUTDOWN, 4, 7, 66, 9, WS_VISIBLE or BS_AUTORADIOBUTTON
    dialogitem 'BUTTON', 'Reboot computer', IDC_REBOOT, 4, 22, 104, 9, WS_VISIBLE or BS_AUTORADIOBUTTON
  enddialog

  ; --------------------------------------------------------------------------
  ; Description de l'interface graphique : Boîte de dialogue "À propos"
  ; --------------------------------------------------------------------------
  dialog dlg_about, 'About', 6, 5, 167, 115, DS_MODALFRAME or WS_POPUP or WS_CAPTION or WS_SYSMENU
    dialogitem 'BUTTON', '', IDC_GRP1, 2, 3, 162, 89, WS_VISIBLE or BS_GROUPBOX
    dialogitem 'STATIC', '#3001', IDC_IMG1, 8, 12, 22, 19, WS_VISIBLE or SS_ICON
    dialogitem 'STATIC', 'Good Night', IDC_STC3, 40, 16, 114, 9, WS_VISIBLE or SS_CENTER
    dialogitem 'STATIC', 'version 1.0', IDC_STC4, 68, 35, 56, 9, WS_VISIBLE or SS_CENTER
    dialogitem 'STATIC', '(c) 2005 by Anfiska aka -=LoToS=-', IDC_STC5, 10, 53, 148, 11, WS_VISIBLE or SS_CENTER
    dialogitem 'STATIC', 'anisovandre@gmail.com', IDC_STC6, 70, 72, 56, 9, WS_VISIBLE
    dialogitem 'BUTTON', 'OK', IDC_ABOUT_OK, 66, 97, 42, 13, WS_VISIBLE or BS_PUSHBUTTON
  enddialog

  ; --------------------------------------------------------------------------
  ; Liens vers les fichiers d'images externes intégrés lors de la compilation
  ; --------------------------------------------------------------------------
  icon icon_group, icon_data, 'clock.ico'                   ; Intègre le fichier icône clock.ico
  bitmap bmp_min, 'img_min.bmp'                             ; Intègre l'image bitmap img_min.bmp