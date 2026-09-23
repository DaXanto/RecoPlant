import torch, os, csv
import numpy as np
from torchvision import transforms, datasets, models
from torch.utils.data import DataLoader
from sklearn.metrics import confusion_matrix, classification_report, top_k_accuracy_score
import matplotlib.pyplot as plt


def main():
    DATA_DIR = r"c:/Users/robin/cours/pfe/RecoPlant/data/PlantNet_balanced"
    BATCH_SIZE = 32
    DEVICE = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    MODEL_PATH = "best_model_gpu.pth"

    val_transform = transforms.Compose([
        transforms.Resize(256),
        transforms.CenterCrop(224),
        transforms.ToTensor(),
        transforms.Normalize([0.485,0.456,0.406],[0.229,0.224,0.225])
    ])

    test_dataset = datasets.ImageFolder(os.path.join(DATA_DIR, "images_test"), transform=val_transform)
    test_loader  = DataLoader(test_dataset, batch_size=BATCH_SIZE, shuffle=False, num_workers=4, pin_memory=True)
    classes = test_dataset.classes

    # Charger le modèle
    model = models.efficientnet_b3(weights=models.EfficientNet_B3_Weights.IMAGENET1K_V1)
    model.classifier[1] = torch.nn.Linear(model.classifier[1].in_features, len(classes))
    model.load_state_dict(torch.load(MODEL_PATH, map_location=DEVICE))
    model.to(DEVICE)
    model.eval()

    all_preds, all_probs, all_labels = [], [], []

    with torch.no_grad():
        for inputs, labels in test_loader:
            inputs = inputs.to(DEVICE, non_blocking=True)
            outputs = model(inputs)
            print(outputs)
            probs = torch.softmax(outputs, dim=1).cpu().numpy()
            preds = outputs.argmax(dim=1).cpu().numpy()
            all_probs.append(probs)
            all_preds.extend(preds.tolist())
            all_labels.extend(labels.numpy().tolist())

    all_probs = np.vstack(all_probs)

    # === Accuracy globale sur toutes les images ===
    all_labels_np = np.array(all_labels)
    all_preds_np = np.array(all_preds)
    global_acc = (all_preds_np == all_labels_np).mean()

    # === Top-5 global ===
    top5 = top_k_accuracy_score(all_labels_np, all_probs, k=5)

    print(f"\n🎯 Accuracy globale (Top-1) : {global_acc*100:.2f}% | Top-5 : {top5*100:.2f}%")


   # === Histogramme des prédictions ===
    plt.figure(figsize=(10, 4))
    # conversion bool -> int
    correct_int = (all_preds_np == all_labels_np).astype(int)
    plt.hist(correct_int, bins=[-0.5,0.5,1.5], color='green', alpha=0.7, rwidth=0.8)
    plt.xticks([0,1], ["Incorrect", "Correct"])
    plt.title(f"Distribution des prédictions (Accuracy globale = {global_acc*100:.2f}%)")
    plt.ylabel("Nombre d’images")
    plt.tight_layout()
    plt.savefig("accuracy_global.png", dpi=300)
    plt.close()
    print("📈 Graphique enregistré : accuracy_global.png")



if __name__ == "__main__":
    torch.multiprocessing.freeze_support()  # 🔒 nécessaire sous Windows
    main()

