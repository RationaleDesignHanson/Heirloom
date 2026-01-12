#!/bin/bash
# Distiller Sync Helper Script
# Sync Heirloom project between Mac and Distiller device

DISTILLER_IP="192.168.1.215"
DISTILLER_USER="distiller"
DISTILLER_PROJECT_PATH="~/projects/Heirloom"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Distiller Sync Tool ===${NC}\n"

# Function to check Distiller connection
check_connection() {
    echo -e "${YELLOW}Checking Distiller connection...${NC}"
    if ssh -o ConnectTimeout=3 ${DISTILLER_USER}@${DISTILLER_IP} "echo 'Connected'" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Distiller is reachable${NC}\n"
        return 0
    else
        echo -e "${YELLOW}✗ Cannot reach Distiller at ${DISTILLER_IP}${NC}"
        echo "Make sure the device is powered on and connected to your network."
        exit 1
    fi
}

# Function to pull changes from Distiller
pull_from_distiller() {
    echo -e "${BLUE}Fetching changes from Distiller...${NC}"
    git fetch origin distiller-dev 2>/dev/null || echo "No distiller-dev branch on remote yet"

    if git rev-parse --verify origin/distiller-dev > /dev/null 2>&1; then
        echo -e "\n${GREEN}Recent commits from Distiller:${NC}"
        git log origin/distiller-dev --oneline -5

        echo -e "\n${YELLOW}Would you like to merge these changes? (y/n)${NC}"
        read -r response
        if [[ "$response" =~ ^[Yy]$ ]]; then
            git checkout distiller-dev 2>/dev/null || git checkout -b distiller-dev origin/distiller-dev
            git pull origin distiller-dev
            git checkout main
            git merge distiller-dev
            echo -e "${GREEN}✓ Changes merged into main${NC}"
        fi
    else
        echo "No distiller-dev branch found yet. Distiller hasn't pushed any changes."
    fi
}

# Function to push changes to Distiller
push_to_distiller() {
    echo -e "${BLUE}Pushing changes to Distiller...${NC}"
    git push origin main

    echo -e "${YELLOW}Pulling changes on Distiller...${NC}"
    ssh ${DISTILLER_USER}@${DISTILLER_IP} "cd ${DISTILLER_PROJECT_PATH} && git pull origin main"
    echo -e "${GREEN}✓ Distiller updated with latest changes${NC}"
}

# Function to check Distiller status
check_status() {
    echo -e "${BLUE}Distiller Status:${NC}"
    ssh ${DISTILLER_USER}@${DISTILLER_IP} "cd ${DISTILLER_PROJECT_PATH} && echo 'Branch:' && git branch --show-current && echo -e '\nLast 3 commits:' && git log --oneline -3 && echo -e '\nWorking tree:' && git status --short"
}

# Function to open Distiller web interface
open_interface() {
    echo -e "${BLUE}Opening Distiller web interface...${NC}"
    open "http://${DISTILLER_IP}:3000"
}

# Main menu
case "$1" in
    pull)
        check_connection
        pull_from_distiller
        ;;
    push)
        check_connection
        push_to_distiller
        ;;
    status)
        check_connection
        check_status
        ;;
    open)
        open_interface
        ;;
    *)
        echo "Usage: $0 {pull|push|status|open}"
        echo ""
        echo "Commands:"
        echo "  pull   - Fetch and merge changes from Distiller"
        echo "  push   - Push your local changes to Distiller"
        echo "  status - Check Distiller's current git status"
        echo "  open   - Open Distiller web interface in browser"
        echo ""
        echo "Quick access:"
        echo "  Web Interface: http://${DISTILLER_IP}:3000"
        echo "  SSH: ssh ${DISTILLER_USER}@${DISTILLER_IP}"
        exit 1
        ;;
esac
