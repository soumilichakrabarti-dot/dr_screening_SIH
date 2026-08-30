"""
Fine-tuning script skeleton for the DR grading model.

Expects a folder of images + a CSV with columns: image_id, diagnosis (0-4)
— this matches the APTOS 2019 Kaggle dataset format directly.
For IDRiD, adapt the CSV column names below.

Usage:
    python train.py --data_dir ./data/aptos --csv ./data/aptos/train.csv --epochs 15
"""
import argparse
import os

import pandas as pd
import torch
import torch.nn as nn
from PIL import Image
from sklearn.model_selection import train_test_split
from torch.utils.data import Dataset, DataLoader
from torchvision import transforms

from model import load_model, NUM_CLASSES

IMG_SIZE = 224


class DRDataset(Dataset):
    def __init__(self, df, img_dir, transform, img_col="id_code", label_col="diagnosis", ext=".png"):
        self.df = df.reset_index(drop=True)
        self.img_dir = img_dir
        self.transform = transform
        self.img_col = img_col
        self.label_col = label_col
        self.ext = ext

    def __len__(self):
        return len(self.df)

    def __getitem__(self, idx):
        row = self.df.iloc[idx]
        img_path = os.path.join(self.img_dir, f"{row[self.img_col]}{self.ext}")
        img = Image.open(img_path).convert("RGB")
        img = self.transform(img)
        label = int(row[self.label_col])
        return img, label


def get_transforms():
    train_tf = transforms.Compose([
        transforms.Resize((IMG_SIZE, IMG_SIZE)),
        transforms.RandomHorizontalFlip(),
        transforms.RandomRotation(15),
        # mimic low-quality smartphone-fundus captures seen in rural screening
        transforms.ColorJitter(brightness=0.2, contrast=0.2),
        transforms.ToTensor(),
        transforms.Normalize(mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225]),
    ])
    val_tf = transforms.Compose([
        transforms.Resize((IMG_SIZE, IMG_SIZE)),
        transforms.ToTensor(),
        transforms.Normalize(mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225]),
    ])
    return train_tf, val_tf


def train(args):
    device = "cuda" if torch.cuda.is_available() else "cpu"
    df = pd.read_csv(args.csv)
    train_df, val_df = train_test_split(df, test_size=0.15, stratify=df[args.label_col], random_state=42)

    train_tf, val_tf = get_transforms()
    train_ds = DRDataset(train_df, args.data_dir, train_tf, args.img_col, args.label_col, args.ext)
    val_ds = DRDataset(val_df, args.data_dir, val_tf, args.img_col, args.label_col, args.ext)

    train_loader = DataLoader(train_ds, batch_size=args.batch_size, shuffle=True, num_workers=2)
    val_loader = DataLoader(val_ds, batch_size=args.batch_size, shuffle=False, num_workers=2)

    model = load_model(weights_path=None, device=device)
    model.train()

    optimizer = torch.optim.AdamW(model.parameters(), lr=args.lr)
    scheduler = torch.optim.lr_scheduler.CosineAnnealingLR(optimizer, T_max=args.epochs)
    criterion = nn.CrossEntropyLoss()

    best_val_acc = 0.0
    os.makedirs(args.checkpoint_dir, exist_ok=True)

    for epoch in range(args.epochs):
        model.train()
        running_loss = 0.0
        for imgs, labels in train_loader:
            imgs, labels = imgs.to(device), labels.to(device)
            optimizer.zero_grad()
            outputs = model(imgs)
            loss = criterion(outputs, labels)
            loss.backward()
            optimizer.step()
            running_loss += loss.item() * imgs.size(0)
        scheduler.step()
        train_loss = running_loss / len(train_ds)

        # validation
        model.eval()
        correct, total = 0, 0
        with torch.no_grad():
            for imgs, labels in val_loader:
                imgs, labels = imgs.to(device), labels.to(device)
                outputs = model(imgs)
                preds = torch.argmax(outputs, dim=1)
                correct += (preds == labels).sum().item()
                total += labels.size(0)
        val_acc = correct / total
        print(f"Epoch {epoch+1}/{args.epochs} | train_loss={train_loss:.4f} | val_acc={val_acc:.4f}")

        if val_acc > best_val_acc:
            best_val_acc = val_acc
            ckpt_path = os.path.join(args.checkpoint_dir, "dr_effnet_b0.pt")
            torch.save(model.state_dict(), ckpt_path)
            print(f"  -> saved new best checkpoint to {ckpt_path}")

    print(f"Training done. Best val_acc={best_val_acc:.4f}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--data_dir", type=str, required=True, help="Folder containing fundus images")
    parser.add_argument("--csv", type=str, required=True, help="CSV with image_id + label columns")
    parser.add_argument("--img_col", type=str, default="id_code")
    parser.add_argument("--label_col", type=str, default="diagnosis")
    parser.add_argument("--ext", type=str, default=".png")
    parser.add_argument("--epochs", type=int, default=15)
    parser.add_argument("--batch_size", type=int, default=32)
    parser.add_argument("--lr", type=float, default=3e-4)
    parser.add_argument("--checkpoint_dir", type=str, default="./checkpoints")
    args = parser.parse_args()
    train(args)
