Code Library #4 — Python Serial Interface for STM32 & Embedded Systems



Interface de communication série développée en Python pour STM32 et systèmes embarqués.

Cette application permet d’établir facilement une communication entre un PC et un microcontrôleur via un port série (COM). Elle détecte automatiquement les ports disponibles et permet de sélectionner la vitesse de communication, d’envoyer des commandes et de visualiser en temps réel les données reçues.

L’interface graphique est développée avec Tkinter, tandis que la communication série est assurée par PySerial. La réception des données est exécutée dans un thread séparé afin de maintenir l’interface graphique disponible pendant les communications.

Fonctions principales : sélection du port COM et du Baud Rate, connexion/déconnexion, transmission de données, réception et affichage en temps réel, effacement du terminal et actualisation automatique des ports disponibles.

Bien que l’interface soit présentée ici avec un STM32, elle peut être utilisée avec tout microcontrôleur ou équipement disposant d’une liaison série compatible.

💻 Python • Tkinter • PySerial • Serial Communication • Embedded Systems

programm final stmka.py/ pour compilation desarchive vien.rar et idea.rar and use pycharm
