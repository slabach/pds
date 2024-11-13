#!/bin/bash
set -e

# Ensure /pds directory exists
mkdir -p /pds

# Dynamically create /pds/pds.env from environment variables
cat <<EOF > /pds/pds.env
PDS_HOSTNAME=${PDS_HOSTNAME}
PDS_ADMIN_PASSWORD=${PDS_ADMIN_PASSWORD}
EOF
echo "/pds/pds.env file created with necessary variables."

# Load the pds.env file
PDS_ENV_FILE="/pds/pds.env"
if [[ -f "$PDS_ENV_FILE" ]]; then
    source "$PDS_ENV_FILE"
else
    echo "Error: $PDS_ENV_FILE not found. Ensure it is present in the container."
    exit 1
fi

# Define user account details from environment variables
EMAIL="${PDS_ADMIN_EMAIL:-admin@perfectfall.com}" # Default if not set
HANDLE="${PDS_ADMIN_HANDLE:-perfectfall.com}"     # Default if not set
PASSWORD="${PDS_ADMIN_PASSWORD}"

# Verify required variables
if [[ -z "$PASSWORD" ]]; then
    echo "Error: PDS_ADMIN_PASSWORD is not set."
    exit 1
fi
if [[ -z "$PDS_HOSTNAME" ]]; then
    echo "Error: PDS_HOSTNAME is not set."
    exit 1
fi

# Create user account
create_account() {
    echo "Creating user account..."
    pdsadmin account create "$EMAIL" "$HANDLE"
    echo "User account created. Fetching DID..."
    DID=$(pdsadmin account list | grep "$HANDLE" | awk '{print $3}')
    if [[ -z "$DID" || "$DID" != did:* ]]; then
        echo "Error: Failed to fetch DID for the created account."
        exit 1
    fi
    echo "DID fetched: $DID"
    reset_password
}

# Reset user password
reset_password() {
    echo "Resetting password for user DID: $DID..."
    curl --fail --silent --show-error --request POST \
        --user "admin:${PDS_ADMIN_PASSWORD}" \
        --header "Content-Type: application/json" \
        --data "{\"did\": \"${DID}\", \"password\": \"${PASSWORD}\"}" \
        "https://${PDS_HOSTNAME}/xrpc/com.atproto.admin.updateAccountPassword" >/dev/null
    echo "Password reset successfully."
}

# Check if account exists
if pdsadmin account list | grep -q "$HANDLE"; then
    echo "User account already exists."
else
    create_account
fi

# Start the application
exec "$@"

