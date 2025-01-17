#!/bin/sh

# Only the default WSL user should run this script
if ! (id -Gn | grep -c "adm.*sudo\|sudo.*adm" >/dev/null); then
  return
fi

setup_display() {

  if [ -n "${XRDP_SESSION}" ]; then
    return
  fi

  # WSL2 Environment variable meaning:
  # WSL2=0: WSL1
  # WSL2=1: WSL2 (Type 1)
  # WSL2=2: WSL2 (Type 2)
  # WSL2=3: WSL2 (Type 3)
  if [ -n "${WSL_INTEROP}" ]; then

    if [ -n "${DISPLAY}" ]; then
      # check if the type is changed
      sudo /usr/local/bin/wsl_change_checker 3 "WSL2" "${DISPLAY}"
      sudo /usr/local/bin/wsl2_ip_checker "$(echo "$DISPLAY" | cut -d : -f 1)"
      #Export an enviroment variable for helping other processes
      export WSL2=3

      return
    fi

    # enable external x display for WSL 2
    ipconfig_exec=$(wslpath "C:\\Windows\\System32\\ipconfig.exe")
    if (command -v ipconfig.exe >/dev/null 2>&1); then
      ipconfig_exec=$(command -v ipconfig.exe)
    fi

    wsl2_d_tmp="$(eval "$ipconfig_exec 2> /dev/null" | grep -n -m 1 "Default Gateway.*: [0-9a-z]" | cut -d : -f 1)"

    if [ -n "${wsl2_d_tmp}" ]; then

      wsl2_d_tmp="$(eval "$ipconfig_exec" | sed "$((wsl2_d_tmp - 4))"','"$((wsl2_d_tmp + 0))"'!d' | grep IPv4 | cut -d : -f 2 | sed -e "s|\s||g" -e "s|\r||g")"
      export DISPLAY=${wsl2_d_tmp}:0

      # check if the type is changed
      sudo /usr/local/bin/wsl_change_checker 2 "WSL2" "${wsl2_d_tmp}:0\.0"
      sudo /usr/local/bin/wsl2_ip_checker "$wsl2_d_tmp"
      #Export an enviroment variable for helping other processes
      export WSL2=2

    else
      wsl2_d_tmp="$(grep </etc/resolv.conf nameserver | awk '{print $2}')"
      export DISPLAY=${wsl2_d_tmp}:0

      # check if we have wsl.exe in path
      sudo /usr/local/bin/wsl_change_checker 1 "WSL2" "$DISPLAY"
      sudo /usr/local/bin/wsl2_ip_checker "$wsl2_d_tmp"
      #Export an enviroment variable for helping other processes
      export WSL2=1
    fi

    unset ipconfig_exec
    unset wsl2_d_tmp

  else

    # enable external x display for WSL 1
    export DISPLAY=localhost:0

    # check if we have wsl.exe in path
    sudo /usr/local/bin/wsl_change_checker 0 "WSL1" "localhost:0"

    # Export an enviroment variable for helping other processes
    unset WSL2

  fi
}

setup_display

# enable external libgl if mesa is not installed
if (command -v glxinfo >/dev/null 2>&1); then
  unset LIBGL_ALWAYS_INDIRECT
  sudo /usr/local/bin/libgl-change-checker 0
else
  export LIBGL_ALWAYS_INDIRECT=1
  sudo /usr/local/bin/libgl-change-checker 1
fi

# speed up some GUI apps like gedit
export NO_AT_BRIDGE=1

# Fix 'clear' scrolling issues
alias clear='clear -x'

# Custom aliases
alias ll='ls -al'
alias winget='powershell.exe winget'
alias wsl='wsl.exe'

# Check if we have Windows Path
if (command -v cmd.exe >/dev/null); then

  # Execute on user's shell first-run
  if [ ! -f "${HOME}/.firstrun" ]; then
    echo "Welcome to Pengwin. Type 'pengwin-setup' to run the setup tool. You will only see this message on the first run."
    touch "${HOME}/.firstrun"
  fi

  # shellcheck disable=SC1003
  if (! wslpath 'C:\' >/dev/null 2>&1); then
    # shellcheck disable=SC2262
    alias wslpath=legacy_wslupath
  fi

  # Create a symbolic link to the windows home

  # Here have a issue: %HOMEDRIVE% might be using a custom set location
  # moving cmd to where Windows is installed might help: %SYSTEMDRIVE%
  wHomeWinPath=$(cmd-exe /c 'cd %SYSTEMDRIVE%\ && echo %HOMEDRIVE%%HOMEPATH%' 2>/dev/null | tr -d '\r')

  if [ ${#wHomeWinPath} -le 3 ]; then #wHomeWinPath contains something like H:\
    wHomeWinPath=$(cmd-exe /c 'cd %SYSTEMDRIVE%\ && echo %USERPROFILE%' 2>/dev/null | tr -d '\r')
  fi

  # shellcheck disable=SC2155
  export WIN_HOME=$(wslpath -u "${wHomeWinPath}")

  win_home_lnk=${HOME}/winhome
  if [ ! -e "${win_home_lnk}" ]; then
    ln -s -f "${WIN_HOME}" "${win_home_lnk}" >/dev/null 2>&1
  fi

  unset win_home_lnk
fi
