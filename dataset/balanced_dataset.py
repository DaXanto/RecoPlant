import os
import random
from shutil import copy2
from PIL import Image, ImageEnhance

# Chemins
DATASET_DIR = r"c:/Users/robin/cours/pfe/RecoPlant/data/PlantNet_clean"
OUTPUT_DIR = r"c:/Users/robin/cours/pfe/RecoPlant/data/PlantNet_balanced"
TARGET_IMAGES_PER_CLASS = 500

# Crée le dossier de sortie si besoin
os.makedirs(OUTPUT_DIR, exist_ok=True)

# Fonction d'augmentation avancée
def augment_image(img):
    # Flip horizontal et vertical
    if random.random() < 0.5:
        img = img.transpose(Image.FLIP_LEFT_RIGHT)
    if random.random() < 0.5:
        img = img.transpose(Image.FLIP_TOP_BOTTOM)

    # Rotation
    if random.random() < 0.5:
        img = img.rotate(random.choice([90, 180, 270]))

    # Variation de luminosité / contraste / saturation
    if random.random() < 0.5:
        enhancer = ImageEnhance.Brightness(img)
        img = enhancer.enhance(random.uniform(0.8, 1.2))
    if random.random() < 0.5:
        enhancer = ImageEnhance.Contrast(img)
        img = enhancer.enhance(random.uniform(0.8, 1.2))
    if random.random() < 0.5:
        enhancer = ImageEnhance.Color(img)
        img = enhancer.enhance(random.uniform(0.8, 1.2))

    # Crop / zoom aléatoire (90–100%)
    if random.random() < 0.5:
        w, h = img.size
        crop_scale = random.uniform(0.9, 1.0)
        new_w, new_h = int(w*crop_scale), int(h*crop_scale)
        left = random.randint(0, w - new_w)
        top = random.randint(0, h - new_h)
        img = img.crop((left, top, left + new_w, top + new_h))
        img = img.resize((w, h))  # remettre à la taille originale

    return img

# Pour chaque split : train, val, test
for split in ["images_train"]:
    split_dir = os.path.join(DATASET_DIR, split)
    out_split_dir = os.path.join(OUTPUT_DIR, split)
    os.makedirs(out_split_dir, exist_ok=True)

    for class_name in os.listdir(split_dir):
        class_dir = os.path.join(split_dir, class_name)
        if not os.path.isdir(class_dir):
            continue
        out_class_dir = os.path.join(out_split_dir, class_name)
        os.makedirs(out_class_dir, exist_ok=True)

        images = [f for f in os.listdir(class_dir) if f.lower().endswith((".jpg", ".png"))]

        if len(images) >= TARGET_IMAGES_PER_CLASS:
            # Sous-échantillonnage pour ≥500 images
            images_to_copy = random.sample(images, TARGET_IMAGES_PER_CLASS)
            for idx, img_name in enumerate(images_to_copy):
                copy2(os.path.join(class_dir, img_name), os.path.join(out_class_dir, f"{idx}_{img_name}"))
        else:
            # Sur-échantillonnage avec augmentation avancée
            images_to_copy = images.copy()
            idx = 0
            # Copie des images originales
            for img_name in images:
                copy2(os.path.join(class_dir, img_name), os.path.join(out_class_dir, f"{idx}_{img_name}"))
                idx += 1

            # Génération d'images augmentées
            while len(images_to_copy) < TARGET_IMAGES_PER_CLASS:
                img_name = random.choice(images)
                img_path = os.path.join(class_dir, img_name)
                img = Image.open(img_path)
                img = augment_image(img)
                out_path = os.path.join(out_class_dir, f"{idx}_{img_name}")
                img.save(out_path)
                images_to_copy.append(img_name)
                idx += 1

        print(f"[{split}] Classe '{class_name}' -> {len(images_to_copy)} images")
