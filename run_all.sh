#!/bin/bash
# run_all.sh — runs all 4 ablation fractions sequentially, then stops the pod.

set -uo pipefail   # deliberately NOT -e: one bad run shouldn't waste the night

RESULTS=/workspace/results
mkdir -p $RESULTS

COMMON="--dataset cifar10 --bias 0.5 --net resnet --gpu 0 --seed 1 \
        --epochs 1500 --lr 0.01 --batchsize 64 --nworkers 100 \
        --byz_type scale --aggregation mean --ckpt_interval 10 \
        --scaling_factor 1.0 --advanced_backdoor 0"

for N in 10 20 30 40; do
  RUN_DIR=$RESULTS/nbyz_$N
  mkdir -p $RUN_DIR
  CKPT_GLOBAL=$RUN_DIR/global_model_params/
  CKPT_CLIENT=$RUN_DIR/client_update_params/

  echo "============================================"
  echo "=== [$(date)] TRAIN nbyz=$N ==="
  echo "============================================"
  python3 -u train.py $COMMON --nbyz $N --b $N \
      --client_update_path $CKPT_CLIENT \
      --global_model_path $CKPT_GLOBAL \
      2>&1 | tee $RUN_DIR/train.log

  echo "============================================"
  echo "=== [$(date)] TEST  nbyz=$N ==="
  echo "============================================"
  python3 -u test.py $COMMON --nbyz $N --b $N \
      --client_update_path $CKPT_CLIENT \
      --global_model_path $CKPT_GLOBAL \
      2>&1 | tee $RUN_DIR/test.log

  echo "=== [$(date)] DONE nbyz=$N ==="
done

echo "============================================"
echo "ALL DONE at $(date)"
echo "============================================"

# Auto-stop pod. Volume persists; checkpoints survive.
runpodctl stop pod $RUNPOD_POD_ID