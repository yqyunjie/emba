#!/bin/bash -p

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

# Description: Uploads the firmware to virustotal
# Important:   This module needs a VT API key in the config file ./config/vt_api_key.txt
#              This key is avilable via your VT profile - https://www.virustotal.com/gui/my-apikey
# Pre-checker threading mode - if set to 1, these modules will run in threaded mode
export PRE_THREAD_ENA=1

P03_firmware_virustotal_check() {

  if [[ "$IN_DOCKER" -eq 1 ]]; then
    print_output "[-] The docker container has no access to the Internet -> no virustotal query possible!" "no_log"
    # module_end_log "${FUNCNAME[0]}" 0
    return
  fi
  module_title "Binary firmware VirusTotal analyzer"
  module_log_init "${FUNCNAME[0]}"
  local NEG_LOG=0
  local VT_UPLOAD_ID=""
  local VT_API_KEY=""
  local URL=""

  if [[ -f "$VT_API_KEY_FILE" && "$ONLINE_CHECKS" -eq 1 && -f "$FIRMWARE_PATH" ]]; then
    VT_API_KEY=$(cat "$VT_API_KEY_FILE")
    # upload our firmware file to VT:
    print_output "[*] Upload to VirusTotal in progress ..."

    # based on code from vt-scan: https://github.com/sevsec/vt-scan
    local FSIZE=0
    FSIZE=$(stat -c %s "$FIRMWARE_PATH")
    if [[ $FSIZE -lt 33554431 ]]; then
      VT_UPLOAD_ID=$(curl -s --request POST --url "https://www.virustotal.com/api/v3/files" --header "x-apikey: $VT_API_KEY" --form "file=@$FIRMWARE_PATH" | jq -r '.data.id')
    else
      URL=$(curl -s --request GET --url "https://www.virustotal.com/api/v3/files/upload_url" --header "x-apikey: $VT_API_KEY" | jq -r .data)
      VT_UPLOAD_ID=$(curl -s --request POST --url "$URL" --header "x-apikey: $VT_API_KEY" --form "file=@$FIRMWARE_PATH" | jq -r '.data.id')
    fi

    if [[ "$VT_UPLOAD_ID" == "null" || -z "$VT_UPLOAD_ID" ]]; then
      print_output "[-] Upload to VirusTotal failed ..."
    else
      # analysis goes here
      wait_vt_analysis "$VT_UPLOAD_ID" "$VT_API_KEY" # no threading here!
      vt_analysis "$VT_UPLOAD_ID" "$VT_API_KEY"
      vt_analysis_beh "$VT_UPLOAD_ID" "$VT_API_KEY"
      NEG_LOG=1
    fi
  else
    if [[ "$ONLINE_CHECKS" -eq 0 ]]; then
      print_output "[-] Online checks are disabled."
    else
      print_output "[-] No Virustotal API key file found in $ORANGE$VT_API_KEY$NC."
    fi
  fi

  module_end_log "${FUNCNAME[0]}" "$NEG_LOG"
}

wait_vt_analysis() {
  local VT_UPLOAD_ID="${1:-}"
  local VT_API_KEY="${2:-}"
  local VT_ANALYSIS_RESP="init"

  print_output "[*] Upload to VirusTotal finished ..."
  print_output "[*] Uploaded firmware to VirusTotal with ID: $ORANGE$VT_UPLOAD_ID$NC"

  while [[ "$VT_ANALYSIS_RESP" != "completed" ]]; do
    VT_ANALYSIS_RESP=$(curl -m 10 -s --request GET --url "https://www.virustotal.com/api/v3/analyses/$VT_UPLOAD_ID" --header "x-apikey: $VT_API_KEY"  | jq -r '.data.attributes.status')
    if [[ "$VT_ANALYSIS_RESP" != "completed" && "$VT_ANALYSIS_RESP" == "queued" ]]; then
      print_dot
    else
      print_output "[*] Analysis of file $ORANGE$FIRMWARE_PATH$NC is $VT_ANALYSIS_RESP."
    fi
    sleep 2
  done
}

vt_analysis() {
  local VT_UPLOAD_ID="${1:-}"
  local VT_API_KEY="${2:-}"
  local VT_SUSP=""
  local VT_MAL=""

  curl -s --request GET --url "https://www.virustotal.com/api/v3/analyses/$VT_UPLOAD_ID" --header "x-apikey: $VT_API_KEY" >> "$TMP_DIR"/vt_response.json

  if [[ $(wc -l "$TMP_DIR"/vt_response.json | awk '{print $1}') -gt 1 ]]; then
    print_ln
    print_output "[*] Firmware metadata reported by VirusTotal:"
    jq -r '.meta' "$TMP_DIR"/vt_response.json | tee -a "$LOG_FILE"
    VT_SUSP=$(jq -r '.data.attributes.stats.suspicious' "$TMP_DIR"/vt_response.json)
    VT_MAL=$(jq -r '.data.attributes.stats.malicious' "$TMP_DIR"/vt_response.json)

    print_ln
    if [[ "$VT_SUSP" -gt 0 || "$VT_MAL" -gt 0 ]]; then
      print_output "[+] Infection via malicious code detected!"
    else
      print_output "[-] No infection via malicious code detected."
    fi

    print_ln
    print_output "[*] VirusTotal test overview:"
    jq -r '.data.attributes' "$TMP_DIR"/vt_response.json | tee -a "$LOG_FILE"
    print_ln
  fi
}

vt_analysis_beh() {
  local VT_UPLOAD_ID="${1:-}"
  local VT_API_KEY="${2:-}"

  curl -s --request GET --url "https://www.virustotal.com/api/v3/files/$VT_UPLOAD_ID/behaviour_summary" --header "x-apikey: $VT_API_KEY" >> "$TMP_DIR"/vt_response_behaviour.json

  if [[ $(wc -l "$TMP_DIR"/vt_response_behaviour.json | awk '{print $1}') -gt 0 ]]; then
    print_ln
    print_output "[*] Firmware behaviour analysis by VirusTotal:"
    jq -r '.meta' "$TMP_DIR"/vt_response.json | tee -a "$LOG_FILE"
  fi
}
