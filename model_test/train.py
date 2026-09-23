import os
import shutil
import random

# Paramètres
flavia_dir = "data/flavia_classes"  # dossier contenant les sous-dossiers par classe
output_dir = "data/flavia"          # dossier final contenant train/ et test/
train_ratio = 0.8
random_seed = 42

train_dir = os.path.join(output_dir, "train")
test_dir  = os.path.join(output_dir, "test")
os.makedirs(train_dir, exist_ok=True)
os.makedirs(test_dir, exist_ok=True)

random.seed(random_seed)
classes = [d for d in os.listdir(flavia_dir) if os.path.isdir(os.path.join(flavia_dir, d))]

for cls in classes:
    cls_path = os.path.join(flavia_dir, cls)
    images = [f for f in os.listdir(cls_path) if f.lower().endswith((".jpg", ".png", ".jpeg"))]
    random.shuffle(images)
    n_train = int(len(images) * train_ratio)
    
    train_images = images[:n_train]
    test_images  = images[n_train:]

    os.makedirs(os.path.join(train_dir, cls), exist_ok=True)
    os.makedirs(os.path.join(test_dir, cls), exist_ok=True)

    for img in train_images:
        shutil.copy(os.path.join(cls_path, img), os.path.join(train_dir, cls, img))
    for img in test_images:
        shutil.copy(os.path.join(cls_path, img), os.path.join(test_dir, cls, img))

    print(f"Classe '{cls}' : {len(train_images)} train / {len(test_images)} test")

print("✅ Découpage train/test terminé !")
