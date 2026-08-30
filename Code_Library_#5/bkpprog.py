# Importe Tkinter pour créer l'interface graphique.
import tkinter as tk
# Importe les boîtes de dialogue et les widgets Tkinter avancés.
from tkinter import messagebox, ttk
# Importe les fonctions nécessaires à la copie des fichiers.
import shutil
# Importe les fonctions de gestion des fichiers et des chemins.
import os
# Importe le module utilisé pour envoyer les rapports par SMTP.
import smtplib
# Permet de construire un message e-mail MIME.
from email.mime.multipart import MIMEMultipart
# Permet d'ajouter du texte au message e-mail.
from email.mime.text import MIMEText
# Importe la bibliothèque utilisée pour planifier les sauvegardes.
import schedule
# Importe les fonctions de temporisation.
import time
# Permet d'exécuter certaines tâches sans bloquer l'interface.
import threading
# Importe la gestion de la date et de l'heure.
from datetime import datetime

# =============================================================================
# CONFIGURATION
# =============================================================================
# Exemple de configuration uniquement.
# Remplacez les chemins, adresses e-mail et paramètres SMTP ci-dessous
# par vos propres valeurs avant d'utiliser le programme.
# Ne publiez jamais de véritables mots de passe ou données sensibles
# dans un dépôt GitHub public.
# =============================================================================

NAS_BASE_PATH = r'\\NAS123'  # Path to the NAS
DEST_BASE_PATH = r'E:\NAS123'  # Path to the destination on disk E

# Configuration e-mail - VALEURS D'EXEMPLE
EMAIL_ADDRESS = "server@votre.ca"  # Your email address
EMAIL_PASSWORD = "password"  # Your email password
SMTP_SERVER = "smtp.your.com"  # SMTP server address
SMTP_PORT = 587  # SMTP server port
TO_EMAIL = ["toyou@votre.ca"]  # Recipient's email address

# Paths that require credentials
PATHS_WITH_CREDENTIALS = ["Management A1", "Marketing A2", "orCADs A3", "QBdata A4"]

# Définit la fonction d'envoi du rapport par e-mail.
def send_email(subject, body):
    # Crée un nouveau message e-mail.
    msg = MIMEMultipart()
    msg['From'] = EMAIL_ADDRESS
    msg['To'] = ", ".join(TO_EMAIL)
    msg['Subject'] = subject
    msg.attach(MIMEText(body, 'plain'))

    try:
        # Ouvre une connexion avec le serveur SMTP.
        with smtplib.SMTP(SMTP_SERVER, SMTP_PORT) as server:
            # Active le chiffrement TLS de la connexion SMTP.
            server.starttls()
            # Authentifie le compte auprès du serveur SMTP.
            server.login(EMAIL_ADDRESS, EMAIL_PASSWORD)
            # Envoie le message préparé.
            server.send_message(msg)
        print("Email sent successfully.")
    except Exception as e:
        print(f"Failed to send email: {e}")

# Définit la fonction de copie récursive des fichiers.
def copy_files(src, dst):
    """
    Copie récursivement les fichiers de src vers dst.

    Retourne :
        total_size : taille totale copiée en octets
        errors     : liste des erreurs rencontrées
    """
    # Initialise le compteur de données copiées.
    total_size = 0
    # Crée une liste destinée à enregistrer les erreurs.
    errors = []

    try:
        # Vérifie si le dossier de destination existe.
        if not os.path.exists(dst):
            # Crée le dossier de destination si nécessaire.
            os.makedirs(dst)

        # Parcourt tous les éléments du dossier source.
        for item in os.listdir(src):
            # Construit le chemin complet de l'élément source.
            src_path = os.path.join(src, item)
            # Construit le chemin correspondant dans la destination.
            dst_path = os.path.join(dst, item)

            try:
                # Vérifie si l'élément source est un dossier.
                if os.path.isdir(src_path):
                    # Copie récursivement le contenu du sous-dossier.
                    sub_size, sub_errors = copy_files(src_path, dst_path)
                    # Ajoute la taille copiée du sous-dossier au total.
                    total_size += sub_size
                    # Ajoute les erreurs du sous-dossier à la liste générale.
                    errors.extend(sub_errors)
                else:
                    # Copie le fichier en conservant ses métadonnées principales.
                    shutil.copy2(src_path, dst_path)
                    # Ajoute la taille du fichier au compteur total.
                    total_size += os.path.getsize(src_path)

            except Exception as e:
                errors.append(
                    f"Erreur avec '{src_path}' -> '{dst_path}' : {e}"
                )

    except Exception as e:
        errors.append(
            f"Impossible d'accéder au dossier '{src}' : {e}"
        )

    # Retourne la taille totale copiée et les erreurs rencontrées.
    return total_size, errors

# Définit l'action exécutée lors d'une sauvegarde immédiate.
def on_button_click(name):
    """Exécute immédiatement la sauvegarde du dossier sélectionné."""

    # Construit le chemin du dossier à sauvegarder sur le NAS.
    src_path = os.path.join(NAS_BASE_PATH, name)
    # Construit le chemin du dossier de destination.
    dest_path = os.path.join(DEST_BASE_PATH, name)

    # Enregistre l'heure de début de la sauvegarde.
    start_time = datetime.now()
    # Lance la copie et récupère son résultat.
    total_size, errors = copy_files(src_path, dest_path)
    # Enregistre l'heure de fin de la sauvegarde.
    end_time = datetime.now()

    # Convertit la taille copiée d'octets en mégaoctets.
    size_mb = total_size / (1024 * 1024)

    result_lines = [
        f"Sauvegarde : {name}",
        f"Source : {src_path}",
        f"Destination : {dest_path}",
        f"Heure de début : {start_time}",
        f"Heure de fin : {end_time}",
        f"Taille copiée : {size_mb:.2f} MB"
    ]

    if errors:
        result_lines.append("")
        result_lines.append(f"Nombre d'erreurs : {len(errors)}")
        result_lines.extend(errors)
        subject = f"Erreur de sauvegarde - {name}"
    else:
        result_lines.append("")
        result_lines.append("Sauvegarde terminée sans erreur.")
        subject = f"Sauvegarde réussie - {name}"

    # Assemble les différentes lignes du rapport.
    result = "\n".join(result_lines)

    # Affiche le rapport dans la console.
    print(result)
    # Envoie automatiquement le rapport par e-mail.
    send_email(subject, result)

# Définit l'exécution successive des sauvegardes sélectionnées.
def run_selected_backups(selected_tasks):
    """
    Exécute toutes les sauvegardes sélectionnées.
    Une nouvelle liste est utilisée à chaque exécution planifiée.
    """
    # Parcourt la liste des dossiers sélectionnés.
    for name in list(selected_tasks):
        # Lance la sauvegarde du dossier courant.
        on_button_click(name)


# Définit la planification hebdomadaire des sauvegardes.
def schedule_tasks(selected_tasks, weekday, time_str):
    """
    Programme une sauvegarde hebdomadaire.

    La liste des tâches est recréée à chaque déclenchement,
    afin que la sauvegarde fonctionne chaque semaine et pas seulement
    lors du premier passage.
    """

    # Mémorise la sélection actuelle des tâches.
    tasks_snapshot = list(selected_tasks)

    # Définit l'action appelée automatiquement à l'heure programmée.
    def scheduled_job():
        threading.Thread(
            target=run_selected_backups,
            args=(tasks_snapshot,),
            daemon=True
        ).start()

    # Vérifie si la sauvegarde doit être exécutée le lundi.
    if weekday == "Lundi":
        schedule.every().monday.at(time_str).do(scheduled_job)
    # Vérifie si la sauvegarde doit être exécutée le mardi.
    elif weekday == "Mardi":
        schedule.every().tuesday.at(time_str).do(scheduled_job)
    # Vérifie si la sauvegarde doit être exécutée le mercredi.
    elif weekday == "Mercredi":
        schedule.every().wednesday.at(time_str).do(scheduled_job)
    # Vérifie si la sauvegarde doit être exécutée le jeudi.
    elif weekday == "Jeudi":
        schedule.every().thursday.at(time_str).do(scheduled_job)
    # Vérifie si la sauvegarde doit être exécutée le vendredi.
    elif weekday == "Vendredi":
        schedule.every().friday.at(time_str).do(scheduled_job)
    # Vérifie si la sauvegarde doit être exécutée le samedi.
    elif weekday == "Samedi":
        schedule.every().saturday.at(time_str).do(scheduled_job)
    # Vérifie si la sauvegarde doit être exécutée le dimanche.
    elif weekday == "Dimanche":
        schedule.every().sunday.at(time_str).do(scheduled_job)
    else:
        raise ValueError(f"Jour de semaine non valide : {weekday}")


# Définit la boucle qui surveille les tâches planifiées.
def run_scheduler():
    """Boucle permanente du planificateur."""
    # Maintient le planificateur actif en permanence.
    while True:
        # Exécute les tâches dont l'heure programmée est arrivée.
        schedule.run_pending()
        # Attend une seconde avant la prochaine vérification.
        time.sleep(1)

# Définit les boutons de sauvegarde immédiate.
def create_buttons(root, names):
    button_positions = [
        (50, 50), (200, 50), (350, 50), (50, 200),
        (50, 100), (200, 100), (350, 100), (200, 200),
        (50, 150), (200, 150), (350, 150), (350, 200)
    ]
    button_width = max(len(name) for name in names) + 2  # Set a uniform button width
    # Crée un bouton pour chaque dossier disponible.
    for i, name in enumerate(names):
        button = tk.Button(
            root,
            text=name,
            width=button_width,
            command=lambda name=name: threading.Thread(
                target=on_button_click,
                args=(name,),
                daemon=True
            ).start()
        )
        button.place(x=button_positions[i][0], y=button_positions[i][1])
    button_label = tk.Label(root, text="Pour copier immédiatement, vous pouvez cliquer sur le bouton suivant\n pour démarrer le processus de copie :", fg="blue")
    button_label.place(x=30, y=5)

# Ajoute une nouvelle programmation au planificateur.
def start_scheduler(selected_tasks, weekday, time_str):
    # Enregistre les tâches et leur horaire.
    schedule_tasks(selected_tasks, weekday, time_str)


# Définit la fonction principale de l'application.
def main():
    names = ["B1", "B2", "B3", "A1", "A2", "A3",
             "A4", "B4", "B5", "B6", "Archive", "TransferS"]

    preselected_names = ["B1", "B2", "B3", "A1", "A2", "A3",
             "A4", "B4", "B5", "B6"]

    # Crée la fenêtre principale Tkinter.
    root = tk.Tk()
    # Définit le titre de la fenêtre.
    root.title("Utilitaire de sauvegarde NAS")
    # Définit les dimensions initiales de la fenêtre.
    root.geometry("800x600")

    create_buttons(root, names)

    # Crée la liste des tâches sélectionnées par l'utilisateur.
    selected_tasks = []

    # Met à jour la liste lorsque les cases sont modifiées.
    def on_checkbox_select():
        # Efface l'ancienne sélection avant de la reconstruire.
        selected_tasks.clear()
        for i, var in enumerate(check_vars):
            # Vérifie si la case correspondante est cochée.
            if var.get():
                selected_tasks.append(names[i])

    # Crée une variable booléenne pour chaque case à cocher.
    check_vars = [tk.BooleanVar() for _ in names]
    checkbox_positions = [
        (50, 400), (50, 440), (50, 480), (50, 520),
        (175, 400), (175, 440), (175, 480), (175, 520),
        (300, 400), (300, 440), (300, 480), (300, 520)
    ]

    for i, name in enumerate(names):
        check_vars[i].set(name in preselected_names)  # Pre-select checkboxes
        checkbox = tk.Checkbutton(root, text=name, variable=check_vars[i], command=on_checkbox_select)
        checkbox.place(x=checkbox_positions[i][0], y=checkbox_positions[i][1])

    on_checkbox_select()  # Initialize the selected tasks list with preselected items

    # Widgets for scheduling
    planificator_label = tk.Label(root, text="Pour la programmation des heures spéciales - utilisez le planificateur\n "
                                             "automatique, mais par défaut la sauvegarde permanente est\n "
                                             "programmée pour le vendredi 19h00.", fg="blue")
    planificator_label.place(x=30, y=250)

    weekday_label = tk.Label(root, text="Sélectionnez le jour de la semaine :")
    weekday_label.place(x=30, y=300)

    # Sélectionne vendredi comme jour par défaut.
    weekday_var = tk.StringVar(value="Vendredi")
    weekday_combobox = ttk.Combobox(root, textvariable=weekday_var, values=["Lundi", "Mardi", "Mercredi", "Jeudi", "Vendredi", "Samedi", "Dimanche"])
    weekday_combobox.place(x=250, y=300)

    time_label = tk.Label(root, text="Sélectionnez l'heure (HH:MM) :")
    time_label.place(x=50, y=330)

    # Définit 19:00 comme heure de sauvegarde par défaut.
    time_var = tk.StringVar(value="19:00")
    time_entry = tk.Entry(root, textvariable=time_var)
    time_entry.place(x=250, y=330)

    # Définit l'action du bouton de démarrage du planificateur.
    def on_start_button_click():
        try:
            # Lit le jour choisi par l'utilisateur.
            selected_weekday = weekday_var.get()
            # Lit l'heure choisie par l'utilisateur.
            selected_time = time_var.get()
            # Ajoute la programmation choisie au planificateur.
            start_scheduler(selected_tasks, selected_weekday, selected_time)
            messagebox.showinfo("Planificateur", f"Tâches prévues pour {selected_weekday} à {selected_time}")
        except Exception as e:
            messagebox.showerror("Erreur du planificateur", str(e))

    start_button = tk.Button(root, text="Démarrer le planificateur", command=on_start_button_click, width=20)
    start_button.place(x=160, y=360)

    # Planification automatique par défaut : vendredi à 19:00.
    # Programme automatiquement la sauvegarde par défaut du vendredi.
    start_scheduler(preselected_names, "Vendredi", "19:00")

    # Démarre une seule fois le moteur du planificateur.
    scheduler_thread = threading.Thread(
        target=run_scheduler,
        daemon=True
    )
    # Démarre le planificateur dans un thread séparé.
    scheduler_thread.start()

    # Logo facultatif.
    # Si le fichier n'existe pas, le programme continue normalement.
    # Définit le chemin facultatif du logo.
    image_path = "C:/image.png"

    try:
        # Charge le logo si le fichier est disponible.
        image = tk.PhotoImage(file=image_path)
        # Crée le widget destiné à afficher le logo.
        image_label = tk.Label(root, image=image)
        # Conserve une référence à l'image pour éviter sa suppression.
        image_label.image = image
        # Positionne le logo dans la fenêtre.
        image_label.place(x=450, y=10)
    except Exception:
        pass

    # Create a label for the red text
    red_text_label = tk.Label( root, text="<<Très important pour utiliser ce programme : >>\n\r "
                                         "1. Activation de NAS et connexion au réseau local.\n\r"
                                         "2. Connexion du disque local via USB au votre serveur  :\n\r"
                                         "     * Ce disque doit être configuré en tant que disque E:\n\r "
                                         "3. Le serveur  doit être connecté au même réseau que NAS.\n\r"
                                         "4. Après chaque sauvegarde, envoyez un courriel à programme\n"
                                         " avec les informations suivantes :\n\r "
                                         "     * Heure de début de la sauvegarde.\n "                                        
                                         "     * Heure de fin de la sauvegarde. \n "
                                         "     * Taille des données copiées.\n"
                                         "     * Indication de la présence ou non d'erreurs.\n"
                                         "     * En cas d'erreurs, les détails des fichiers \n    concernés et des erreurs rencontrées.\n\n"
                                         "AHDS ahds@engineer.com", fg="red" )
    red_text_label.place(x=400, y=250)  # Change coordinates as needed

    # Lance la boucle principale de l'interface graphique.
    root.mainloop()

# Vérifie que le fichier est exécuté directement.
if __name__ == "__main__":
    # Démarre l'application.
    main()
