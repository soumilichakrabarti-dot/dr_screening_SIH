"""
Explainability layer: Grad-CAM++ heatmap over the predicted DR grade,
plus a plain-language explanation string a health worker can read.
"""
import numpy as np
import cv2
import torch
from pytorch_grad_cam import GradCAMPlusPlus
from pytorch_grad_cam.utils.image import show_cam_on_image
from pytorch_grad_cam.utils.model_targets import ClassifierOutputTarget

from model import CLASS_NAMES


def generate_heatmap(model, input_tensor, rgb_img_float, predicted_class: int):
    """
    model: DRModel
    input_tensor: normalized [1, 3, H, W] tensor (requires_grad not needed, handled internally)
    rgb_img_float: HxWx3 float32 image in [0,1], same size as input, for overlay
    predicted_class: int class index to explain

    Returns: overlay_image (uint8, HxWx3), raw_cam (HxW float array in [0,1])
    """
    target_layers = [model.get_target_layer()]
    cam = GradCAMPlusPlus(model=model, target_layers=target_layers)
    targets = [ClassifierOutputTarget(predicted_class)]

    grayscale_cam = cam(input_tensor=input_tensor, targets=targets)[0]  # HxW
    overlay = show_cam_on_image(rgb_img_float, grayscale_cam, use_rgb=True)
    return overlay, grayscale_cam


def describe_activation_regions(grayscale_cam: np.ndarray, threshold: float = 0.6):
    """
    Very lightweight region description: bins the image into a 3x3 grid
    (macula-ish center, periphery, etc.) and reports which zones the
    model focused on. This is a stand-in for proper lesion-mask overlap
    (do that with IDRiD lesion masks if you have time — much stronger).
    """
    h, w = grayscale_cam.shape
    zones = {
        "central (macular) region": grayscale_cam[h // 3:2 * h // 3, w // 3:2 * w // 3],
        "upper field": grayscale_cam[0:h // 3, :],
        "lower field": grayscale_cam[2 * h // 3:, :],
        "left periphery": grayscale_cam[:, 0:w // 3],
        "right periphery": grayscale_cam[:, 2 * w // 3:],
    }
    hot_zones = [name for name, region in zones.items() if region.mean() > threshold * grayscale_cam.mean() and region.max() > threshold]
    # fall back: just report the single hottest zone if nothing clears the bar
    if not hot_zones:
        hot_zones = [max(zones, key=lambda k: zones[k].mean())]
    return hot_zones


def build_explanation(predicted_class: int, confidence: float, hot_zones: list) -> str:
    label = CLASS_NAMES[predicted_class]
    zones_str = " and ".join(hot_zones[:2])
    if predicted_class == 0:
        return (
            f"No signs of diabetic retinopathy detected (confidence {confidence*100:.0f}%). "
            f"The model did not find lesion-like patterns in the retinal image."
        )
    return (
        f"Prediction: {label} (confidence {confidence*100:.0f}%). "
        f"The model focused mainly on the {zones_str} of the retina, "
        f"consistent with lesion patterns (e.g. hemorrhages, exudates, or microaneurysms) "
        f"typically seen at this stage."
    )
