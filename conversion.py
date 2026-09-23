import torch
import torch.nn.functional as F
from torchvision import models
import json

checkpoint_path = "best_model_gpu.pth"
labels_path = "labels.json"
num_classes = 480

with open(labels_path, "r", encoding="utf-8") as f:
    label_map = list(json.load(f).values())

model = models.efficientnet_b3(pretrained=False)
model.classifier[1] = torch.nn.Linear(model.classifier[1].in_features, num_classes)

state_dict = torch.load(checkpoint_path, map_location="cpu")
model.load_state_dict(state_dict)
model.eval()

class WrappedModel(torch.nn.Module):
    def __init__(self, model):
        super().__init__()
        self.model = model

    def forward(self, x):
        logits = self.model(x)
        probs = F.softmax(logits, dim=1)
        max_probs, max_indices = torch.max(probs, dim=1)
        # Transformer en un Tensor 1D de taille 2
        out = torch.zeros(2)
        out[0] = max_probs[0]
        out[1] = max_indices[0].float()
        return out  # <-- retourne un seul Tensor

wrapped_model = WrappedModel(model)

example_input = torch.randn(1, 3, 224, 224)
traced_model = torch.jit.trace(wrapped_model, example_input)
traced_model.save("model_mobile.pt")

print("✅ Modèle TorchScript compatible Flutter : renvoie Tensor([proba_max, index_classe])")

