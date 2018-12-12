#! /bin/bash
# file: init-master.sh

# Only run as root necessary commands
[ $EUID -eq 0 ] && sudo='' || sudo='sudo'

# Check the dependecies
programs=( minikube kubectl docker kubeadm )
for prog in ${programs[@]}; do
  if ! which $prog &>/dev/null; then
    echo "[ERROR] Missing dependencies: Run env-setup.sh before running again this script."
    exit 1
  fi
done

# Get WiFi IP Address
wlan_net=$(ip r | grep wl | grep /24 | cut -d" " -f1)
wlan_address=$(ip r | grep wl | grep /24 | cut -d" " -f12)

if [[ $wlan_net = '' ]]; then
  echo "[ERROR] Network: WiFi connection required."
  exit 1
fi

# Start K8s
minikube	start	--vm-driver	virtualbox                                                                           || exit 1
$sudo kubeadm	config	images pull                                                                                  || exit 1
$sudo kubeadm	init --pod-network-cidr $wlan_net --apiserver-advertise-address=$wlan_address                       || exit 1
# Configuration files
mkdir -p $HOME/.kube
$sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
$sudo	chown	$(id	-u):$(id	-g)	$HOME/.kube/config
kubectl	apply	--filename "https://cloud.weave.works/k8s/net?k8s-version=$(kubectl version | base64 | tr -d '\n')" || exit 1
