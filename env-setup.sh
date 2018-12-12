#! /bin/bash
# file: env-setup.sh

# Only run as root necessary commands
[ $EUID -eq 0 ] && sudo='' || sudo='sudo'
[[ $SUDO_USER = '' ]] && user=$USER || user=$SUDO_USER
[[ $(lsb_release -is) = 'elementary' ]] && dist='xenial' || dist=$(lsb_release -cs)

# Install the dependecies
dependecies=( curl virtualbox-qt apt-transport-https software-properties-common ca-certificates kubectl kubeadm )
for dep in ${dependecies[@]};do
  # Kubectl needs prerequisites
  if [ $dep = kubectl ]; then
    if [ ! -f /etc/apt/sources.list.d/kubernetes.list ]; then
      curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | $sudo apt-key add -
      echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | $sudo tee -a /etc/apt/sources.list.d/kubernetes.list
      $sudo apt-get update -y
    fi
  fi
  # Install missing dependencies
  if ! dpkg -l $dep &>/dev/null; then
    $sudo apt-get install -y $dep
  fi
done

# Docker Setup
if ! which docker &>/dev/null; then
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | $sudo apt-key add -
  $sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $dist stable"
  $sudo apt-get update -y
  $sudo apt-get install -y docker-ce=$(apt-cache madison docker-ce | cut -d" " -f4 | grep 18.06.0)
fi

# Get the latest version name
MINIKUBE_VERSION() {
  curl --silent "https://api.github.com/repos/kubernetes/minikube/releases/latest" |
  grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/'
}

# Download and install Minikube
if ! which minikube &>/dev/null; then
  curl -Lo minikube https://storage.googleapis.com/minikube/releases/$(MINIKUBE_VERSION)/minikube-linux-amd64
  chmod +x minikube
  $sudo mv minikube /usr/local/bin/
fi
