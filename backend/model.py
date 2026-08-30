"""
DR grading model: EfficientNet-B0 backbone, 5-class head
(0=No DR, 1=Mild, 2=Moderate, 3=Severe, 4=Proliferative DR - ICDR scale)
"""
import torch
import torch.nn as nn
import timm

NUM_CLASSES = 5
CLASS_NAMES = ["No DR", "Mild", "Moderate", "Severe", "Proliferative DR"]

# Simple triage mapping: what should happen next for each grade
TRIAGE = {
    0: "Routine screening in 12 months",
    1: "Routine screening in 6 months",
    2: "Refer to ophthalmologist within 1 month",
    3: "Refer to ophthalmologist urgently (within 1 week)",
    4: "Refer to ophthalmologist immediately",
}


class DRModel(nn.Module):
    def __init__(self, num_classes: int = NUM_CLASSES, pretrained: bool = True):
        super().__init__()
        # efficientnet_b0 is small enough to run on a low-end laptop/edge box
        self.backbone = timm.create_model(
            "efficientnet_b0", pretrained=pretrained, num_classes=num_classes
        )

    def forward(self, x):
        return self.backbone(x)

    def get_target_layer(self):
        """Layer to hook Grad-CAM onto — last conv block of EfficientNet-B0."""
        return self.backbone.conv_head


def load_model(weights_path: str = None, device: str = "cpu") -> DRModel:
    model = DRModel(pretrained=(weights_path is None))
    if weights_path:
        state_dict = torch.load(weights_path, map_location=device)
        # The Colab notebook saves the raw timm model directly, so its keys
        # look like "conv_stem.weight" — but DRModel wraps it as self.backbone,
        # so this model expects "backbone.conv_stem.weight". Add the prefix
        # back on load so the checkpoint matches.
        if not any(k.startswith("backbone.") for k in state_dict.keys()):
            state_dict = {f"backbone.{k}": v for k, v in state_dict.items()}
        model.load_state_dict(state_dict)
    model.to(device)
    model.eval()
    return model


if __name__ == "__main__":
    # sanity check
    m = load_model()
    dummy = torch.randn(1, 3, 224, 224)
    out = m(dummy)
    print("Output shape:", out.shape)  # should be [1, 5]
