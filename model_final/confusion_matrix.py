import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns
import csv

# === Charger la matrice de confusion ===
cm = np.load("confusion_matrix.npy")

# === Charger les noms de classes (optionnel) ===
classes = []
n_images = []
try:
    with open("per_class_accuracy.csv", newline='', encoding='utf-8') as f:
        reader = csv.DictReader(f)
        for row in reader:
            classes.append(row["class"])
            n_images.append(int(row["n_images"]))
except FileNotFoundError:
    classes = [str(i) for i in range(cm.shape[0])]
    n_images = [cm[i].sum() for i in range(cm.shape[0])]
    print("⚠️ 'per_class_accuracy.csv' introuvable, utilisation des indices et totaux de cm")

# === Sélectionner les 30 classes les plus fréquentes ===
top_n = 30
idxs = np.argsort(n_images)[::-1][:top_n]
cm_reduced = cm[np.ix_(idxs, idxs)]
classes_reduced = [classes[i] for i in idxs]

print(f"🎯 Affichage des {top_n} classes les plus fréquentes")

# === Fonction de tracé ===
def plot_confusion_matrix(cm, classes, title, filename, normalize=False):
    if normalize:
        cm = cm.astype('float') / cm.sum(axis=1, keepdims=True)
        cm = np.nan_to_num(cm)

    plt.figure(figsize=(12, 10))
    sns.heatmap(cm, 
                cmap="viridis", 
                xticklabels=classes, 
                yticklabels=classes, 
                cbar=True, 
                square=True,
                fmt=".2f" if normalize else "d")

    plt.xlabel("Prédictions", fontsize=12)
    plt.ylabel("Vérités terrain", fontsize=12)
    plt.title(title, fontsize=14, pad=15)
    plt.xticks(rotation=90)
    plt.yticks(rotation=0)
    plt.tight_layout()
    plt.savefig(filename, dpi=300)
    plt.close()
    print(f"✅ Image enregistrée : {filename}")

# === Enregistrer les deux versions ===
plot_confusion_matrix(cm_reduced, classes_reduced,
                      f"Matrice de confusion - {top_n} classes (brute)",
                      f"confusion_matrix_top{top_n}_raw.png",
                      normalize=False)

plot_confusion_matrix(cm_reduced, classes_reduced,
                      f"Matrice de confusion - {top_n} classes (normalisée)",
                      f"confusion_matrix_top{top_n}_normalized.png",
                      normalize=True)
