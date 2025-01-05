#!/bin/sh

ACTION=${1}
shift 1

do_install() {
  local config=`uci get pve.@pve[0].config_path 2>/dev/null`
  local IMAGE_NAME=`uci get pve.@pve[0].image_name 2>/dev/null`
  local tz=`uci get pve.@pve[0].time_zone 2>/dev/null`
  local port=`uci get pve.@pve[0].http_port 2>/dev/null`

  if [ -z "$config" ]; then
      echo "config path is empty!"
      exit 1
  fi
  [ -z "$port" ] && port=8006

  echo "start vmease"
  /etc/init.d/vmease start
  sleep 1

  echo "docker pull ${IMAGE_NAME}"
  docker pull ${IMAGE_NAME}
  docker rm -f pve
  mkdir -p "$config"

  local cmd="docker run --restart=unless-stopped -d \
    --privileged \
    --tmpfs /tmp \
    --tmpfs /run/lock \
	  --hostname pve \
    -e "ISTOREOS=1" \
    -v \"$config/vz:/var/lib/vz\" \
    -v \"$config/pve-cluster:/var/lib/pve-cluster\" \
    -v \"/dev/vfio:/dev/vfio\" \
	  --device /dev/kvm:/dev/kvm \
    -p $port:8006 \
    --dns=172.17.0.1 \
    --dns=223.5.5.5 "

  if [ -z "$tz" ]; then
    tz="`uci get system.@system[0].zonename | sed 's/ /_/g'`"
  fi
  [ -z "$tz" ] || cmd="$cmd -e TZ=\"$tz\""

  cmd="$cmd -v /mnt:/mnt"
  mountpoint -q /mnt && cmd="$cmd:rslave"

  cmd="$cmd --name pve \"$IMAGE_NAME\""

  echo "$cmd"
  eval "$cmd"

  echo "Waiting"
  sleep 8
  echo "Done"
}

do_gpu_passthrough() {
  echo "TODO"
  return 0
}

usage() {
  echo "usage: $0 sub-command"
  echo "where sub-command is one of:"
  echo "      install                Install the pve"
  echo "      upgrade                Upgrade the pve"
  echo "      rm/start/stop/restart  Remove/Start/Stop/Restart the pve"
  echo "      status                 pve status"
  echo "      port                   pve port"
}

case ${ACTION} in
  "install")
    do_install
  ;;
  "upgrade")
    do_install
  ;;
  "rm")
    docker rm -f pve
  ;;
  "start")
    /etc/init.d/vmease start
    sleep 1
    docker ${ACTION} pve
  ;;
  "stop")
    docker ${ACTION} pve
  ;;
  "restart")
    /etc/init.d/vmease start
    sleep 1
    docker ${ACTION} pve
  ;;
  "status")
    docker ps --all -f 'name=^/pve$' --format '{{.State}}'
  ;;
  "port")
    docker ps --all -f 'name=^/pve$' --format '{{.Ports}}' | grep -om1 '0.0.0.0:[0-9]*' | sed 's/0.0.0.0://'
  ;;
  "gpu-passthrough")
    do_gpu_passthrough
  ;;
  *)
    usage
    exit 1
  ;;
esac
