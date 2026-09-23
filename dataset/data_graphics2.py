import os
import pandas as pd
import matplotlib.pyplot as plt

# Chemins
DATASET_BEFORE = r"c:/Users/robin/cours/pfe/RecoPlant/data/PlantNet_clean"
DATASET_AFTER  = r"c:/Users/robin/cours/pfe/RecoPlant/data/PlantNet_balanced"
SPLIT = "images_train"
TOP_N = 40  # pour afficher les 40 classes les moins fournies

def get_class_counts(dataset_path, split):
    split_dir = os.path.join(dataset_path, split)
    class_counts = {}
    for class_name in os.listdir(split_dir):
        class_dir = os.path.join(split_dir, class_name)
        if os.path.isdir(class_dir):
            num_images = len([f for f in os.listdir(class_dir) if f.lower().endswith((".jpg",".png"))])
            class_counts[class_name] = num_images
    df = pd.DataFrame(list(class_counts.items()), columns=["class","count"])
    return df

# Récupération des données
df_before = get_class_counts(DATASET_BEFORE, SPLIT).sort_values("count", ascending=True)[:TOP_N]
df_after  = get_class_counts(DATASET_AFTER, SPLIT).sort_values("count", ascending=True)[:TOP_N]

# Graphique côte à côte
fig, axes = plt.subplots(1,2, figsize=(16,6))
axes[0].barh(df_before["class"], df_before["count"], color="tomato")
axes[0].set_title(f"{SPLIT} - Avant augmentation")
axes[0].set_xlabel("Nombre d'images")

axes[1].barh(df_after["class"], df_after["count"], color="seagreen")
axes[1].set_title(f"{SPLIT} - Après augmentation")
axes[1].set_xlabel("Nombre d'images")

plt.tight_layout()
plt.savefig("dataset_comparison_augmented.png")
plt.show()
