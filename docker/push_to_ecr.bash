#!/bin/bash

set -exuo pipefail

aws ecr get-login-password --region eu-central-1 | docker login --username AWS --password-stdin 799634405166.dkr.ecr.eu-central-1.amazonaws.com
docker build -t coder/ui-template .
docker tag coder/ui-template:latest 799634405166.dkr.ecr.eu-central-1.amazonaws.com/coder/ui-template:latest
docker push 799634405166.dkr.ecr.eu-central-1.amazonaws.com/coder/ui-template:latest
