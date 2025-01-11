#!/bin/bash

WORKING_DIR=/home/runner

cd $WORKING_DIR

if [[ ! -s ".runner" ]]; then
  rm -rf ".runner"
  ./gitea-actions-runner register \
    --instance "$GITEA_INSTANCE_URL" \
    --token "$GITEA_RUNNER_REGISTRATION_TOKEN" \
    --worker "$GITEA_RUNNER_WORKER" \
    --labels "$RUNNER_LABELS" \
    --no-interactive
fi

unset GITEA_RUNNER_WORKER
unset GITEA_RUNNER_REGISTRATION_TOKEN

./gitea-actions-runner daemon ${GITEA_RUNNER_ONCE+"--once"}

rm -rf ~/.bash_history
history -c
