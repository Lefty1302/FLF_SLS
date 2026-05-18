#!/bin/bash
# run_all.sh — Obj 3 ablation: 4 training+test runs at nbyz ∈ {10,20,30,40}.
#
# Designed for fire-and-forget overnight execution on a RunPod pod.
# - Survives SSH disconnects (run inside tmux).
# - Each run is logged to its own dir; one bad run does not abort the others.
# - Auto-stops the pod on completion if RUNPOD_API_KEY is set in env.
#
# Usage:
#   export RUNPOD_API_KEY=rpa_YOUR_KEY     # set in shell, NOT in this file
#   tmux new -s flf
#   ./run_all.sh
#   # Ctrl-b d  to detach
#
# Storage: ~15 GB checkpoints per run × 4 runs = ~60 GB on volume.

set -uo pipefail   # deliberately NOT -e: one bad run shouldn't waste the night

RESULTS=/workspace/results
mkdir -p "$RESULTS"

COMMON="--dataset cifar10 --bias 0.5 --net resnet --gpu 0 --seed 1 \
        --epochs 1500 --lr 0.01 --batchsize 64 --nworkers 100 \
        --byz_type scale --aggregation mean --ckpt_interval 10 \
        --scaling_factor 1.0 --advanced_backdoor 0"

for N in 10 20 30 40; do
  RUN_DIR="$RESULTS/nbyz_$N"
  mkdir -p "$RUN_DIR"
  CKPT_GLOBAL="$RUN_DIR/global_model_params/"
  CKPT_CLIENT="$RUN_DIR/client_update_params/"

  echo "============================================"
  echo "=== [$(date)] TRAIN nbyz=$N ==="
  echo "============================================"
  python3 -u train.py $COMMON --nbyz $N --b $N \
      --client_update_path "$CKPT_CLIENT" \
      --global_model_path "$CKPT_GLOBAL" \
      2>&1 | tee "$RUN_DIR/train.log"

  echo "============================================"
  echo "=== [$(date)] TEST  nbyz=$N ==="
  echo "============================================"
  python3 -u test.py $COMMON --nbyz $N --b $N \
      --client_update_path "$CKPT_CLIENT" \
      --global_model_path "$CKPT_GLOBAL" \
      2>&1 | tee "$RUN_DIR/test.log"

  echo "=== [$(date)] DONE nbyz=$N ==="
done

echo "============================================"
echo "ALL DONE at $(date)"
echo "============================================"

# Auto-stop the pod via RunPod REST API. The GraphQL endpoint that runpodctl
# uses is read-only on new RunPod API keys; the REST endpoint accepts writes
# if the key has "api.runpod.ai — Full access" enabled.
if [ -n "${RUNPOD_API_KEY:-}" ] && [ -n "${RUNPOD_POD_ID:-}" ]; then
  echo "Stopping pod $RUNPOD_POD_ID ..."
  curl -s -X POST "https://rest.runpod.io/v1/pods/${RUNPOD_POD_ID}/stop" \
       -H "Authorization: Bearer ${RUNPOD_API_KEY}" \
       -H "Content-Type: application/json"
  echo ""
else
  echo "RUNPOD_API_KEY or RUNPOD_POD_ID not set — pod will not auto-stop."
  echo "Stop it manually in the RunPod UI to halt billing."
fi
