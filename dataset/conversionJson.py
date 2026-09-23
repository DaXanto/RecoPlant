import json
import pandas as pd
import re

# === 🔹 Fichiers d'entrée ===
json_path = "C:/Users/robin/cours/pfe/RecoPlant/data/PlantNet_balanced/plantnet300K_species_id_2_name.json"  # ton JSON original
csv_path = "C:/Users/robin/cours/pfe/RecoPlant/data/dataset_cleaning_report.csv"                           # ton CSV avec colonnes "Classe" et "Status"
output_path = "labels.json"                        # fichier de sortie

# === 📖 Charger les fichiers ===
with open(json_path, "r", encoding="utf-8") as f:
    id_to_name = json.load(f)

df = pd.read_csv(csv_path)

# === 🧩 Filtrer uniquement les classes "✅ Kept" ===
kept_ids = df[df["Status"].str.contains("✅")]["Classe"].astype(str).tolist()

# === 🧠 Fonction pour nettoyer le nom scientifique ===
def clean_name(name):
    # Garder uniquement les deux premiers mots (genre + espèce)
    words = name.split()
    if len(words) >= 2:
        return f"{words[0]} {words[1]}"
    else:
        return name.strip()

# === 🏷️ Créer le dictionnaire filtré et nettoyé ===
filtered_labels = {}
for cid in kept_ids:
    if cid in id_to_name:
        filtered_labels[cid] = clean_name(id_to_name[cid])

# === 💾 Sauvegarde ===
with open(output_path, "w", encoding="utf-8") as f:
    json.dump(filtered_labels, f, ensure_ascii=False, indent=2)

print(f"✅ Fichier '{output_path}' créé avec {len(filtered_labels)} classes gardées.")
