# USB Camera — Legacy FASM to Windows 10

## Présentation

Ce projet présente la modernisation d'une application de capture d'image par caméra USB développée initialement en **2004–2005 en assembleur FASM (Flat Assembler)**.

La version originale utilisait **Video for Windows / AVICAP32** et fonctionnait avec les anciennes générations de Windows, notamment **Windows XP**.

En **2026, environ 22 ans plus tard**, le projet a été repris et modernisé afin de fonctionner sous **Windows 10**, tout en conservant l'application principale et son interface en assembleur FASM.

L'objectif n'était pas de réécrire complètement l'application dans un langage moderne, mais de conserver le code FASM et de remplacer la couche de capture vidéo devenue obsolète.

---

## Évolution du projet

### Version héritage — 2004 / 2005

Architecture originale :

    Caméra USB
        ↓
    AVICAP32 / Video for Windows
        ↓
    Application FASM / Win32 API
        ↓
    Windows XP
        ↓
    Aperçu en direct + Capture d'image

La version originale permettait :

- la connexion à une caméra ;
- l'affichage vidéo en direct ;
- l'arrêt de la capture ;
- la capture d'une image.

Le code source FASM de cette version est conservé dans ce dépôt à des fins de comparaison et d'étude.

---

## Version modernisée — 2026

La nouvelle version utilise une architecture hybride :

    Caméra USB / UVC
            ↓
    Microsoft Media Foundation
            ↓
    Moteur C++ — camlib1.dll
            ↓
    Application FASM Win32
            ↓
    Exécutable unique (.EXE)
            ↓
    Aperçu en direct + Capture d'image (.BMP)

La partie principale de l'application reste développée en **FASM / Win32 API**.

La gestion moderne de la caméra est réalisée dans une bibliothèque **C++**, développée avec **Microsoft Visual Studio 2019** et **Microsoft Media Foundation**.

---

## Interface FASM ↔ C++

La DLL expose trois fonctions principales :

    StartCameraCapture()
    StopCameraCapture()
    TakeCameraPhoto()

L'application FASM charge dynamiquement ces fonctions à l'aide de :

    LoadLibrary()
    GetProcAddress()

Un fichier `.DEF` est également utilisé afin de conserver des noms d'exportation simples et stables pour les fonctions appelées depuis FASM.

---

## DLL intégrée dans l'EXE

Une particularité du projet est que `camlib1.dll` est directement **intégrée dans les ressources de l'exécutable FASM**.

La DLL n'a donc pas besoin d'être placée manuellement à côté du programme.

Au démarrage :

1. l'application extrait la DLL dans le répertoire temporaire `%TEMP%` ;
2. la DLL est chargée avec `LoadLibrary()` ;
3. les fonctions exportées sont récupérées avec `GetProcAddress()` ;
4. le moteur Media Foundation est utilisé pour accéder à la caméra.

À la fermeture, la bibliothèque temporaire est déchargée puis supprimée.

Le résultat final peut ainsi être utilisé sous la forme d'un **seul fichier EXE**.

---

## Fonctionnalités

- Détection et utilisation d'une caméra USB/UVC
- Aperçu vidéo en direct
- Démarrage et arrêt de la caméra
- Capture d'une image au format BMP
- Interface graphique Win32 développée en FASM
- Moteur de capture développé en C++
- Microsoft Media Foundation
- DLL intégrée directement dans l'exécutable
- Exécutable autonome

---

## Contenu du repository

Le dépôt contient les deux générations du projet.

### Legacy Version

- code source FASM original ;
- version destinée aux anciennes générations de Windows ;
- exécutable de la version historique.

### Windows 10 Version

- code source FASM modernisé ;
- exécutable Windows 10 ;
- `camlib1.dll` ;
- code source C++ de la DLL ;
- projet Microsoft Visual Studio 2019 ;
- fichier `.DEF` pour les fonctions exportées.

Cette organisation permet de comparer directement l'architecture originale de **2004/2005** avec sa modernisation réalisée en **2026**.

---

## Compilation

### FASM

La partie assembleur peut être compilée avec **Flat Assembler (FASM)**.

FASM est disponible gratuitement depuis son site officiel.

### C++

Le moteur de capture `camlib1.dll` a été développé avec :

- Microsoft Visual Studio 2019
- C++
- Microsoft Media Foundation
- Win32 API

La DLL doit être compilée en **Win32 / x86** pour être utilisée avec l'application FASM 32 bits.

---

## Compatibilité

### Version héritage

Développée pour les anciennes générations de Windows et utilisée notamment sous **Windows XP**.

### Version modernisée

**Testée sous Windows 10** avec une caméra USB/UVC.

La compatibilité avec d'autres versions modernes de Windows n'est pas revendiquée tant qu'elle n'a pas été vérifiée expérimentalement.

---

## Technologies

`FASM` · `x86 Assembly` · `Win32 API` · `C++` · `Visual Studio 2019`  
`DLL` · `Microsoft Media Foundation` · `UVC` · `USB Camera` · `GDI`  
`Windows XP` · `Windows 10`

---

## Architecture

![Architecture du projet](images/camera_architecture.png)

Le diagramme ci-dessus montre l'évolution du projet entre la version héritage de **2004/2005** et la version modernisée en **2026**.

---

## Historique

**2004 / 2005** — Développement de la version originale en FASM avec Video for Windows / AVICAP32.

**2026** — Modernisation de l'application avec une architecture hybride FASM + C++ et Microsoft Media Foundation pour Windows 10.

Après plus de deux décennies, l'interface et une partie importante de l'architecture FASM d'origine ont ainsi pu être conservées tout en remplaçant la couche de capture vidéo devenue obsolète.

---

## Source Code

Les sources des deux versions sont disponibles dans ce repository.

Pour toute question ou remarque :

**AHDS**  
GitHub: `https://github.com/Anfiska2023`
