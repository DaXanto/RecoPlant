import os
import shutil
import csv
from tqdm import tqdm

# ============================
# PARAMÈTRES À MODIFIER
# ============================
DATASET_DIR = "data/plantnet_300K"          # dossier racine du dataset
OUTPUT_DIR = "data/PlantNet_clean"     # dossier de sortie nettoyé
MIN_IMAGES = 30                   # nombre minimal d'images par classe
REPORT_CSV = "data/dataset_cleaning_report.csv"

# ============================
# FONCTIONS
# ============================

def count_images(folder_path):
    """Compte les images dans un dossier."""
    if not os.path.exists(folder_path):
        return 0
    return len([f for f in os.listdir(folder_path) if f.lower().endswith(('.jpg', '.png', '.jpeg'))])

def copy_folder(src, dest):
    """Copie un dossier (classe) vers la sortie."""
    if not os.path.exists(dest):
        shutil.copytree(src, dest)

def clean_dataset():
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    report = []
    classes_to_keep = []

    print(f"📂 Analyse du dataset : {DATASET_DIR}")

    # Étape 1 — Analyser le TRAIN
    train_dir = os.path.join(DATASET_DIR, "images_train")
    print("\n🔍 Étape 1 : Filtrage du dossier TRAIN")
    for class_name in tqdm(sorted(os.listdir(train_dir))):
        class_path = os.path.join(train_dir, class_name)
        if not os.path.isdir(class_path):
            continue

        nb_train = count_images(class_path)
        nb_val = count_images(os.path.join(DATASET_DIR, "images_val", class_name))
        nb_test = count_images(os.path.join(DATASET_DIR, "images_test", class_name))

        if nb_train >= MIN_IMAGES:
            classes_to_keep.append(class_name)
            dest_path = os.path.join(OUTPUT_DIR, "images_train", class_name)
            copy_folder(class_path, dest_path)
            report.append([class_name, nb_train, nb_val, nb_test, "✅ Kept"])
        else:
            report.append([class_name, nb_train, nb_val, nb_test, "❌ Removed"])

    # Étape 2 — Nettoyer val et test
    print("\n🧹 Étape 2 : Nettoyage de val et test pour cohérence")
    for split in ["images_val", "images_test"]:
        split_dir = os.path.join(DATASET_DIR, split)
        out_split = os.path.join(OUTPUT_DIR, split)
        os.makedirs(out_split, exist_ok=True)

        for class_name in tqdm(sorted(os.listdir(split_dir))):
            src_class = os.path.join(split_dir, class_name)
            if not os.path.isdir(src_class):
                continue

            if class_name in classes_to_keep:
                copy_folder(src_class, os.path.join(out_split, class_name))
            else:
                pass  # on ignore cette classe

    # Étape 3 — Sauvegarde du rapport CSV
    print("\n📊 Étape 3 : Génération du rapport CSV")
    with open(REPORT_CSV, "w", newline='', encoding='utf-8') as f:
        writer = csv.writer(f)
        writer.writerow(["Classe", "Train Images", "Val Images", "Test Images", "Status"])
        writer.writerows(report)

    print(f"\n✅ Nettoyage terminé !")
    print(f"👉 Dataset nettoyé disponible ici : {OUTPUT_DIR}")
    print(f"📄 Rapport CSV : {REPORT_CSV}")
    print(f"📈 Nombre de classes conservées : {len(classes_to_keep)}")

# ============================
# LANCEMENT
# ============================

if __name__ == "__main__":
    clean_dataset()
