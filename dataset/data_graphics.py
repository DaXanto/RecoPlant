import os
import matplotlib.pyplot as plt
import seaborn as sns
from collections import Counter
import pandas as pd

# ============================
# 🔧 PARAMÈTRES À MODIFIER
# ============================
DATASET_BEFORE = r"C:/Users/robin/cours/pfe/RecoPlant/data/plantnet_300K"           # dossier avant nettoyage
DATASET_AFTER = r"C:/Users/robin/cours/pfe/RecoPlant/data/PlantNet_clean"      # dossier après nettoyage
OUTPUT_FIG = "dataset_comparison.png"
TOP_N = 40  # nombre de classes max à afficher sur les graphiques

# ============================
# 📊 ANALYSE DU DATASET
# ============================

def count_images_per_class(base_dir):
    """Compte le nombre d’images par classe pour chaque split (train/val/test)."""
    data = []
    for split in ["images_train", "images_val", "images_test"]:
        split_dir = os.path.join(base_dir, split)
        if not os.path.exists(split_dir):
            continue
        for cls in sorted(os.listdir(split_dir)):
            cls_path = os.path.join(split_dir, cls)
            if not os.path.isdir(cls_path):
                continue
            n_imgs = len([f for f in os.listdir(cls_path)
                          if f.lower().endswith(('.jpg', '.png', '.jpeg'))])
            data.append({"split": split, "class": cls, "count": n_imgs})
    return pd.DataFrame(data)

def summary(df, name):
    """Résumé statistique global du dataset."""
    if df.empty:
        print(f"\n⚠️ Le dataset '{name}' est vide ou mal structuré.")
        return
    print(f"\n=== 📋 RÉSUMÉ GLOBAL DU DATASET : {name} ===")
    total_images = df["count"].sum()
    total_classes = df["class"].nunique()
    print(f"Nombre total d’images : {total_images}")
    print(f"Nombre total de classes : {total_classes}\n")

    for split in ["images_train", "images_val", "images_test"]:
        subset = df[df["split"] == split]
        if not subset.empty:
            print(f"[{split.upper()}] Classes : {subset['class'].nunique()} | Images : {subset['count'].sum()}")

def plot_comparison(df_before, df_after, split="images_train"):
    """Affiche la comparaison avant/après pour un split donné."""
    plt.figure(figsize=(16, 8))
    sns.set(style="whitegrid")

    before = df_before[df_before["split"] == split].sort_values("count", ascending=True)[:TOP_N]
    after = df_after[df_after["split"] == split].sort_values("count", ascending=True)[:TOP_N]

    plt.subplot(1, 2, 1)
    sns.barplot(x="count", y="class", data=before, palette="crest")
    plt.title(f"{split.upper()} - AVANT NETTOYAGE")
    plt.xlabel("Nombre d’images")
    plt.ylabel("Classe")

    plt.subplot(1, 2, 2)
    sns.barplot(x="count", y="class", data=after, palette="rocket")
    plt.title(f"{split.upper()} - APRÈS NETTOYAGE")
    plt.xlabel("Nombre d’images")
    plt.ylabel("Classe")

    plt.suptitle(f"📊 Distribution des {TOP_N} classes les moins fournies ({split.upper()})", fontsize=14)
    plt.tight_layout(rect=[0, 0, 1, 0.96])
    plt.savefig(OUTPUT_FIG)
    plt.show()
    print(f"\n✅ Graphique enregistré sous : {OUTPUT_FIG}")

# ============================
# 🚀 LANCEMENT
# ============================

if __name__ == "__main__":
    df_before = count_images_per_class(DATASET_BEFORE)
    df_after = count_images_per_class(DATASET_AFTER)

    # Résumés
    summary(df_before, "PlantNet (avant nettoyage)")
    summary(df_after, "PlantNet_clean (après nettoyage)")

    print(df_before.head())
    print(df_after.head())

    if not df_before.empty and not df_after.empty:
        plot_comparison(df_before, df_after, split="images_train")

