import torch
import torch.nn.functional as F
from torchvision import models, transforms
from PIL import Image
import json

# === CONFIGURATION ===
model_path = "best_model_gpu.pth"      # ou "model_mobile.pt"
labels_path = "labels.json"
image_path = "image.png"                # 🔁 remplace par ton image à tester
num_classes = 480

# === CHARGEMENT DES LABELS ===
with open(labels_path, "r", encoding="utf-8") as f:
    labels = list(json.load(f).values())  # ["Sedum rubrotinctum", "Pelargonium graveolens", ...]

# === TRANSFORMATIONS D'IMAGE ===
transform = transforms.Compose([
    transforms.Resize((224, 224)),
    transforms.ToTensor(),
])

# === CHARGER L'IMAGE ===
image = Image.open(image_path).convert("RGB")
input_tensor = transform(image).unsqueeze(0)  # batch de taille 1

# === CHARGER LE MODÈLE ===
model = models.efficientnet_b3(pretrained=False)
model.classifier[1] = torch.nn.Linear(model.classifier[1].in_features, num_classes)

state_dict = torch.load(model_path, map_location="cpu")
model.load_state_dict(state_dict, strict=False)
model.eval()

# === PRÉDICTION ===
with torch.no_grad():
    outputs = model(input_tensor)
    probs = F.softmax(outputs, dim=1)
    conf, pred_idx = torch.max(probs, dim=1)

pred_idx = pred_idx.item()
confidence = conf.item()
pred_label = labels[pred_idx] if pred_idx < len(labels) else "Unknown"

print(f"✅ Prédiction : {pred_label} ({confidence*100:.2f}%)")
