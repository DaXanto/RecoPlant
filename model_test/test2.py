import torch
import torch.nn as nn
import torch.optim as optim
from torch.utils.data import DataLoader, random_split
from torchvision import datasets, transforms
import timm
from tqdm import tqdm

# ======================
# 1. Paramètres globaux
# ======================
plant_dir = "D:/project/recoplant/data/PlantVillage"   # dossier PlantVillage (sous-dossiers = classes)
batch_size = 32
num_epochs = 3
learning_rate = 1e-4
device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
print(device)
# ======================
# 2. Dataset
# ======================
transform = transforms.Compose([
    transforms.Resize((128,128)),
    transforms.ToTensor(),
    transforms.Normalize([0.485,0.456,0.406],[0.229,0.224,0.225])
])

dataset = datasets.ImageFolder(root=plant_dir, transform=transform)
num_classes = len(dataset.classes)

# Split Train / Val (80% / 20%)
train_size = int(0.8 * len(dataset))
val_size = len(dataset) - train_size
train_dataset, val_dataset = random_split(dataset, [train_size, val_size])

train_loader = DataLoader(train_dataset, batch_size=batch_size, shuffle=True)
val_loader = DataLoader(val_dataset, batch_size=batch_size, shuffle=False)

# ======================
# 3. Liste des modèles à tester
# ======================
models_to_test = ["efficientnet_b3",]

# ======================
# 4. Fonctions train / val
# ======================
def train_one_epoch(model, loader, optimizer, criterion):
    model.train()
    total_loss, correct, total = 0, 0, 0
    loop = tqdm(loader, desc="Train", unit="batch", leave=False)
    for images, labels in loop:
        images, labels = images.to(device), labels.to(device)

        optimizer.zero_grad()
        outputs = model(images)
        loss = criterion(outputs, labels)
        loss.backward()
        optimizer.step()

        total_loss += loss.item()
        _, predicted = outputs.max(1)
        correct += (predicted == labels).sum().item()
        total += labels.size(0)

    return total_loss/len(loader), 100*correct/total

def validate(model, loader, criterion):
    model.eval()
    total_loss, correct1, correct5, total = 0, 0, 0, 0
    with torch.no_grad():
        loop = tqdm(loader, desc="Val", unit="batch", leave=False)
        for images, labels in loop:
            images, labels = images.to(device), labels.to(device)
            outputs = model(images)
            loss = criterion(outputs, labels)

            total_loss += loss.item()
            _, predicted = outputs.max(1)
            correct1 += (predicted == labels).sum().item()

            # Top-5
            top5 = outputs.topk(5, 1, True, True)[1]
            correct5 += sum([labels[i] in top5[i] for i in range(labels.size(0))])

            total += labels.size(0)

    return total_loss/len(loader), 100*correct1/total, 100*correct5/total

# ======================
# 5. Boucle multi-modèles
# ======================
results = {}

for model_name in models_to_test:
    print(f"\n=== Entraînement du modèle : {model_name} ===")

    try:
        # Charger le modèle
        model = timm.create_model(model_name, pretrained=True)
        model.reset_classifier(num_classes)
        model = model.to(device)

        # Optimiseur et loss
        criterion = nn.CrossEntropyLoss()
        optimizer = optim.Adam(model.parameters(), lr=learning_rate)

        # Entraînement sur 3 epochs
        for epoch in range(num_epochs):
            train_loss, train_acc = train_one_epoch(model, train_loader, optimizer, criterion)
            val_loss, val_acc1, val_acc5 = validate(model, val_loader, criterion)

            print(f"[{model_name}] Epoch {epoch+1}/{num_epochs} "
                  f"Train Loss: {train_loss:.4f} Acc: {train_acc:.2f}% | "
                  f"Val Loss: {val_loss:.4f} Top-1: {val_acc1:.2f}% Top-5: {val_acc5:.2f}%")

        # Sauvegarde du modèle
        save_path = f"{model_name}_plantvillage.pth"
        torch.save(model.state_dict(), save_path)
        print(f"✅ Modèle sauvegardé : {save_path}")

        # Résultats finaux
        results[model_name] = (val_acc1, val_acc5)

    except Exception as e:
        print(f"❌ Erreur avec {model_name}: {e}")

# ======================
# 6. Résumé final
# ======================
print("\n=== Résultats finaux sur PlantVillage ===")
for model_name, (top1, top5) in results.items():
    print(f"{model_name:20s} | Top-1: {top1:.2f}% | Top-5: {top5:.2f}%")
