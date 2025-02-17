#!/bin/bash

# EMBA - EMBEDDED LINUX ANALYZER
#
# Copyright 2020-2022 Siemens Energy AG
#
# EMBA comes with ABSOLUTELY NO WARRANTY. This is free software, and you are
# welcome to redistribute it under the terms of the GNU General Public License.
# See LICENSE file for usage of this software.
#
# EMBA is licensed under GPLv3
#
# Author(s): Michael Messner

# Description:  Installs unblob and dependencies for EMBA

IP61_unblob() {
  module_title "${FUNCNAME[0]}"

  if [[ "$LIST_DEP" -eq 1 ]] || [[ $IN_DOCKER -eq 1 ]] || [[ $DOCKER_SETUP -eq 0 ]] || [[ $FULL -eq 1 ]]; then
    cd "$HOME_PATH" || ( echo "Could not install EMBA component unblob" && exit 1 )
    INSTALL_APP_LIST=()

    print_tool_info "python3-pip" 1
    print_tool_info "libpython3-dev" 1
    print_tool_info "zlib1g" 1
    print_tool_info "zlib1g-dev" 1
    print_tool_info "liblzo2-2" 1
    print_tool_info "liblzo2-dev" 1
    print_tool_info "python3-lzo" 1
    print_tool_info "e2fsprogs" 1
    print_tool_info "gcc" 1
    print_tool_info "git" 1
    # print_tool_info "img2simg" 1
    print_tool_info "android-sdk-libsparse-utils" 1
    print_tool_info "liblzo2-dev" 1
    print_tool_info "lz4"
    print_tool_info "lziprecover" 1
    print_tool_info "lzop" 1
    print_tool_info "p7zip-full" 1
    print_tool_info "unar" 1
    print_tool_info "xz-utils" 1
    print_tool_info "zlib1g-dev" 1
    print_tool_info "libmagic1" 1
    print_tool_info "libhyperscan5" 1
    print_tool_info "libhyperscan-dev" 1
    print_tool_info "zstd" 1
    print_tool_info "python3-magic" 1
    print_tool_info "pkg-config" 1
    print_tool_info "pkgconf" 1

    print_file_info "sasquatch_1.0_amd64.deb" "sasquatch_1.0_amd64.deb" "https://github.com/onekey-sec/sasquatch/releases/download/sasquatch-v1.0/sasquatch_1.0_amd64.deb" "external/sasquatch_1.0_amd64.deb"

    print_git_info "unblob" "EMBA-support-repos/unblob" "Unblob is a powerful firmware extractor"

    echo -e "$ORANGE""Unblob will be downloaded and installed via poetry.""$NC"

    if [[ "$LIST_DEP" -eq 1 ]] || [[ $DOCKER_SETUP -eq 1 ]] ; then
      ANSWER=("n")
    else
      echo -e "\\n""$MAGENTA""$BOLD""unblob with all dependencies (if not already on the system) will be downloaded and installed!""$NC"
      ANSWER=("y")
    fi
    case ${ANSWER:0:1} in
      y|Y )
        apt-get install "${INSTALL_APP_LIST[@]}" -y --no-install-recommends

        download_file "sasquatch_1.0_amd64.deb" "https://github.com/onekey-sec/sasquatch/releases/download/sasquatch-v1.0/sasquatch_1.0_amd64.deb" "external/sasquatch_1.0_amd64.deb"
        dpkg -i external/sasquatch_1.0_amd64.deb
        rm -f external/sasquatch_1.0_amd64.deb

        if ! [[ -d external/unblob ]]; then
          git clone https://github.com/EMBA-support-repos/unblob.git external/unblob
        fi

        # install poetry
        python3 -m pip install --upgrade poetry
        cd external/unblob || ( echo "Could not install EMBA component unblob" && exit 1 )

        # install unblob with poetry:
        poetry install --only main
        UNBLOB_PATH=$(poetry env info --path)

        # Temp solution to install hyperscan in a recent version which is installable on Kali:
        # sed -i 's/hyperscan\ =\ \"0.2.0\"//' pyproject.toml
        # poetry env use "$UNBLOB_PATH"
        # poetry add hyperscan

        if [[ -f "$UNBLOB_PATH""/bin/unblob" ]]; then
          export PATH=$PATH:"$UNBLOB_PATH""/bin"
          echo -e "${GREEN}Identified unblob path: $ORANGE$UNBLOB_PATH$NC"
        else
          cd "$HOME_PATH" && ( echo "Could not install EMBA component unblob" && exit 1 )
        fi

        cd "$HOME_PATH" || ( echo "Could not install EMBA component unblob" && exit 1 )

        if command -v unblob > /dev/null ; then
          unblob --show-external-dependencies
          echo -e "$GREEN""unblob installed successfully""$NC"
          echo
        else
          echo -e "$ORANGE""unblob installation failed - check it manually""$NC"
          echo
        fi

        echo -e "${GREEN}Backup unblob environment for read only docker container: $ORANGE$UNBLOB_PATH$NC"
        echo "$UNBLOB_PATH" > external/unblob/unblob_path.cfg
        if [[ -d "$HOME"/.cache ]]; then
          cp -pr "$HOME"/.cache external/unblob/root_cache
          rm -rf "$HOME"/.cache || true
        fi
        # we have seen issues with the installed sasquatch version - lets move it to another name and link to it
        # during the testing phase. With this we are also able to install the binwalk sasquatch version in ||
        if [[ -e /usr/bin/sasquatch ]]; then
          echo -e "${GREEN}Backup unblob sasquatch version to $ORANGE/usr/local/bin/sasquatch_unblob$NC"
          mv /usr/bin/sasquatch /usr/local/bin/sasquatch_unblob
        fi
      ;;
    esac
  fi
}
