#!/bin/bash
# Автоустановка Krea 2 для образа runpod/comfyui (быстрая версия)
# Запускается при каждом старте пода, ДО запуска ComfyUI.
# Всё, что уже скачано, повторно не качается.

C=/workspace/runpod-slim/ComfyUI
M=$C/models
export PIP_CONSTRAINT=/opt/comfyui-runtime-constraints.txt  # не ломаем torch из образа
export HF_XET_HIGH_PERFORMANCE=1                             # максимальная скорость скачивания

echo "=== [krea2] старт настройки ==="

# ---------- 1. ComfyUI ----------
if [ ! -d "$C" ]; then
  echo "[krea2] копирую ComfyUI в /workspace"
  mkdir -p /workspace/runpod-slim
  cp -r /opt/comfyui-baked "$C"
fi

# ---------- 2. Быстрый загрузчик Hugging Face ----------
python3.12 -m pip install -q -U "huggingface_hub[hf_xet]"

# ---------- 3. Модели: все сразу, параллельно, в фоне ----------
(
  # Krea 2 + text encoder + LoRA retroanime — из одного репозитория, одной командой
  hf download Comfy-Org/Krea-2 \
    diffusion_models/krea2_turbo_fp8_scaled.safetensors \
    text_encoders/qwen3vl_4b_fp8_scaled.safetensors \
    loras/krea2_retroanime.safetensors \
    --local-dir "$M"
  echo "[krea2] Krea 2 скачана"
) &
(
  if [ ! -f "$M/vae/qwen_image_vae.safetensors" ]; then
    hf download Comfy-Org/Qwen-Image_ComfyUI split_files/vae/qwen_image_vae.safetensors --local-dir /tmp/qvae
    mkdir -p "$M/vae"
    mv /tmp/qvae/split_files/vae/qwen_image_vae.safetensors "$M/vae/"
  fi
  echo "[krea2] VAE скачан"
) &

# ---------- 4. Ноды (пока модели качаются) ----------
install_node() {
  dir="$C/custom_nodes/$(basename "$1")"
  if [ ! -d "$dir" ]; then
    echo "[krea2] ставлю ноду $(basename "$1")"
    git clone --depth 1 "$1" "$dir"
  fi
  if [ -f "$dir/requirements.txt" ]; then
    python3.12 -m pip install -q -r "$dir/requirements.txt"
  fi
}

install_node https://github.com/rgthree/rgthree-comfy
install_node https://github.com/city96/ComfyUI-GGUF
install_node https://github.com/r-vage/ComfyUI-RvTools_v2
install_node https://github.com/nova452/ComfyUI-ConditioningKrea2Rebalance
install_node https://github.com/numz/ComfyUI-SeedVR2_VideoUpscaler

echo "=== [krea2] ноды готовы, запускаю ComfyUI ==="
