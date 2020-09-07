#!/bin/bash
set -x
# Exit on error
set -efu

docker --version

sudo systemctl start docker

sudo docker pull owasp/zap2docker-stable

sudo docker run -t owasp/zap2docker-stable zap-baseline.py -t https://www.example.com
