#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script prompts for credentials for other scripts to use

# AIX lacks sudo
if [[ $(command -v sudo) ]] && [[ -z "$SUDO_PASSWORD" ]]; then

  echo
  echo "If you enter a sudo password, then it will be used for installation."
  echo "If you don't enter a password, then ensure INSTX_PREFIX is writable."
  echo "To avoid sudo and the password, just press ENTER and they won't be used."
  read -r -s -p "Please enter password for sudo: " SUDO_PASSWORD
  echo

  # I would like to avoid exporting this, but SUDO_PASSWORD is
  # _not_ available to subshells even after source'ing.
  export SUDO_PASSWORD

fi
