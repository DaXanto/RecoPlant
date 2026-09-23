import matplotlib.pyplot as plt
import os

# ======================================================
# 🔢 Données collectées pendant l'entraînement
# ======================================================
train_loss = [2.3064, 1.1387, 0.8957, 0.7667, 0.6749, 0.6152, 0.5628, 0.6198, 0.5687, 0.5277, 0.4951, 0.4665, 0.4439, 0.4241, 0.4046]
train_acc = [0.466, 0.672, 0.733, 0.768, 0.794, 0.812, 0.827, 0.812, 0.826, 0.839, 0.848, 0.857, 0.864, 0.870, 0.876]
val_acc   = [0.602, 0.669, 0.667, 0.691, 0.712, 0.708, 0.697, 0.711, 0.720, 0.723, 0.713, 0.715, 0.708, 0.722, 0.719]

epochs = list(range(1, len(train_loss) + 1))

# ======================================================
# 🎨 Création des graphiques
# ======================================================
plt.figure(figsize=(12, 5))

# 🔴 Courbe de la loss
plt.subplot(1, 2, 1)
plt.plot(epochs, train_loss, marker='o', label="Train Loss", color='red')
plt.title("Évolution de la Loss")
plt.xlabel("Époques")
plt.ylabel("Loss")
plt.grid(True, linestyle='--', alpha=0.6)
plt.legend()

# 🔵 Courbes des accuracies
plt.subplot(1, 2, 2)
plt.plot(epochs, train_acc, marker='o', label="Train Accuracy", color='blue')
plt.plot(epochs, val_acc, marker='o', label="Validation Accuracy", color='green')
plt.title("Accuracy : Entraînement vs Validation")
plt.xlabel("Époques")
plt.ylabel("Accuracy")
plt.grid(True, linestyle='--', alpha=0.6)
plt.legend()

plt.tight_layout()

# ======================================================
# 💾 Sauvegarde du graphique
# ======================================================
output_path = os.path.join(os.getcwd(), "courbes_entraînement.png")
plt.savefig(output_path, dpi=300, bbox_inches='tight')
plt.show()

print(f"✅ Image sauvegardée : {output_path}")
