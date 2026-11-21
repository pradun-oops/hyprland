#!/usr/bin/env python3
import argparse
import gc
import hashlib
import json
import os
import subprocess
import numpy as np
from PIL import Image
import onnxruntime as ort

HOME = os.path.expanduser("~")
MODEL_DIR = os.path.join(HOME, ".local/share/quickshell/models")
CACHE_DIR = os.path.join(HOME, ".cache/quickshell/depth_masks")
DEPTH_MODEL = os.path.join(MODEL_DIR, "depth_anything_v2_small.onnx")
SUBJECT_MODEL = os.path.join(MODEL_DIR, "birefnet_lite.onnx")

IMAGENET_MEAN = np.array([0.485, 0.456, 0.406], dtype=np.float32)
IMAGENET_STD = np.array([0.229, 0.224, 0.225], dtype=np.float32)


def get_active_wallpaper(target_output=""):
    for bin_name in ("awww", "swww"):
        try:
            out = subprocess.check_output([bin_name, "query"], stderr=subprocess.DEVNULL, text=True)
            fallback_wp = ""
            for raw_line in out.splitlines():
                line = raw_line.lstrip(": ").strip()
                if "image:" not in line:
                    continue
                out_name = line.split(":", 1)[0].strip()
                wp_path = line.split("image:", 1)[1].strip()
                if os.path.isfile(wp_path):
                    if target_output and out_name == target_output:
                        return wp_path
                    if not fallback_wp:
                        fallback_wp = wp_path
            if fallback_wp:
                return fallback_wp
        except Exception:
            pass
    for cache_file in (
        os.path.join(HOME, ".cache/qs_wallpaper_path"),
        os.path.join(HOME, ".cache/quickshell_last_wallpaper.txt"),
    ):
        try:
            if os.path.isfile(cache_file):
                with open(cache_file, "r", encoding="utf-8") as cf:
                    wp_path = cf.read().strip()
                if wp_path and os.path.isfile(wp_path):
                    return wp_path
        except Exception:
            pass
    return ""


def preprocess_imagenet(img_rgb, target_w, target_h):
    resized = img_rgb.resize((target_w, target_h), Image.Resampling.BILINEAR)
    arr = np.asarray(resized, dtype=np.float32) / 255.0
    arr -= IMAGENET_MEAN
    arr /= IMAGENET_STD
    arr = np.transpose(arr, (2, 0, 1))[None, ...]
    return np.ascontiguousarray(arr, dtype=np.float32)


def make_session(model_path):
    opts = ort.SessionOptions()
    opts.intra_op_num_threads = 4
    opts.inter_op_num_threads = 1
    opts.enable_cpu_mem_arena = False
    opts.enable_mem_pattern = False
    opts.graph_optimization_level = ort.GraphOptimizationLevel.ORT_ENABLE_ALL
    return ort.InferenceSession(model_path, sess_options=opts, providers=["CPUExecutionProvider"])


def run_depth_model(img_rgb, orig_w, orig_h):
    short_side = 336
    scale = short_side / min(orig_w, orig_h)
    tw = max(14, int(round((orig_w * scale) / 14.0)) * 14)
    th = max(14, int(round((orig_h * scale) / 14.0)) * 14)

    sess = make_session(DEPTH_MODEL)
    in_name = sess.get_inputs()[0].name
    inp = preprocess_imagenet(img_rgb, tw, th)
    pred = sess.run(None, {in_name: inp})[0].squeeze()
    del inp, sess
    gc.collect()

    d_min, d_max = float(pred.min()), float(pred.max())
    norm = (pred - d_min) / (d_max - d_min + 1e-8)
    depth_u8 = (np.clip(norm, 0.0, 1.0) * 255.0).astype(np.uint8)
    return Image.fromarray(depth_u8, mode="L").resize((orig_w, orig_h), Image.Resampling.BILINEAR)


def run_subject_model(img_rgb, orig_w, orig_h):
    sess = make_session(SUBJECT_MODEL)
    in_meta = sess.get_inputs()[0]
    in_name = in_meta.name
    shape = in_meta.shape
    th = shape[2] if (len(shape) >= 4 and isinstance(shape[2], int) and shape[2] > 0) else 512
    tw = shape[3] if (len(shape) >= 4 and isinstance(shape[3], int) and shape[3] > 0) else 512

    inp = preprocess_imagenet(img_rgb, tw, th)
    logits = sess.run(None, {in_name: inp})[0].squeeze()
    del inp, sess
    gc.collect()

    probs = 1.0 / (1.0 + np.exp(-np.clip(logits, -30.0, 30.0)))
    alpha_u8 = (np.clip(probs, 0.0, 1.0) * 255.0).astype(np.uint8)
    return Image.fromarray(alpha_u8, mode="L").resize((orig_w, orig_h), Image.Resampling.BILINEAR)


def evaluate_subject_quality(subj_img):
    arr = np.asarray(subj_img, dtype=np.float32) / 255.0
    fg_ratio = float((arr > 0.5).mean())
    uncertain_ratio = float(((arr > 0.15) & (arr < 0.85)).mean())
    is_good = (0.04 <= fg_ratio <= 0.80) and (uncertain_ratio < 0.16)
    return is_good, fg_ratio


def compose_cutout(rgb_img, depth_img, subj_img, mode, threshold, out_path):
    w, h = rgb_img.size
    if w > 1920:
        new_h = int(round(h * (1920.0 / w)))
        rgb_img = rgb_img.resize((1920, new_h), Image.Resampling.LANCZOS)
        depth_img = depth_img.resize((1920, new_h), Image.Resampling.BILINEAR)
        subj_img = subj_img.resize((1920, new_h), Image.Resampling.BILINEAR)

    if mode == "subject":
        alpha_img = subj_img
    else:
        d = np.asarray(depth_img, dtype=np.float32) / 255.0
        feather = 0.035
        t = np.clip((d - (threshold - feather)) / (2.0 * feather), 0.0, 1.0)
        smooth = t * t * (3.0 - 2.0 * t)
        alpha_img = Image.fromarray((smooth * 255.0).astype(np.uint8), mode="L")

    rgba = rgb_img.convert("RGBA")
    rgba.putalpha(alpha_img)
    tmp_path = out_path + ".tmp.png"
    rgba.save(tmp_path, format="PNG", compress_level=1)
    os.replace(tmp_path, out_path)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--wp", default="")
    parser.add_argument("--output", default="")
    parser.add_argument("--mode", default="auto", choices=["auto", "depth", "subject"])
    parser.add_argument("--threshold", type=float, default=0.48)
    parser.add_argument("--force", action="store_true")
    args = parser.parse_args()

    wp_arg = args.wp.strip()
    wp = wp_arg if (wp_arg and os.path.isfile(wp_arg)) else get_active_wallpaper(args.output)
    if not wp:
        print(json.dumps({"status": "no_wallpaper"}))
        return

    if not os.path.exists(DEPTH_MODEL) or not os.path.exists(SUBJECT_MODEL):
        print(json.dumps({"status": "missing_models", "wp": wp}))
        return

    os.makedirs(CACHE_DIR, exist_ok=True)
    st = os.stat(wp)
    key = hashlib.sha256(f"{wp}:{st.st_mtime}:{st.st_size}".encode()).hexdigest()[:24]
    entry_dir = os.path.join(CACHE_DIR, key)
    os.makedirs(entry_dir, exist_ok=True)

    depth_path = os.path.join(entry_dir, "depth.png")
    subj_path = os.path.join(entry_dir, "subject.png")
    meta_path = os.path.join(entry_dir, "meta.json")
    cutout_path = os.path.join(entry_dir, "cutout.png")

    with Image.open(wp) as raw_im:
        rgb_img = raw_im.convert("RGB")
        orig_w, orig_h = rgb_img.size

        if args.force or not (os.path.exists(depth_path) and os.path.exists(subj_path) and os.path.exists(meta_path)):
            depth_img = run_depth_model(rgb_img, orig_w, orig_h)
            subj_img = run_subject_model(rgb_img, orig_w, orig_h)
            has_subject, fg_ratio = evaluate_subject_quality(subj_img)

            depth_img.save(depth_path, format="PNG")
            subj_img.save(subj_path, format="PNG")
            meta = {"auto_mode": "subject" if has_subject else "depth", "fg_ratio": round(fg_ratio, 4)}
            with open(meta_path, "w") as mf:
                json.dump(meta, mf)
        else:
            depth_img = Image.open(depth_path).convert("L")
            subj_img = Image.open(subj_path).convert("L")
            with open(meta_path) as mf:
                meta = json.load(mf)

        resolved_mode = meta.get("auto_mode", "depth") if args.mode == "auto" else args.mode
        threshold = max(0.05, min(0.95, float(args.threshold)))
        compose_cutout(rgb_img, depth_img, subj_img, resolved_mode, threshold, cutout_path)

    print(json.dumps({
        "status": "ready",
        "wp": wp,
        "cutout": cutout_path,
        "resolved_mode": resolved_mode,
        "auto_mode": meta.get("auto_mode", "depth"),
        "threshold": threshold
    }))


if __name__ == "__main__":
    main()
