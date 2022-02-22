#!/usr/bin/env bash

set -e
set -u
set -o pipefail
set -x

####################
# Variables
####################
DEBIAN_FRONTEND="noninteractive"
TIMEZONE="${CONTAINER_TIMEZONE:-Europe/London}"
USERNAME="${CONTAINER_USERNAME}"
USER_UID="1000"
USER_GID="1000"

VSCODE_DEVCONTAINERS_VERSION="v0.222.0" # https://github.com/microsoft/vscode-dev-containers/releases

# Binaries
AWSCLI_VERSION="2.4.19" # https://github.com/aws/aws-cli/blob/v2/CHANGELOG.rst
AWSVAULT_VERSION="6.5.0" # https://github.com/99designs/aws-vault/releases
COSIGN_VERSION="1.5.2" # https://github.com/sigstore/cosign/releases
GITHUB_CLI_VERSION="2.5.1" # https://github.com/cli/cli/releases
GCLOUD_VERSION="373.0.0" # https://cloud.google.com/sdk/docs/release-notes
GRYPE_VERSION="0.33.0" # https://github.com/anchore/grype/releases
HELM_VERSION="3.8.0" # https://github.com/helm/helm/releases
KUBECTL_VERSION="1.23.4" # https://storage.googleapis.com/kubernetes-release/release/stable.txt
KUBELINTER_VERSION="0.2.5" # https://github.com/stackrox/kube-linter/releases
KUBESEC_VERSION="2.11.4" # https://github.com/controlplaneio/kubesec/releases
OPA_VERSION="0.37.2" # https://github.com/open-policy-agent/opa/releases
ORAS_VERSION="0.12.0" # https://github.com/oras-project/oras/releases
SNYK_VERSION="1.856.0" # https://github.com/snyk/snyk/releases
SYFT_VERSION="0.38.0" # https://github.com/anchore/syft/releases
TERRAFORM_VERSION="1.1.6" # https://github.com/hashicorp/terraform/releases
TERRAGRUNT_VERSION="0.36.1" # https://github.com/gruntwork-io/terragrunt/releases
TFLINT_VERSION="0.34.1" # https://github.com/terraform-linters/tflint/releases
TFSEC_VERSION="1.4.2" # https://github.com/aquasecurity/tfsec/releases
TRIVY_VERSION="0.23.0" # https://github.com/aquasecurity/trivy/releases

# Pip
ARGCOMPLETE_VERSION="2.0.0" # https://pypi.org/project/argcomplete/#history
ANSIBLE_VERSION="5.3.0" # https://pypi.org/project/ansible/#history
ANSIBLE_LINT_VERSION="5.4.0" # https://pypi.org/project/ansible-lint/#history

####################
# Functions
####################
set_system_arch() {
  if [[ "$( uname -m )" == "x86_64" ]]; then
    export ARCH="$( uname -m )"
    export ALT_ARCH="amd64"
  elif [[ "$( uname -m )" == "aarch64" ]]; then
    export ARCH="$( uname -m )"
    export ALT_ARCH="arm64"
  else
    echo "$( uname -m ) is not supported - Exiting."
    exit 1
  fi
}

configure_timezone() {
  ln -fs /usr/share/zoneinfo/${TIMEZONE} /etc/localtime
}

install_apt_packages() {
  apt update --assume-yes
  apt upgrade --assume-yes
  apt install --assume-yes \
    apt-transport-https \
    bash \
    ca-certificates \
    curl \
    git-crypt \
    gnupg \
    icu-devtools \
    python3 \
    python3-pip \
    sshpass \
    unzip \
    zip
}

install_pip_packages() {
  python3 -m pip install --upgrade pip --no-cache
  python3 -m pip install --no-cache \
    argcomplete=="${ARGCOMPLETE_VERSION}" \
    ansible=="${ANSIBLE_VERSION}" \
    ansible-lint=="${ANSIBLE_LINT_VERSION}"
}

setup_vscode_common() {
  curl https://raw.githubusercontent.com/microsoft/vscode-dev-containers/${VSCODE_DEVCONTAINERS_VERSION}/script-library/common-debian.sh \
    --output /tmp/common-debian.sh
  bash /tmp/common-debian.sh "true" "${USERNAME}" "${USER_UID}" "${USER_GID}" "true" "true" "false"
  chsh --shell /bin/zsh "${USERNAME}"
  rm --force /tmp/common-debian.sh

  mkdir --parents /usr/local/etc/vscode-dev-containers
  mv /root/src/first-run-notice.txt /usr/local/etc/vscode-dev-containers/first-run-notice.txt
}

setup_vscode_docker() {
  groupadd --gid 800 docker
  usermod --append --groups docker ${USERNAME}

  curl https://raw.githubusercontent.com/microsoft/vscode-dev-containers/${VSCODE_DEVCONTAINERS_VERSION}/script-library/docker-in-docker-debian.sh \
    --output /tmp/docker-in-docker-debian.sh
  bash /tmp/docker-in-docker-debian.sh "true" "${USERNAME}" "true" "latest"
  rm --force /tmp/docker-in-docker-debian.sh
}

setup_vscode_ssh() {
  curl https://raw.githubusercontent.com/microsoft/vscode-dev-containers/${VSCODE_DEVCONTAINERS_VERSION}/script-library/sshd-debian.sh \
    --output /tmp/sshd-debian.sh
  bash /tmp/sshd-debian.sh "2222" "${USERNAME}" "false" "skip" "true"
}

install_awscli() {
  curl https://awscli.amazonaws.com/awscli-exe-linux-${ARCH}-${AWSCLI_VERSION}.zip \
    --output awscliv2.zip
  unzip -q awscliv2.zip
  bash aws/install
  rm -rf aws awscliv2.zip
}

install_awsvault() {
  curl --location https://github.com/99designs/aws-vault/releases/download/${AWSVAULT_VERSION}/aws-vault-linux-${ALT_ARCH} \
    --output /usr/local/bin/aws-vault
  chmod +x /usr/local/bin/aws-vault
}

install_cosign() {
  curl --location https://github.com/sigstore/cosign/releases/download/v${COSIGN_VERSION}/cosign-linux-${ALT_ARCH} \
    --output /usr/local/bin/cosign
  chmod +x /usr/local/bin/cosign
}

install_github() {
  curl --location https://github.com/cli/cli/releases/download/v${GITHUB_CLI_VERSION}/gh_${GITHUB_CLI_VERSION}_linux_${ALT_ARCH}.tar.gz \
    --output gh_${GITHUB_CLI_VERSION}_linux_${ALT_ARCH}.tar.gz
  tar -zxvf gh_${GITHUB_CLI_VERSION}_linux_${ALT_ARCH}.tar.gz
  mv gh_${GITHUB_CLI_VERSION}_linux_${ALT_ARCH}/bin/gh /usr/local/bin/gh
  rm -rf gh_${GITHUB_CLI_VERSION}_linux_${ALT_ARCH}*

  gh completion -s zsh > /usr/local/share/zsh/site-functions/_gh
}

install_gcloud() {
  echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | tee -a /etc/apt/sources.list.d/google-cloud-sdk.list
  curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key --keyring /usr/share/keyrings/cloud.google.gpg add -
  apt update --yes
  apt install --yes \
    google-cloud-sdk="${GCLOUD_VERSION}-0" # '-0' is required as per https://cloud.google.com/sdk/docs/install#:~:text=To%20revert%20to,cloud%2Dsdk%3D123.0.0%2D0
}

install_grype() {
  curl --location https://github.com/anchore/grype/releases/download/v${GRYPE_VERSION}/grype_${GRYPE_VERSION}_linux_${ALT_ARCH}.tar.gz \
    --output grype_${GRYPE_VERSION}_linux_${ALT_ARCH}.tar.gz
  tar -zxvf grype_${GRYPE_VERSION}_linux_${ALT_ARCH}.tar.gz
  mv grype /usr/local/bin/grype
  rm grype_${GRYPE_VERSION}_linux_${ALT_ARCH}.tar.gz README.md CHANGELOG.md LICENSE
}

install_helm() {
  curl --location https://get.helm.sh/helm-v${HELM_VERSION}-linux-${ALT_ARCH}.tar.gz \
    --output helm-v${HELM_VERSION}-linux-${ALT_ARCH}.tar.gz
  tar -zxvf helm-v${HELM_VERSION}-linux-${ALT_ARCH}.tar.gz
  mv linux-${ALT_ARCH}/helm /usr/local/bin/helm
  rm -rf linux-${ALT_ARCH} helm-v${HELM_VERSION}-linux-${ALT_ARCH}.tar.gz
}

install_kubectl() {
  curl --location https://dl.k8s.io/release/v${KUBECTL_VERSION}/bin/linux/${ALT_ARCH}/kubectl \
    --output /usr/local/bin/kubectl
  chmod +x /usr/local/bin/kubectl
}

install_kubelinter() {
  curl --location https://github.com/stackrox/kube-linter/releases/download/${KUBELINTER_VERSION}/kube-linter-linux.zip \
    --output kube-linter-linux.zip
  unzip -q kube-linter-linux.zip
  mv kube-linter /usr/local/bin/kube-linter
  rm -f kube-linter-linux.zip
}

install_kubesec() {
  curl --location https://github.com/controlplaneio/kubesec/releases/download/v${KUBESEC_VERSION}/kubesec_linux_${ALT_ARCH}.tar.gz \
    --output kubesec_linux_${ALT_ARCH}.tar.gz
  tar -zxvf kubesec_linux_${ALT_ARCH}.tar.gz
  mv kubesec /usr/local/bin/kubesec
  rm -f kubesec_linux_${ALT_ARCH}.tar.gz README.md CHANGELOG.md LICENSE
}

install_opa() {
  if [[ "${ALT_ARCH}" == "amd64" ]]; then
    OPA_BINARY="opa_linux_amd64"
  elif [[ "${ALT_ARCH}" == "arm64" ]]; then
    OPA_BINARY="opa_linux_arm64_static"
  fi

  curl --location https://github.com/open-policy-agent/opa/releases/download/v${OPA_VERSION}/${OPA_BINARY} \
    --output /usr/local/bin/opa
  chmod +x /usr/local/bin/opa
}

install_oras() {
  curl --location https://github.com/oras-project/oras/releases/download/v0.12.0/oras_${ORAS_VERSION}_linux_${ALT_ARCH}.tar.gz \
    --output oras_${ORAS_VERSION}_linux_${ALT_ARCH}.tar.gz
  tar -zxvf oras_${ORAS_VERSION}_linux_${ALT_ARCH}.tar.gz
  mv oras /usr/local/bin/oras
  rm -f oras_${ORAS_VERSION}_linux_${ALT_ARCH}.tar.gz LICENSE
}

install_snyk() {
  curl --location https://github.com/snyk/snyk/releases/download/v${SNYK_VERSION}/snyk-linux-${ALT_ARCH} \
    --output /usr/local/bin/snyk
  chmod +x /usr/local/bin/snyk
}

install_syft() {
  curl --location https://github.com/anchore/syft/releases/download/v${SYFT_VERSION}/syft_${SYFT_VERSION}_linux_${ALT_ARCH}.tar.gz \
    --output syft_${SYFT_VERSION}_linux_${ALT_ARCH}.tar.gz
  tar -zxvf syft_${SYFT_VERSION}_linux_${ALT_ARCH}.tar.gz
  mv syft /usr/local/bin/syft
  rm syft_${SYFT_VERSION}_linux_${ALT_ARCH}.tar.gz README.md CHANGELOG.md LICENSE
}

install_terraform() {
  curl https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_${ALT_ARCH}.zip \
    --output terraform_${TERRAFORM_VERSION}_linux_${ALT_ARCH}.zip
  unzip -q terraform_${TERRAFORM_VERSION}_linux_${ALT_ARCH}.zip
  mv terraform /usr/local/bin/terraform
  rm -rf terraform_${TERRAFORM_VERSION}_linux_${ALT_ARCH}.zip
}

install_terragrunt() {
  curl --location https://github.com/gruntwork-io/terragrunt/releases/download/v${TERRAGRUNT_VERSION}/terragrunt_linux_${ALT_ARCH} \
    --output /usr/local/bin/terragrunt
  chmod +x /usr/local/bin/terragrunt
}

install_tflint() {
  curl --location https://github.com/terraform-linters/tflint/releases/download/v0.34.1/tflint_linux_${ALT_ARCH}.zip \
    --output tflint_linux_${ALT_ARCH}.zip
  unzip -q tflint_linux_${ALT_ARCH}.zip
  mv tflint /usr/local/bin/tflint
  rm -rf tflint_linux_${ALT_ARCH}.zip
}

install_tfsec() {
  curl --location https://github.com/aquasecurity/tfsec/releases/download/v${TFSEC_VERSION}/tfsec-linux-${ALT_ARCH} \
    --output /usr/local/bin/tfsec
  chmod +x /usr/local/bin/tfsec
}

install_trivy() {
  if [[ "${ALT_ARCH}" == "amd64" ]]; then
    TRIVY_ARCHIVE="trivy_${TRIVY_VERSION}_Linux-64bit.tar.gz"
  elif [[ "${ALT_ARCH}" == "arm64" ]]; then
    TRIVY_ARCHIVE="trivy_${TRIVY_VERSION}_Linux-ARM64.tar.gz"
  fi

  curl --location https://github.com/aquasecurity/trivy/releases/download/v${TRIVY_VERSION}/${TRIVY_ARCHIVE} \
    --output ${TRIVY_ARCHIVE}
  tar -zxvf ${TRIVY_ARCHIVE}
  mv trivy /usr/local/bin/trivy
  rm -rf ${TRIVY_ARCHIVE} README.md LICENSE contrib
}

configure_user_artefacts() {
  mv /root/src/zshrc /home/${USERNAME}/.zshrc
  chown --recursive ${USERNAME}:${USERNAME} /home/${USERNAME}/.zshrc
}

configure_filesystem() {
  mkdir --parents /home/${USERNAME}/workspace
  chown --recursive ${USERNAME}:${USERNAME} /home/${USERNAME}/workspace

  mkdir --parents /home/${USERNAME}/.commandhistory
  chown --recursive ${USERNAME}:${USERNAME} /home/${USERNAME}/.commandhistory

  mkdir --parents /home/${USERNAME}/.docker
  chown --recursive ${USERNAME}:${USERNAME} /home/${USERNAME}/.docker

  mkdir --parents /home/${USERNAME}/.config/gh
  chown --recursive ${USERNAME}:${USERNAME} /home/${USERNAME}/.config/gh

  mkdir --parents /home/${USERNAME}/.aws
  chown --recursive ${USERNAME}:${USERNAME} /home/${USERNAME}/.aws

  mkdir --parents /home/${USERNAME}/.awsvault
  chown --recursive ${USERNAME}:${USERNAME} /home/${USERNAME}/.awsvault

  mkdir --parents /home/${USERNAME}/.kube
  chown --recursive ${USERNAME}:${USERNAME} /home/${USERNAME}/.kube

  # This is not an exported volume, but it needs to be created otherwise VSCode's terminal will throw an error about permissions
  mkdir --parents /home/${USERNAME}/.config/vscode-dev-containers
  chown --recursive ${USERNAME}:${USERNAME} /home/${USERNAME}/.config/vscode-dev-containers

  mkdir --parents /home/${USERNAME}/.config/gcloud
  chown --recursive ${USERNAME}:${USERNAME} /home/${USERNAME}/.config/gcloud

  mkdir --parents /home/${USERNAME}/.config/configstore
  chown --recursive ${USERNAME}:${USERNAME} /home/${USERNAME}/.config/configstore
}

clean_apt_cache() {
  apt clean autoclean --assume-yes
  apt autoremove --assume-yes
  rm --force --recursive /var/lib/{apt,dpkg,cache,log}
}

####################
# Pre
####################
set_system_arch
configure_timezone
install_apt_packages
install_pip_packages

####################
# Main
####################
setup_vscode_common
setup_vscode_docker
setup_vscode_ssh

###

install_awscli
install_awsvault
install_cosign
install_github
install_gcloud
install_grype
install_helm
install_kubectl
install_kubelinter
install_kubesec
install_opa
install_oras
install_snyk
install_syft
install_terraform
install_terragrunt
install_tflint
install_tfsec
install_trivy

####

configure_user_artefacts
configure_filesystem

####################
# Post
####################
clean_apt_cache