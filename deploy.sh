#!/bin/bash
#
# Interactive deployment script for the n8n, Traefik, Postgres, and Redis stack.
# This script will:
# 1. Check for Docker and install it if it's not present.
# 2. Install htpasswd for Traefik password generation.
# 3. Interactively create the .env file from env-example.
# 4. Deploy the stack using Docker Compose.

# Exit immediately if a command exits with a non-zero status.
set -e

# --- Helper Functions for Logging ---
log_info() {
    echo "INFO: $1"
}

log_warn() {
    echo "WARN: $1"
}

log_success() {
    echo "✅ SUCCESS: $1"
}

log_error() {
    echo "❌ ERROR: $1" >&2
    exit 1
}

# --- 1. Check and Install Dependencies ---
log_info "Checking for Docker installation..."
if ! command -v docker &> /dev/null; then
    log_warn "Docker not found. Starting installation..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    rm get-docker.sh
    log_success "Docker installed successfully."

    log_info "Adding current user (${USER}) to the 'docker' group..."
    sudo usermod -aG docker "${USER}"
    log_warn "You may need to log out and log back in for group changes to take effect."
    log_info "The script will proceed using 'sudo' for Docker commands to ensure it works in this session."
else
    log_success "Docker is already installed."
fi

log_info "Checking for htpasswd (for Traefik password)..."
if ! command -v htpasswd &> /dev/null; then
    log_warn "htpasswd not found. Installing apache2-utils..."
    sudo apt-get update && sudo apt-get install -y apache2-utils
    log_success "htpasswd installed successfully."
else
    log_success "htpasswd is already installed."
fi

# Define the docker command to use (with sudo if the user isn't in the group yet)
DOCKER_CMD="docker"
if ! groups "${USER}" | grep -q '\bdocker\b'; then
    DOCKER_CMD="sudo docker"
fi

# --- 2. Create and Configure .env File ---
log_info "Checking for .env configuration file..."
if [ -f ".env" ]; then
    log_info ".env file already exists. Skipping creation."
else
    log_warn ".env file not found. Creating from 'env-example'..."
    if [ ! -f "env-example" ]; then
        log_error "'env-example' file not found. Cannot proceed."
    fi

    cp env-example .env
    log_info "Please provide the values for your environment variables."

    while IFS= read -r line || [[ -n "$line" ]]; do
        if [[ "$line" =~ ^#.*$ ]] || [[ -z "$line" ]]; then
            continue
        fi

        VAR_NAME=$(echo "$line" | cut -d '=' -f 1)
        USER_INPUT=""
        FINAL_VALUE=""

        # Handle special cases for specific variables
        case "$VAR_NAME" in
            "TIMEZONE" | "GENERIC_TIMEZONE")
                read -p "Enter value for ${VAR_NAME} (default: Asia/Jakarta): " USER_INPUT < /dev/tty
                # If the user just presses enter, use the default value
                if [ -z "$USER_INPUT" ]; then
                    FINAL_VALUE="Asia/Jakarta"
                else
                    FINAL_VALUE="$USER_INPUT"
                fi
                ;;
            "TRAEFIK_DASHBOARD_PWD")
                read -p "Enter a plain-text password for the Traefik dashboard: " USER_INPUT < /dev/tty
                if [ -z "$USER_INPUT" ]; then
                    log_error "Traefik password cannot be empty."
                fi
                # Generate bcrypt hash and escape the dollar signs for Traefik
                FINAL_VALUE=$(htpasswd -nbB admin "$USER_INPUT" | cut -d ':' -f 2 | sed 's/\$/\$\$/g')
                log_info "Generated Traefik-compatible password hash."
                ;;
            *)
                # Default behavior for all other variables
                read -p "Enter value for ${VAR_NAME}: " USER_INPUT < /dev/tty
                FINAL_VALUE="$USER_INPUT"
                ;;
        esac

        # Escape special characters for sed before writing to the file
        ESCAPED_VALUE=$(printf '%s\n' "$FINAL_VALUE" | sed -e 's/[\/&]/\\&/g')
        sed -i "s/^${VAR_NAME}=.*/${VAR_NAME}=${ESCAPED_VALUE}/" .env

    done < "env-example"

    log_success ".env file has been configured."
fi

# --- 3. Deploy the Application ---
log_info "Starting the deployment with Docker Compose..."
$DOCKER_CMD compose up -d

if [ $? -eq 0 ]; then
    log_success "Application deployed successfully!"
    log_info "It may take a few minutes for all services to be fully up and running."
else
    log_error "Deployment failed. Please check the output above for errors."
fi
