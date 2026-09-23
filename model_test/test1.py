import torch
import torch.nn as nn
import torch.optim as optim
from torch.utils.data import DataLoader
from torchvision import datasets, transforms
import timm
from tqdm import tqdm
import time

# ======================
# 1. Paramètres
# ======================
data_dir = "data/flavia"   # dossier contenant train/ et test/
batch_size = 16            # dataset très petit → batch petit
num_classes = 32
num_epochs = 3             # fine-tuning rapide
lr = 0.001
device = torch.device("cuda" if torch.cuda.is_available() else "cpu")

# Liste des modèles à tester
models_to_test = [
    "densenet121",
    "mobilenetv3_large_100"
]

# ======================
# 2. Data transforms & loaders
# ======================
train_transform = transforms.Compose([
    transforms.Resize((128,128)),          # résolution plus petite pour test rapide
    transforms.RandomHorizontalFlip(),
    transforms.RandomRotation(15),
    transforms.ToTensor(),
    transforms.Normalize([0.485,0.456,0.406],[0.229,0.224,0.225])
])

test_transform = transforms.Compose([
    transforms.Resize((128,128)),
    transforms.ToTensor(),
    transforms.Normalize([0.485,0.456,0.406],[0.229,0.224,0.225])
])

train_dataset = datasets.ImageFolder(root=f"{data_dir}/train", transform=train_transform)
test_dataset  = datasets.ImageFolder(root=f"{data_dir}/test", transform=test_transform)

train_loader = DataLoader(train_dataset, batch_size=batch_size, shuffle=True)
test_loader  = DataLoader(test_dataset, batch_size=batch_size, shuffle=False)

# ======================
# 3. Fonction pour entraîner et évaluer un modèle
# ======================
def train_and_evaluate(model_name):
    print(f"\n=== Test du modèle : {model_name} ===")
    
    model = timm.create_model(model_name, pretrained=True)
    model.reset_classifier(num_classes)
    model = model.to(device)
    
    criterion = nn.CrossEntropyLoss()
    optimizer = optim.Adam(model.parameters(), lr=lr)
    
    # ----- Entraînement rapide -----
    for epoch in range(num_epochs):
        model.train()
        total_loss, correct, total = 0, 0, 0
        loop = tqdm(train_loader, desc=f"Epoch {epoch+1}/{num_epochs}", unit="batch")
        for images, labels in loop:
            images, labels = images.to(device), labels.to(device)
            optimizer.zero_grad()
            outputs = model(images)
            loss = criterion(outputs, labels)
            loss.backward()
            optimizer.step()
            
            total_loss += loss.item()
            _, predicted = torch.max(outputs, 1)
            correct += (predicted == labels).sum().item()
            total += labels.size(0)
            
            loop.set_postfix(loss=total_loss/len(train_loader), acc=f"{100*correct/total:.2f}%")
    
    # ----- Évaluation -----
    model.eval()
    correct1, correct5, total = 0, 0, 0
    latencies = []

    with torch.no_grad():
        loop = tqdm(test_loader, desc="Evaluation", unit="batch")
        for images, labels in loop:
            images, labels = images.to(device), labels.to(device)
            start = time.time()
            outputs = model(images)
            latencies.append((time.time() - start)/images.size(0))
            
            _, predicted = torch.max(outputs, 1)
            correct1 += (predicted == labels).sum().item()
            
            top5 = outputs.topk(5, 1, True, True)[1]
            correct5 += sum([labels[i] in top5[i] for i in range(labels.size(0))])
            total += labels.size(0)
    
    top1_acc = 100*correct1/total
    top5_acc = 100*correct5/total
    avg_latency = 1000*sum(latencies)/len(latencies)  # en ms
    
    print(f"\nRésultats pour {model_name}:")
    print(f"Top-1 Accuracy: {top1_acc:.2f}%")
    print(f"Top-5 Accuracy: {top5_acc:.2f}%")
    print(f"Latence moyenne par image: {avg_latency:.2f} ms")
    
    # Sauvegarder le modèle
    torch.save(model.state_dict(), f"{model_name}_flavia.pth")
    print(f"Modèle sauvegardé : {model_name}_flavia.pth")
    
    return model_name, top1_acc, top5_acc, avg_latency

# ======================
# 4. Boucle sur tous les modèles
# ======================
results = []
for model_name in models_to_test:
    try:
        res = train_and_evaluate(model_name)
        results.append(res)
    except Exception as e:
        print(f"Erreur avec {model_name}: {e}")

# ======================
# 5. Affichage comparatif
# ======================
print("\n=== Résultats comparatifs ===")
print(f"{'Modèle':25s} | {'Top-1 Acc':>8s} | {'Top-5 Acc':>8s} | {'Latence (ms)':>12s}")
print("-"*60)
for r in results:
    print(f"{r[0]:25s} | {r[1]:8.2f} | {r[2]:8.2f} | {r[3]:12.2f}")
