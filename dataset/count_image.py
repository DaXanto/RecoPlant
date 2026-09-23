import os
import shutil
import csv
from tqdm import tqdm

# ============================
# PARAMÈTRES À MODIFIER
# ============================
DATASET_DIR = r"c:/Users/robin/cours/pfe/RecoPlant/data/PlantNet_balanced"         # dossier racine du dataset


def count_images(folder_path):
    """Compte les images dans un dossier."""
    if not os.path.exists(folder_path):
        return 0
    return len([f for f in os.listdir(folder_path) if f.lower().endswith(('.jpg', '.png', '.jpeg'))])


nb_train = 0
nb_test = 0
nb_val = 0
train_dir = os.path.join(DATASET_DIR, "images_train")

for class_name in tqdm(sorted(os.listdir(train_dir))):
        class_path = os.path.join(train_dir, class_name)
        if not os.path.isdir(class_path):
            continue

        nb_train += count_images(class_path)
        nb_val += count_images(os.path.join(DATASET_DIR, "images_val", class_name))
        nb_test += count_images(os.path.join(DATASET_DIR, "images_test", class_name))

print(nb_train,nb_test,nb_val)