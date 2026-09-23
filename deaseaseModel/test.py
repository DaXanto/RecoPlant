import sys
import numpy as np
from PIL import Image
import tensorflow as tf
import os

MODEL_PATH = "C:/Users/robin/cours/pfe/RecoPlant/deaseaseModel/plant_disease_fp32.tflite"   # ajuste si nécessaire
LABELS_PATH = "C:/Users/robin/cours/pfe/RecoPlant/deaseaseModel/labels.txt"  # optionnel, ligne par label
INPUT_SIZE = 128  # change si ton modèle attend autre chose

def load_labels(path):
    if not os.path.exists(path):
        return None
    with open(path, "r", encoding="utf-8") as f:
        lines = [l.strip() for l in f.readlines() if l.strip()]
    return lines

def preprocess_image_pil(image_path, input_size, input_type):
    """
    Load image, convert to RGB, resize to input_size x input_size,
    and return numpy array of shape (1, H, W, C) with correct dtype and scaling.
    """
    img = Image.open(image_path).convert("RGB")
    img = img.resize((input_size, input_size), Image.BILINEAR)
    arr = np.asarray(img)

    if input_type == np.float32:
        # normalize to [0,1]
        arr = arr.astype(np.float32) / 255.0
    elif input_type == np.uint8:
        arr = arr.astype(np.uint8)
    else:
        # fallback: cast to float32
        arr = arr.astype(np.float32) / 255.0

    # add batch dim NHWC
    return np.expand_dims(arr, axis=0)

def softmax(x):
    x = np.array(x, dtype=np.float64)
    x = x - np.max(x)
    exps = np.exp(x)
    return exps / np.sum(exps)

def run_inference(model_path, image_path=None, labels=None, input_size=128):
    # Load interpreter
    interpreter = tf.lite.Interpreter(model_path=model_path)
    interpreter.allocate_tensors()

    input_details = interpreter.get_input_details()
    output_details = interpreter.get_output_details()

    print("Interpreter loaded.")
    print("Input details:", input_details)
    print("Output details:", output_details)

    # Determine expected input dtype and shape
    in_index = input_details[0]['index']
    in_shape = input_details[0]['shape']  # e.g. [1,128,128,3]
    in_dtype = input_details[0]['dtype']
    print(f"Model expects input shape {in_shape} dtype {in_dtype}")

    # Build input array
    if image_path:
        input_data = preprocess_image_pil(image_path, input_size, np.dtype(in_dtype).type)
    else:
        # random input
        if in_dtype == np.float32:
            input_data = np.random.rand(*in_shape).astype(np.float32)
        else:
            # uint8 or others
            input_data = (np.random.rand(*in_shape) * 255).astype(in_dtype)

    # Ensure correct shape (some interpreters want exact batch dim)
    if list(input_data.shape) != list(in_shape):
        # try to reshape if batch dimension differs
        try:
            input_data = input_data.reshape(in_shape)
        except Exception as e:
            print("Could not reshape input to model shape:", e)
            return

    interpreter.set_tensor(in_index, input_data)
    interpreter.invoke()

    out_index = output_details[0]['index']
    output_data = interpreter.get_tensor(out_index)  # shape e.g. [1,38]
    print("Raw output shape:", output_data.shape)

    # Flatten and compute softmax (if needed)
    logits = np.squeeze(output_data)
    # If values already sum to 1, they might be probs; softmax won't harm
    probs = softmax(logits)

    # Show top5
    topk = 5
    topk_idx = probs.argsort()[-topk:][::-1]
    print("\nTop predictions:")
    for i in topk_idx:
        label = (labels[i] if labels and i < len(labels) else f"Class {i}")
        print(f" - {label}: {probs[i]*100:.3f}%")

    return probs

if __name__ == "__main__":
    img_path = "C:/Users/robin/cours/pfe/RecoPlant/deaseaseModel/1000007032.webp"
    if not os.path.exists(MODEL_PATH):
        print("ERROR: model file not found:", MODEL_PATH)
        sys.exit(1)

    labels = load_labels(LABELS_PATH)
    if labels:
        print(f"Loaded {len(labels)} labels from {LABELS_PATH}")

    print("Running inference...")
    probs = run_inference(MODEL_PATH, img_path, labels, INPUT_SIZE)
