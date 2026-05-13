#!/bin/bash
set -euxo pipefail

curl --fail -H "Authorization: Bearer Oracle" -L0 \
  http://169.254.169.254/opc/v2/instance/metadata/oke_init_script \
  | base64 --decode >/var/run/oke-init.sh

bash /usr/libexec/oci-growfs -y

bash /var/run/oke-init.sh
