import tkinter as tk  # Bibliothèque pour l'interface graphique
from tkinter import messagebox, ttk  # Widgets avancés et boîtes de message
import serial  # Pour la communication série
import serial.tools.list_ports  # Pour obtenir la liste des ports COM disponibles
import threading  # Pour exécuter la lecture série dans un thread séparé

class SerialApp:
    def __init__(self, root):
        # Initialisation de la fenêtre principale
        self.root = root
        self.root.title("STM32 Serial Interface")  # Titre de la fenêtre

        # Variables pour la gestion du port série
        self.serial_port = None  # Objet pour le port série
        self.is_connected = False  # Statut de la connexion

        # Widgets de l'interface
        # Label pour le port COM
        self.port_label = tk.Label(root, text="Port COM :")
        self.port_label.pack(pady=5)

        # Liste déroulante pour sélectionner un port COM disponible
        self.port_combobox = ttk.Combobox(root, state="readonly")
        self.port_combobox.pack(pady=5)
        self.refresh_ports()  # Remplit la liste avec les ports disponibles

        # Label pour le baud rate
        self.baud_label = tk.Label(root, text="Baud Rate :")
        self.baud_label.pack(pady=5)

        # Liste déroulante pour choisir un baud rate
        baud_rates = ["9600", "19200", "38400", "57600", "115200"]
        self.baud_combobox = ttk.Combobox(root, values=baud_rates, state="readonly")
        self.baud_combobox.pack(pady=5)
        self.baud_combobox.set("9600")  # Définit "9600" comme valeur par défaut

        # Bouton pour se connecter au port série
        self.connect_button = tk.Button(root, text="Connect", command=self.connect_serial)
        self.connect_button.pack(pady=5)

        # Bouton pour se déconnecter
        self.disconnect_button = tk.Button(root, text="Disconnect", command=self.disconnect_serial, state=tk.DISABLED)
        self.disconnect_button.pack(pady=5)

        # Zone pour entrer des données à envoyer
        self.data_label = tk.Label(root, text="Envoyer des données :")
        self.data_label.pack(pady=5)
        self.data_entry = tk.Entry(root)
        self.data_entry.pack(pady=5)

        # Bouton pour envoyer des données via le port série
        self.send_button = tk.Button(root, text="Envoyer", command=self.send_data)
        self.send_button.pack(pady=10)

        # Label pour afficher les données reçues
        self.output_label = tk.Label(root, text="Données reçues :")
        self.output_label.pack(pady=5)

        # Cadre pour le terminal déroulant (affichage des données reçues)
        self.output_frame = tk.Frame(root)
        self.output_frame.pack(pady=5)

        # Barre de défilement verticale
        self.scrollbar = tk.Scrollbar(self.output_frame)
        self.scrollbar.pack(side=tk.RIGHT, fill=tk.Y)

        # Zone de texte liée à la barre de défilement
        self.output_text = tk.Text(self.output_frame, height=10, width=50, yscrollcommand=self.scrollbar.set)
        self.output_text.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)

        # Configure la barre de défilement pour suivre la zone de texte
        self.scrollbar.config(command=self.output_text.yview)

        # Bouton pour effacer le contenu du terminal
        self.clear_button = tk.Button(root, text="Clear", command=self.clear_terminal)
        self.clear_button.pack(pady=5)

        # Bouton pour actualiser la liste des ports COM
        self.refresh_button = tk.Button(root, text="Rafraîchir les ports", command=self.refresh_ports)
        self.refresh_button.pack(pady=5)

    def refresh_ports(self):
        """Actualise la liste des ports COM disponibles."""
        ports = [port.device for port in serial.tools.list_ports.comports()]  # Obtient tous les ports disponibles
        self.port_combobox['values'] = ports  # Remplit la liste déroulante
        if ports:
            self.port_combobox.set(ports[0])  # Sélectionne le premier port par défaut

    def connect_serial(self):
        """Connecte au port série sélectionné."""
        try:
            port = self.port_combobox.get()  # Récupère le port sélectionné
            baud_rate = int(self.baud_combobox.get())  # Convertit le baud rate en entier
            self.serial_port = serial.Serial(port, baud_rate, timeout=1)  # Initialise la connexion série
            self.is_connected = True  # Met à jour le statut de connexion
            self.connect_button.config(state=tk.DISABLED)  # Désactive le bouton Connect
            self.disconnect_button.config(state=tk.NORMAL)  # Active le bouton Disconnect
            # Lance un thread séparé pour lire les données du port série
            threading.Thread(target=self.read_serial, daemon=True).start()
            # Affiche un message de confirmation
            messagebox.showinfo("Connexion réussie", f"Connecté à {port} à {baud_rate} baud.")
        except Exception as e:
            # Affiche un message d'erreur en cas de problème
            messagebox.showerror("Erreur", str(e))

    def disconnect_serial(self):
        """Déconnecte du port série."""
        if self.serial_port and self.is_connected:
            self.is_connected = False  # Met à jour le statut de connexion
            self.serial_port.close()  # Ferme le port série
            self.serial_port = None
            self.connect_button.config(state=tk.NORMAL)  # Réactive le bouton Connect
            self.disconnect_button.config(state=tk.DISABLED)  # Désactive le bouton Disconnect
            messagebox.showinfo("Déconnexion réussie", "Le port série a été déconnecté.")

    def send_data(self):
        """Envoie des données via le port série."""
        if self.is_connected:
            data = self.data_entry.get()  # Récupère les données saisies
            if data:
                self.serial_port.write(data.encode())  # Envoie les données encodées au port série
        else:
            # Affiche un avertissement si le port série n'est pas connecté
            messagebox.showwarning("Non connecté", "Veuillez d'abord connecter le port série.")

    def read_serial(self):
        """Lit les données reçues du port série."""
        while self.is_connected:
            try:
                if self.serial_port.in_waiting > 0:  # Vérifie si des données sont disponibles
                    data = self.serial_port.readline().decode().strip()  # Lit et décode les données
                    self.output_text.insert(tk.END, data + "\n")  # Affiche les données dans le terminal
                    self.output_text.see(tk.END)  # Défile automatiquement vers le bas
            except Exception:
                break  # Arrête la lecture en cas de problème

    def clear_terminal(self):
        """Efface le contenu du terminal."""
        self.output_text.delete("1.0", tk.END)  # Supprime tout le texte de la zone d'affichage

    def close(self):
        """Ferme proprement l'application."""
        if self.serial_port:  # Ferme le port série s'il est ouvert
            self.serial_port.close()
        self.root.destroy()  # Ferme la fenêtre principale

# Programme principal
if __name__ == "__main__":
    root = tk.Tk()  # Crée la fenêtre principale
    app = SerialApp(root)  # Initialise l'application
    root.protocol("WM_DELETE_WINDOW", app.close)  # Gestion propre de la fermeture de la fenêtre
    root.mainloop()  # Démarre la boucle principale de l'interface

"""
Explications des blocs principaux :

    Imports :
        Import des modules nécessaires pour gérer l'interface graphique et la communication série.
    Classe SerialApp :
        Contient tous les éléments de l'interface graphique et les fonctionnalités liées au port série.
    Widgets :
        Déclaration et disposition des boutons, entrées de texte et autres éléments.
    Méthodes :
        refresh_ports : Met à jour la liste des ports COM.
        connect_serial : Connecte au port série.
        disconnect_serial : Déconnecte du port série.
        send_data : Envoie des données via le port série.
        read_serial : Lit les données reçues.
        clear_terminal : Efface les données affichées.
        close : Gère la fermeture propre de l'application.
        
        Étapes pour compiler un fichier .exe avec PyInstaller
1. Installer PyInstaller

Ouvre un terminal ou la console de commande (CMD) et installe PyInstaller via pip :

pip install pyinstaller

2. Préparer ton script Python

Assure-toi que ton script Python fonctionne correctement avant de le compiler.
3. Compiler le script en .exe

Utilise la commande suivante pour créer l'exécutable. Dans ton terminal, va dans le dossier où se 
trouve ton script Python et tape la commande suivante :

pyinstaller --onefile stmka.py

    --onefile : Cela crée un seul fichier .exe (sinon, PyInstaller crée un dossier avec plusieurs fichiers).
    mon_script.py : Remplace ce nom par le nom de ton fichier Python.

4. Options supplémentaires

Tu peux ajouter des options supplémentaires selon tes besoins :

    --windowed ou --noconsole : Empêche l'ouverture d'une fenêtre de terminal lors de l'exécution 
    (utile pour les applications GUI, comme avec Tkinter).

    Exemple :

pyinstaller --onefile --windowed stmka.py

--icon=icone.ico : Si tu souhaites ajouter une icône à ton exécutable, utilise cette option pour 
spécifier le chemin de l'icône.

Exemple :

    pyinstaller --onefile --windowed --icon=mon_icone.ico stmka.py

5. Localisation de l'exécutable

Après l'exécution de la commande, tu trouveras ton fichier .exe dans le dossier 
dist/ créé par PyInstaller dans ton répertoire de travail.
6. Tester le fichier .exe

Il est important de tester le fichier .exe sur un autre ordinateur pour vérifier s'il 
fonctionne correctement sans Python installé.
Dépannage

Si ton programme utilise des bibliothèques externes (comme serial, tkinter, etc.), PyInstaller 
les inclura automatiquement, mais si des problèmes surviennent, tu peux consulter le fichier stmka.spec 
généré par PyInstaller pour personnaliser davantage le processus de compilation.
"""