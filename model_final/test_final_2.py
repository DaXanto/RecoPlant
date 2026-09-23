import torch
from torch import nn, optim
from torchvision import datasets, transforms, models
from torch.utils.data import DataLoader
from tqdm import tqdm
import os


def main():
    # ======================================================
    # ⚙️ CONFIGURATION
    # ======================================================
    DATA_DIR = r"c:/Users/robin/cours/pfe/RecoPlant/data/PlantNet_balanced"
    BATCH_SIZE = 32
    NUM_EPOCHS = 15
    LEARNING_RATE = 1e-4
    NUM_WORKERS = 4
    MODEL_PATH = "best_model_gpu.pth"

    # Détection GPU
    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    print(f"✅ Entraînement sur : {device}")
    if device.type == "cuda":
        print(f"GPU détecté : {torch.cuda.get_device_name(0)}")
        print(f"VRAM disponible : {round(torch.cuda.get_device_properties(0).total_memory / 1024**3, 1)} Go")

    # ======================================================
    # 📦 DATASET + TRANSFORMATIONS
    # ======================================================
    train_transform = transforms.Compose([
        transforms.RandomResizedCrop(224),
        transforms.RandomHorizontalFlip(),
        transforms.ColorJitter(brightness=0.2, contrast=0.2, saturation=0.2),
        transforms.ToTensor(),
        transforms.Normalize([0.485, 0.456, 0.406],
                             [0.229, 0.224, 0.225])
    ])

    val_transform = transforms.Compose([
        transforms.Resize(256),
        transforms.CenterCrop(224),
        transforms.ToTensor(),
        transforms.Normalize([0.485, 0.456, 0.406],
                             [0.229, 0.224, 0.225])
    ])

    train_dataset = datasets.ImageFolder(os.path.join(DATA_DIR, "images_train"), transform=train_transform)
    val_dataset = datasets.ImageFolder(os.path.join(DATA_DIR, "images_val"), transform=val_transform)
    test_dataset = datasets.ImageFolder(os.path.join(DATA_DIR, "images_test"), transform=val_transform)

    train_loader = DataLoader(train_dataset, batch_size=BATCH_SIZE, shuffle=True, num_workers=NUM_WORKERS, pin_memory=True)
    val_loader = DataLoader(val_dataset, batch_size=BATCH_SIZE, shuffle=False, num_workers=NUM_WORKERS, pin_memory=True)

    print(f"\n📊 Classes : {len(train_dataset.classes)}")
    print(f"🖼️ Train : {len(train_dataset)} images | Val : {len(val_dataset)} | Test : {len(test_dataset)}")

    # ======================================================
    # 🧠 MODÈLE
    # ======================================================
    model = models.efficientnet_b3(weights=models.EfficientNet_B3_Weights.IMAGENET1K_V1)
    num_features = model.classifier[1].in_features
    model.classifier[1] = nn.Linear(num_features, len(train_dataset.classes))
    model = model.to(device)

    criterion = nn.CrossEntropyLoss()
    optimizer = optim.Adam(model.parameters(), lr=LEARNING_RATE)

    best_val_acc = 0.0
    start_epoch = 0

    # ======================================================
    # 🔄 CHARGEMENT SI MODÈLE EXISTE
    # ======================================================
    if os.path.exists(MODEL_PATH):
        print(f"\n🔁 Modèle existant détecté : {MODEL_PATH}")
        checkpoint = torch.load(MODEL_PATH, map_location=device)
        model.load_state_dict(checkpoint)
        print("✅ Poids chargés avec succès ! (reprise d'entraînement)")
        # ⚠️ On ne connaît pas forcément l'état de l’optimiseur ici, on le recrée proprement.
        # Si tu veux aussi sauvegarder optimizer.state_dict(), ajoute-le à la sauvegarde.
    else:
        print("\n🚀 Aucun modèle sauvegardé trouvé — entraînement depuis zéro.")

    # ======================================================
    # 🚀 ENTRAÎNEMENT
    # ======================================================
    for epoch in range(start_epoch, NUM_EPOCHS):
        print(f"\n🔥 Epoch {epoch+1}/{NUM_EPOCHS}")

        model.train()
        running_loss, correct, total = 0.0, 0, 0

        for inputs, labels in tqdm(train_loader, desc="Entraînement"):
            inputs, labels = inputs.to(device, non_blocking=True), labels.to(device, non_blocking=True)

            optimizer.zero_grad()
            outputs = model(inputs)
            loss = criterion(outputs, labels)
            loss.backward()
            optimizer.step()

            running_loss += loss.item()
            _, preds = torch.max(outputs, 1)
            correct += torch.sum(preds == labels).item()
            total += labels.size(0)

        train_acc = correct / total
        train_loss = running_loss / len(train_loader)

        # Validation
        model.eval()
        val_correct, val_total = 0, 0
        with torch.no_grad():
            for inputs, labels in val_loader:
                inputs, labels = inputs.to(device, non_blocking=True), labels.to(device, non_blocking=True)
                outputs = model(inputs)
                _, preds = torch.max(outputs, 1)
                val_correct += torch.sum(preds == labels).item()
                val_total += labels.size(0)

        val_acc = val_correct / val_total

        print(f"📉 Loss: {train_loss:.4f} | ✅ Train acc: {train_acc:.3f} | 🧪 Val acc: {val_acc:.3f}")

        # Sauvegarde du meilleur modèle
        if val_acc > best_val_acc:
            best_val_acc = val_acc
            torch.save(model.state_dict(), MODEL_PATH)
            print("💾 Nouveau meilleur modèle sauvegardé !")

    print("\n🏁 Entraînement terminé !")
    print(f"⭐ Meilleure accuracy validation : {best_val_acc:.3f}")


if __name__ == "__main__":
    main()
