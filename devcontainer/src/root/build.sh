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
COSIGN_VERSION="1.5.2" # https://github.com/sigstore/cosign/releases
GITHUB_CLI_VERSION="2.5.1" # https://github.com/cli/cli/releases
GRYPE_VERSION="0.33.0" # https://github.com/anchore/grype/releases
HELM_VERSION="3.8.0" # https://github.com/helm/helm/releases
KUBECTL_VERSION="1.23.4" # https://storage.googleapis.com/kubernetes-release/release/stable.txt
KUBELINTER_VERSION="0.2.5" # https://github.com/stackrox/kube-linter/releases
KUBESEC_VERSION="2.11.4" # https://github.com/controlplaneio/kubesec/releases
OPA_VERSION="0.37.2" # https://github.com/open-policy-agent/opa/releases
ORAS_VERSION="0.12.0" # https://github.com/oras-project/oras/releases
SYFT_VERSION="0.38.0" # https://github.com/anchore/syft/releases
TERRAFORM_VERSION="1.1.6" # https://github.com/hashicorp/terraform/releases
TERRAGRUNT_VERSION="0.36.1" # https://github.com/gruntwork-io/terragrunt/releases
TFLINT_VERSION="0.34.1" # https://github.com/terraform-linters/tflint/releases
TFSEC_VERSION="1.4.2" # https://github.com/aquasecurity/tfsec/releases

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
    icu-devtools \
    python3 \
    python3-pip \
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

install_cosign
install_github
install_grype
install_helm
install_kubectl
install_kubelinter
install_kubesec
install_opa
install_oras
install_syft
install_terraform
install_terragrunt
install_tflint
install_tfsec

####

configure_user_artefacts
configure_filesystem

####################
# Post
####################
clean_apt_cache