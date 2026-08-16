Compatibilité Windows

L’application a été testée avec succès sur plusieurs générations de Microsoft Windows :

Windows 98 • Windows XP • Windows 7 • Windows 8 • Windows 10

Malgré son développement en assembleur x86 et l’utilisation directe de l’API Win32, le programme reste fonctionnel sur des systèmes Windows couvrant plusieurs générations.

Windows 11 n’a pas encore été testé, je préfère donc ne pas l’indiquer comme officiellement compatible pour le moment.
Code Library #3 — Calculatrice scientifique Windows en Assembleur (FASM)

Cette application est une calculatrice scientifique développée entièrement en assembleur x86 avec FASM, en utilisant directement l’API Win32 pour la création et la gestion de l’interface graphique Windows.

Au-delà des opérations arithmétiques classiques, le programme intègre plusieurs fonctions utiles pour les développeurs et les ingénieurs :

opérations arithmétiques et fonctions trigonométriques ;
modes Degrés / Radians et fonctions trigonométriques inverses ;
gestion de la mémoire (MC, MR, MS) ;
prise en charge des nombres à virgule flottante ;
sélection et conversion entre plusieurs bases numériques : DEC / HEX / OCT / BIN ;
saisie au clavier et gestion du presse-papiers ;
interface graphique construite directement avec les fonctions de l’API Win32.

L’un des intérêts principaux de ce projet n’est pas uniquement la fonction « calculatrice », mais surtout son implémentation bas niveau en assembleur : gestion des messages Windows, création dynamique des contrôles, traitement des événements clavier, utilisation de la FPU et interaction directe avec les bibliothèques système Windows.

Le projet constitue ainsi un exemple pratique de développement d’une application Windows complète en assembleur, sans framework graphique moderne.

💻 Développé avec : FASM (Flat Assembler) / x86 Assembly / Win32 API
