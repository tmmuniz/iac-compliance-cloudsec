#!/bin/bash
set -euxo pipefail

dnf update -y
dnf install -y python3 amazon-ssm-agent

systemctl enable amazon-ssm-agent
systemctl start amazon-ssm-agent