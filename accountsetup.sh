#!/bin/bash
set -e

# Define user account details
EMAIL="${PDS_ADMIN_EMAIL:-admin@perfectfall.com}" # Default if env not set
HANDLE="${PDS_ADMIN_HANDLE:-perfectfall.com}"     # Default if env not set
PASSWORD="${PDS_ADMIN_PASSWORD}"

# Check for required environment variables
if [[ -z "$PASSWORD" ]]; then
    echo "Error: PDS_ADMIN_PASSWORD is not set."
    exit 1
fi

# Function to create user account
create_account() {
    echo "Creating user account..."
    pdsadmin account create "$EMAIL" "$HANDLE"
    echo "User account created."
}

# Function to set user password
set_password() {
    echo "Setting password for user..."
    echo "$PASSWORD" | pdsadmin set-password "$HANDLE"
    echo "Password set successfully."
}

# Check if the account already exists
if pdsadmin account list | grep -q "$HANDLE"; then
    echo "User account already exists."
else
    create_account
    set_password
fi

# Start the application
exec "$@"

