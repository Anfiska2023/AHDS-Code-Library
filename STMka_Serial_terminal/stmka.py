# =============================================================================
# STM32 SERIAL INTERFACE
# =============================================================================
#
# Petite interface graphique permettant de communiquer avec un microcontrôleur
# STM32, PIC, AVR ou tout autre équipement utilisant une liaison série.
#
# Fonctions principales :
#   - Détection automatique des ports COM disponibles
#   - Sélection du débit de communication (Baud Rate)
#   - Connexion / déconnexion du port série
#   - Transmission de données
#   - Réception de données en temps réel
#   - Affichage des données reçues dans un terminal
#   - Effacement du terminal
#   - Actualisation de la liste des ports COM
#
# Interface graphique : Tkinter
# Communication série : PySerial
#
# La lecture série est exécutée dans un thread séparé.
# Les données sont transférées au thread principal de Tkinter au moyen
# d'une Queue afin d'éviter de modifier directement les widgets depuis
# le thread de communication.
#
# =============================================================================


# -----------------------------------------------------------------------------
# IMPORTATION DES BIBLIOTHÈQUES
# -----------------------------------------------------------------------------

import tkinter as tk
# Bibliothèque standard Python utilisée pour créer l'interface graphique.

from tkinter import messagebox, ttk
# messagebox : affichage des boîtes d'information, d'erreur et d'avertissement.
# ttk        : widgets graphiques améliorés, notamment les listes déroulantes.

import serial
# Bibliothèque PySerial utilisée pour la communication série.

import serial.tools.list_ports
# Permet d'obtenir automatiquement la liste des ports COM disponibles.

import threading
# Permet d'exécuter la lecture du port série dans un thread séparé afin de
# ne pas bloquer l'interface graphique.

import queue
# File d'attente thread-safe permettant de transférer les données reçues
# depuis le thread série vers le thread principal Tkinter.


# =============================================================================
# CLASSE PRINCIPALE DE L'APPLICATION
# =============================================================================

class SerialApp:

    def __init__(self, root):

        # ---------------------------------------------------------------------
        # INITIALISATION DE LA FENÊTRE PRINCIPALE
        # ---------------------------------------------------------------------

        self.root = root

        # Définit le titre affiché dans la barre supérieure de la fenêtre.
        self.root.title("STM32 Serial Interface")

        # Dimensions initiales de la fenêtre.
        self.root.geometry("430x610")

        # Empêche éventuellement une réduction excessive de la fenêtre.
        self.root.minsize(430, 610)


        # ---------------------------------------------------------------------
        # VARIABLES DE GESTION DE LA COMMUNICATION SÉRIE
        # ---------------------------------------------------------------------

        # Objet représentant le port série.
        # Aucun port n'est ouvert au démarrage.
        self.serial_port = None

        # Indique l'état actuel de la connexion.
        self.is_connected = False

        # Queue utilisée pour transférer les données reçues du thread série
        # vers le thread graphique principal.
        self.receive_queue = queue.Queue()


        # ---------------------------------------------------------------------
        # SÉLECTION DU PORT COM
        # ---------------------------------------------------------------------

        self.port_label = tk.Label(
            root,
            text="Port COM :"
        )

        self.port_label.pack(pady=5)


        # Liste déroulante contenant les ports COM détectés.
        self.port_combobox = ttk.Combobox(
            root,
            state="readonly",
            width=20
        )

        self.port_combobox.pack(pady=5)


        # Recherche automatiquement les ports disponibles au démarrage.
        self.refresh_ports()


        # ---------------------------------------------------------------------
        # SÉLECTION DU BAUD RATE
        # ---------------------------------------------------------------------

        self.baud_label = tk.Label(
            root,
            text="Baud Rate :"
        )

        self.baud_label.pack(pady=5)


        # Liste des vitesses de communication proposées.
        baud_rates = [
            "9600",
            "19200",
            "38400",
            "57600",
            "115200"
        ]


        self.baud_combobox = ttk.Combobox(
            root,
            values=baud_rates,
            state="readonly",
            width=20
        )

        self.baud_combobox.pack(pady=5)


        # Valeur sélectionnée par défaut.
        self.baud_combobox.set("9600")


        # ---------------------------------------------------------------------
        # BOUTON CONNECT
        # ---------------------------------------------------------------------

        self.connect_button = tk.Button(
            root,
            text="Connect",
            command=self.connect_serial
        )

        self.connect_button.pack(pady=5)


        # ---------------------------------------------------------------------
        # BOUTON DISCONNECT
        # ---------------------------------------------------------------------

        self.disconnect_button = tk.Button(
            root,
            text="Disconnect",
            command=self.disconnect_serial,
            state=tk.DISABLED
        )

        self.disconnect_button.pack(pady=5)


        # ---------------------------------------------------------------------
        # ZONE D'ENVOI DES DONNÉES
        # ---------------------------------------------------------------------

        self.data_label = tk.Label(
            root,
            text="Envoyer des données :"
        )

        self.data_label.pack(pady=5)


        # Zone dans laquelle l'utilisateur saisit le texte à transmettre.
        self.data_entry = tk.Entry(
            root,
            width=35
        )

        self.data_entry.pack(pady=5)


        # ---------------------------------------------------------------------
        # BOUTON ENVOYER
        # ---------------------------------------------------------------------

        self.send_button = tk.Button(
            root,
            text="Envoyer",
            command=self.send_data
        )

        self.send_button.pack(pady=10)


        # ---------------------------------------------------------------------
        # ZONE D'AFFICHAGE DES DONNÉES REÇUES
        # ---------------------------------------------------------------------

        self.output_label = tk.Label(
            root,
            text="Données reçues :"
        )

        self.output_label.pack(pady=5)


        # Création d'un cadre contenant la zone terminal et sa scrollbar.
        self.output_frame = tk.Frame(root)

        self.output_frame.pack(
            pady=5,
            padx=10,
            fill=tk.BOTH,
            expand=True
        )


        # Barre de défilement verticale.
        self.scrollbar = tk.Scrollbar(
            self.output_frame
        )

        self.scrollbar.pack(
            side=tk.RIGHT,
            fill=tk.Y
        )


        # Zone terminal affichant les données reçues.
        self.output_text = tk.Text(
            self.output_frame,
            height=12,
            width=50,
            yscrollcommand=self.scrollbar.set
        )

        self.output_text.pack(
            side=tk.LEFT,
            fill=tk.BOTH,
            expand=True
        )


        # Associe la scrollbar au terminal.
        self.scrollbar.config(
            command=self.output_text.yview
        )


        # ---------------------------------------------------------------------
        # BOUTON CLEAR
        # ---------------------------------------------------------------------

        self.clear_button = tk.Button(
            root,
            text="Clear",
            command=self.clear_terminal
        )

        self.clear_button.pack(pady=5)


        # ---------------------------------------------------------------------
        # BOUTON DE RAFRAÎCHISSEMENT DES PORTS
        # ---------------------------------------------------------------------

        self.refresh_button = tk.Button(
            root,
            text="Rafraîchir les ports",
            command=self.refresh_ports
        )

        self.refresh_button.pack(pady=5)


        # ---------------------------------------------------------------------
        # SURVEILLANCE DE LA QUEUE DE RÉCEPTION
        # ---------------------------------------------------------------------

        # Lance la vérification périodique de la queue.
        #
        # Cette fonction est exécutée dans le thread principal Tkinter
        # et peut donc modifier les widgets en toute sécurité.
        self.root.after(
            100,
            self.process_received_data
        )


    # =========================================================================
    # ACTUALISATION DES PORTS COM
    # =========================================================================

    def refresh_ports(self):

        """
        Recherche les ports série disponibles et actualise la liste déroulante.
        """

        # Obtient la liste de tous les ports série détectés.
        ports = [
            port.device
            for port in serial.tools.list_ports.comports()
        ]


        # Place la liste dans la Combobox.
        self.port_combobox["values"] = ports


        # Sélectionne automatiquement le premier port trouvé.
        if ports:

            self.port_combobox.set(
                ports[0]
            )

        else:

            # Aucun port détecté.
            self.port_combobox.set("")


    # =========================================================================
    # CONNEXION AU PORT SÉRIE
    # =========================================================================

    def connect_serial(self):

        """
        Ouvre le port série sélectionné.
        """

        try:

            # Récupère le nom du port sélectionné.
            port = self.port_combobox.get()


            # Vérifie qu'un port a réellement été sélectionné.
            if not port:

                messagebox.showwarning(
                    "Port COM",
                    "Aucun port COM n'est disponible."
                )

                return


            # Récupère le baud rate sélectionné.
            baud_rate = int(
                self.baud_combobox.get()
            )


            # Ouvre le port série.
            self.serial_port = serial.Serial(
                port=port,
                baudrate=baud_rate,
                timeout=0.2
            )


            # Indique que la connexion est active.
            self.is_connected = True


            # Désactive le bouton Connect.
            self.connect_button.config(
                state=tk.DISABLED
            )


            # Active le bouton Disconnect.
            self.disconnect_button.config(
                state=tk.NORMAL
            )


            # -----------------------------------------------------------------
            # CRÉATION DU THREAD DE RÉCEPTION
            # -----------------------------------------------------------------

            # Le thread exécute read_serial() indépendamment de Tkinter.
            #
            # daemon=True signifie que le thread sera automatiquement arrêté
            # lorsque l'application principale sera fermée.
            receive_thread = threading.Thread(
                target=self.read_serial,
                daemon=True
            )

            receive_thread.start()


            # Message de confirmation.
            messagebox.showinfo(
                "Connexion réussie",
                f"Connecté à {port} à {baud_rate} baud."
            )


        except serial.SerialException as error:

            messagebox.showerror(
                "Erreur série",
                str(error)
            )


        except ValueError:

            messagebox.showerror(
                "Erreur",
                "Le Baud Rate sélectionné est invalide."
            )


        except Exception as error:

            messagebox.showerror(
                "Erreur",
                str(error)
            )


    # =========================================================================
    # DÉCONNEXION DU PORT SÉRIE
    # =========================================================================

    def disconnect_serial(self):

        """
        Ferme proprement la connexion série.
        """

        if self.serial_port and self.is_connected:

            # Informe le thread que la connexion doit être arrêtée.
            self.is_connected = False


            try:

                # Ferme le port série.
                if self.serial_port.is_open:

                    self.serial_port.close()

            except serial.SerialException:

                pass


            # Supprime la référence vers l'objet série.
            self.serial_port = None


            # Réactive Connect.
            self.connect_button.config(
                state=tk.NORMAL
            )


            # Désactive Disconnect.
            self.disconnect_button.config(
                state=tk.DISABLED
            )


            messagebox.showinfo(
                "Déconnexion réussie",
                "Le port série a été déconnecté."
            )


    # =========================================================================
    # TRANSMISSION DE DONNÉES
    # =========================================================================

    def send_data(self):

        """
        Envoie les données saisies par l'utilisateur sur le port série.
        """

        if not self.is_connected or not self.serial_port:

            messagebox.showwarning(
                "Non connecté",
                "Veuillez d'abord connecter le port série."
            )

            return


        # Récupère le contenu de la zone de saisie.
        data = self.data_entry.get()


        # Ne transmet rien si le champ est vide.
        if not data:

            return


        try:

            # Conversion de la chaîne Python en bytes.
            encoded_data = data.encode("utf-8")


            # Transmission des bytes.
            self.serial_port.write(
                encoded_data
            )


            # Attend que le buffer de transmission soit vidé.
            self.serial_port.flush()


        except serial.SerialException as error:

            messagebox.showerror(
                "Erreur de transmission",
                str(error)
            )


    # =========================================================================
    # THREAD DE RÉCEPTION SÉRIE
    # =========================================================================

    def read_serial(self):

        """
        Lecture des données série dans un thread séparé.

        IMPORTANT :
        Cette fonction ne modifie jamais directement les widgets Tkinter.

        Les données reçues sont placées dans receive_queue.
        """

        while self.is_connected:

            try:

                # Vérifie que le port existe et est toujours ouvert.
                if (
                    self.serial_port
                    and self.serial_port.is_open
                    and self.serial_port.in_waiting > 0
                ):

                    # Lit une ligne du port série.
                    raw_data = self.serial_port.readline()


                    # Conversion des bytes en texte.
                    #
                    # errors="replace" évite de faire planter le programme
                    # lorsqu'un caractère reçu n'est pas UTF-8 valide.
                    data = raw_data.decode(
                        "utf-8",
                        errors="replace"
                    ).rstrip("\r\n")


                    # Ajoute la donnée à la Queue.
                    self.receive_queue.put(
                        data
                    )


            except serial.SerialException as error:

                # Envoie également l'erreur au terminal.
                self.receive_queue.put(
                    f"[Erreur série] {error}"
                )

                break


            except Exception as error:

                self.receive_queue.put(
                    f"[Erreur] {error}"
                )

                break


    # =========================================================================
    # MISE À JOUR SÉCURISÉE DU TERMINAL TKINTER
    # =========================================================================

    def process_received_data(self):

        """
        Lit les éléments présents dans la Queue et les affiche dans Tkinter.

        Cette méthode est appelée par root.after() et s'exécute donc
        dans le thread principal de l'interface graphique.
        """

        try:

            # Traite toutes les données actuellement disponibles.
            while True:

                data = self.receive_queue.get_nowait()


                # Affiche la donnée dans le terminal.
                self.output_text.insert(
                    tk.END,
                    data + "\n"
                )


                # Descend automatiquement vers la dernière ligne.
                self.output_text.see(
                    tk.END
                )


        except queue.Empty:

            # La queue ne contient plus de données.
            pass


        # Relance cette méthode dans 100 ms.
        self.root.after(
            100,
            self.process_received_data
        )


    # =========================================================================
    # EFFACEMENT DU TERMINAL
    # =========================================================================

    def clear_terminal(self):

        """
        Efface toutes les données affichées dans le terminal.
        """

        self.output_text.delete(
            "1.0",
            tk.END
        )


    # =========================================================================
    # FERMETURE DE L'APPLICATION
    # =========================================================================

    def close(self):

        """
        Ferme proprement le port série puis l'application.
        """

        # Arrête le thread de lecture.
        self.is_connected = False


        # Ferme le port s'il est encore ouvert.
        if self.serial_port:

            try:

                if self.serial_port.is_open:

                    self.serial_port.close()

            except serial.SerialException:

                pass


        # Ferme la fenêtre Tkinter.
        self.root.destroy()


# =============================================================================
# PROGRAMME PRINCIPAL
# =============================================================================

if __name__ == "__main__":

    # Création de la fenêtre principale Tkinter.
    root = tk.Tk()


    # Création de l'application.
    app = SerialApp(root)


    # Associe la fermeture de la fenêtre à la méthode close().
    root.protocol(
        "WM_DELETE_WINDOW",
        app.close
    )


    # Démarre la boucle principale de Tkinter.
    root.mainloop()


# =============================================================================
# DOCUMENTATION
# =============================================================================
#
# DESCRIPTION
# -----------
#
# Cette application constitue une petite interface série pour le développement
# et le diagnostic des systèmes embarqués.
#
# Elle permet de sélectionner un port COM disponible, de choisir un Baud Rate,
# d'établir une connexion série, d'envoyer des données et de visualiser en
# temps réel les informations reçues.
#
# Bien que l'application porte le nom "STM32 Serial Interface", elle peut être
# utilisée avec pratiquement tout système possédant une liaison série :
#
#   - STM32
#   - PIC
#   - AVR
#   - Arduino
#   - ESP32
#   - Convertisseur USB-UART
#   - Modules électroniques disposant d'une interface UART
#
#
# -----------------------------------------------------------------------------
# BIBLIOTHÈQUES UTILISÉES
# -----------------------------------------------------------------------------
#
# tkinter
#     Interface graphique.
#     Inclus normalement avec une installation standard de Python sous Windows.
#
# pyserial
#     Communication avec les ports série.
#
# threading
#     Exécution de la lecture série dans un thread séparé.
#
# queue
#     Communication sécurisée entre le thread série et Tkinter.
#
#
# -----------------------------------------------------------------------------
# INSTALLATION DE PYSERIAL
# -----------------------------------------------------------------------------
#
# Ouvrir CMD ou PowerShell puis exécuter :
#
#     pip install pyserial
#
#
# -----------------------------------------------------------------------------
# EXÉCUTION DU PROGRAMME PYTHON
# -----------------------------------------------------------------------------
#
# Depuis le dossier contenant le fichier :
#
#     python stm32_serial_interface.py
#
#
# =============================================================================
# CRÉATION D'UN FICHIER .EXE AVEC PYINSTALLER
# =============================================================================
#
# 1. Installer PyInstaller
# -----------------------
#
# Ouvrir CMD ou PowerShell :
#
#     pip install pyinstaller
#
#
# 2. Vérifier le programme
# ------------------------
#
# Avant de créer l'exécutable, vérifier que le programme fonctionne :
#
#     python stm32_serial_interface.py
#
#
# 3. Créer un fichier EXE unique
# ------------------------------
#
# Dans le dossier contenant le script :
#
#     pyinstaller --onefile stm32_serial_interface.py
#
#
# L'option :
#
#     --onefile
#
# demande à PyInstaller de regrouper l'application dans un seul fichier EXE.
#
#
# 4. Application graphique sans console
# --------------------------------------
#
# Pour éviter l'ouverture d'une fenêtre CMD derrière l'application :
#
#     pyinstaller --onefile --windowed stm32_serial_interface.py
#
#
# 5. Ajouter une icône
# --------------------
#
# Si le fichier d'icône s'appelle :
#
#     serial.ico
#
# utiliser :
#
#     pyinstaller --onefile --windowed --icon=serial.ico stm32_serial_interface.py
#
#
# 6. Emplacement du fichier EXE
# -----------------------------
#
# Après la compilation, PyInstaller crée plusieurs éléments :
#
#     build/
#     dist/
#     stm32_serial_interface.spec
#
# Le fichier final se trouve normalement dans :
#
#     dist/stm32_serial_interface.exe
#
#
# 7. Tester l'exécutable
# ----------------------
#
# Il est recommandé de tester le fichier EXE sur un autre ordinateur Windows,
# idéalement sans Python installé, afin de vérifier que toutes les dépendances
# nécessaires ont bien été intégrées par PyInstaller.
#
#
# -----------------------------------------------------------------------------
# COMPILATION AVEC PYCHARM
# -----------------------------------------------------------------------------
#
# Le code peut être développé et testé dans PyCharm.
#
# PyCharm est utilisé comme environnement de développement Python.
# La création du fichier EXE reste assurée par PyInstaller.
#
# Dans le terminal intégré à PyCharm, on peut utiliser exactement les mêmes
# commandes :
#
#     pip install pyserial
#     pip install pyinstaller
#
# puis :
#
#     pyinstaller --onefile --windowed stm32_serial_interface.py
#
#
# -----------------------------------------------------------------------------
# STRUCTURE RECOMMANDÉE POUR GITHUB
# -----------------------------------------------------------------------------
#
# Exemple :
#
# STM32_Serial_Interface/
#
#     stm32_serial_interface.py
#     README.md
#     serial.ico
#     Screenshot.png
#     requirements.txt
#
#
# Contenu possible de requirements.txt :
#
#     pyserial
#
#
# Installation des dépendances depuis requirements.txt :
#
#     pip install -r requirements.txt
#
#
# =============================================================================