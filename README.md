# RecoPlant

Application mobile de **reconnaissance de plantes** et de **détection de maladies**, développée dans le cadre d’un PFE. L’app Flutter fonctionne **hors ligne** (modèles embarqués) et peut basculer sur une **API cloud** lorsqu’une connexion est disponible. Un système de **points**, de **favoris** et de **boutique** (plantation d’arbres) s’appuie sur **Firebase**.

## Fonctionnalités

| Module | Description |
|--------|-------------|
| **Identification** | Photo ou galerie → classification d’espèces (EfficientNet, PyTorch Lite) |
| **Maladies** | Détection sur feuilles (TFLite `plant_disease_fp32.tflite`) |
| **Compte** | Authentification e-mail / mot de passe (Firebase Auth) |
| **Gamification** | Points, jeu « devine la plante », catalogue boutique |
| **Cloud** | Inférence distante si le réseau est disponible (fallback local) |

## Structure du dépôt

```
RecoPlant/
├── recoplant/          # Application Flutter (code principal)
│   ├── lib/            # Pages, widgets, services Firebase
│   └── assets/models/  # Modèles mobile (.pt, .tflite) et labels
├── dataset/            # Scripts de nettoyage / équilibrage PlantNet
├── model_test/         # Découpage train/test, essais d’entraînement
├── model_final/        # Évaluation, matrices de confusion, graphiques
├── deaseaseModel/      # Scripts liés au modèle maladies
├── conversion.py       # Export checkpoint PyTorch → TorchScript (mobile)
└── data/               # Jeux de données locaux (non versionnés, voir .gitignore)
```

Le dossier `recoplant/tes_app/` est un projet Flutter secondaire (tests / brouillon) ; l’application livrée est **`recoplant/`**.

## Prérequis

### Application mobile

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (SDK Dart ^3.9, voir `recoplant/pubspec.yaml`)
- Android Studio / Xcode selon la cible
- Compte [Firebase](https://firebase.google.com/) (Auth, Firestore, Storage, App Check)

### Pipeline machine learning (optionnel)

- Python 3.10+
- PyTorch, torchvision, scikit-learn, matplotlib
- GPU recommandée pour l’entraînement EfficientNet

## Installation — application Flutter

```bash
cd recoplant
flutter pub get
```

### Firebase

1. Créer un projet Firebase et activer **Authentication** (e-mail), **Cloud Firestore**, **Storage** et **App Check** si utilisé.
2. Ajouter une application Android (et iOS le cas échéant).
3. Placer `google-services.json` dans `recoplant/android/app/` (et `GoogleService-Info.plist` dans `recoplant/ios/Runner/` pour iOS).
4. Générer les options Flutter si besoin :  
   `dart pub global activate flutterfire_cli` puis `flutterfire configure` depuis `recoplant/`.

Sans configuration Firebase, l’app démarre mais l’authentification et la synchronisation cloud ne fonctionneront pas.

### Lancement

```bash
cd recoplant
flutter run
```

Build release Android :

```bash
flutter build apk --release
```

## Modèles embarqués

| Fichier | Rôle |
|---------|------|
| `assets/models/model_mobile.pt` | Classification d’espèces (PyTorch Lite) |
| `assets/models/labels.json` | Libellés espèces |
| `assets/models/plant_disease_fp32.tflite` | Maladies des plantes |
| `assets/models/labels.txt` | Libellés maladies |

Les checkpoints d’entraînement (`*.pth` à la racine) ne sont **pas** versionnés. Pour régénérer le modèle mobile après entraînement, adapter les chemins dans `conversion.py` puis copier le `.pt` produit vers `recoplant/assets/models/`.

## Pipeline ML (Python)

Les scripts supposent un dossier `data/` local (PlantNet, FLAVIA, PlantVillage, etc.) — voir les constantes dans `dataset/` et `model_final/`.

Exemples :

```bash
# Préparation / statistiques dataset (chemins à adapter dans les scripts)
python dataset/filter_dataset.py
python dataset/balanced_dataset.py

# Évaluation du modèle final
python model_final/evalute_model.py

# Export TorchScript pour mobile
python conversion.py
```

Installez les dépendances dans un environnement virtuel (PyTorch, torchvision, scikit-learn, matplotlib, pillow, etc.) ; il n’y a pas encore de `requirements.txt` à la racine.

## Inférence cloud

Les pages d’identification et de maladies envoient les images à des API HTTP lorsque la connectivité est détectée ; sinon, l’inférence locale est utilisée. Les URLs sont définies dans le code (`home_page.dart`, `disease_page.dart`). Pour un déploiement personnel, remplacez-les par vos propres endpoints.

## Licence

Projet académique (PFE). Précisez ici la licence ou les conditions de réutilisation si nécessaire.
