#!/bin/bash

# Automated Setup Script for Supabase Functions Backend

# Exit immediately if a command exits with a non-zero status
set -e

# Function to display messages
function echo_info() {
  echo -e "\e[34m[INFO]\e[0m $1"
}

function echo_success() {
  echo -e "\e[32m[SUCCESS]\e[0m $1"
}

function echo_error() {
  echo -e "\e[31m[ERROR]\e[0m $1"
}

# Check for Node.js and npm
if ! command -v node &> /dev/null
then
    echo_error "Node.js is not installed. Please install Node.js (v14 or higher) and try again."
    exit 1
fi

if ! command -v npm &> /dev/null
then
    echo_error "npm is not installed. Please install npm and try again."
    exit 1
fi

# Check for Git
if ! command -v git &> /dev/null
then
    echo_error "Git is not installed. Please install Git and try again."
    exit 1
fi

# Check for Deno
if ! command -v deno &> /dev/null
then
    echo_error "Deno is not installed. Please install Deno and try again."
    exit 1
fi

# Install Supabase CLI if not installed
if ! command -v supabase &> /dev/null
then
    echo_info "Supabase CLI not found. Installing Supabase CLI..."

    # Detect OS and Architecture
    OS=$(uname | tr '[:upper:]' '[:lower:]')
    ARCH=$(uname -m)

    case "$ARCH" in
        x86_64|amd64)
            ARCH="amd64"
            ;;
        aarch64|arm64)
            ARCH="arm64"
            ;;
        *)
            echo_error "Unsupported architecture: $ARCH"
            exit 1
            ;;
    esac

    SUPABASE_CLI_VERSION="v1.204.3"
    SUPABASE_CLI_URL="https://github.com/supabase/cli/releases/download/${SUPABASE_CLI_VERSION}/supabase_${SUPABASE_CLI_VERSION}_${OS}_${ARCH}.deb"

    # Download the Supabase CLI .deb package
    echo_info "Downloading Supabase CLI from $SUPABASE_CLI_URL..."
    wget "$SUPABASE_CLI_URL" -O supabase_cli.deb

    # Install the .deb package
    echo_info "Installing Supabase CLI..."
    sudo dpkg -i supabase_cli.deb || sudo apt-get install -f -y

    # Remove the .deb package
    rm supabase_cli.deb

    # Verify installation
    if command -v supabase &> /dev/null
    then
        echo_success "Supabase CLI installed successfully."
    else
        echo_error "Failed to install Supabase CLI. Please install it manually from https://github.com/supabase/cli#install-the-cli"
        exit 1
    fi
else
    echo_info "Supabase CLI is already installed."
fi

# Prompt user for Supabase project details
echo_info "Please provide your Supabase project details."

read -p "Enter your Supabase Project Reference (found in your Supabase project URL, e.g., xyz123): " SUPABASE_PROJECT_REF
read -p "Enter your Supabase Service Role Key: " SUPABASE_SERVICE_ROLE_KEY
read -p "Enter your Supabase Anon Key: " SUPABASE_ANON_KEY
read -p "Enter your Supabase URL (e.g., https://xyz123.supabase.co): " SUPABASE_URL
read -p "Enter the port number for local development (default: 3000): " PORT
PORT=${PORT:-3000}

# Create project directory
PROJECT_DIR="supabase_backend"
mkdir -p $PROJECT_DIR
cd $PROJECT_DIR

echo_info "Initializing Supabase project locally..."
supabase init

# Create SQL migration file
MIGRATIONS_DIR="supabase/migrations"
mkdir -p $MIGRATIONS_DIR
MIGRATION_FILE="$MIGRATIONS_DIR/$(date +"%Y%m%d%H%M%S")_init.sql"

echo_info "Creating database tables and RLS policies..."

cat > $MIGRATION_FILE <<EOL
-- Enable extensions
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Users Table
CREATE TABLE IF NOT EXISTS users (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  email text UNIQUE NOT NULL,
  password text NOT NULL,
  created_at timestamp with time zone DEFAULT timezone('utc', now())
);

-- Licenses Table
CREATE TABLE IF NOT EXISTS licenses (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES users(id) ON DELETE CASCADE,
  license_key text UNIQUE NOT NULL,
  valid_until timestamp with time zone,
  created_at timestamp with time zone DEFAULT timezone('utc', now())
);

-- Hardware IDs Table
CREATE TABLE IF NOT EXISTS hardware_ids (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES users(id) ON DELETE CASCADE,
  hardware_id text NOT NULL,
  ip_address text,
  last_used timestamp with time zone DEFAULT timezone('utc', now())
);

-- Enable Row Level Security
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE licenses ENABLE ROW LEVEL SECURITY;
ALTER TABLE hardware_ids ENABLE ROW LEVEL SECURITY;

-- Users Table Policies
CREATE POLICY "Users select own data" ON users
  FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Users insert" ON users
  FOR INSERT WITH CHECK (true);

CREATE POLICY "Users update own data" ON users
  FOR UPDATE USING (auth.uid() = id);

-- Licenses Table Policies
CREATE POLICY "Licenses select own licenses" ON licenses
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Licenses insert for authenticated users" ON licenses
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Licenses update own licenses" ON licenses
  FOR UPDATE USING (auth.uid() = user_id);

-- Hardware IDs Table Policies
CREATE POLICY "Hardware select own data" ON hardware_ids
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Hardware insert for authenticated users" ON hardware_ids
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Hardware update own data" ON hardware_ids
  FOR UPDATE USING (auth.uid() = user_id);
EOL

echo_success "Database migration file created at $MIGRATION_FILE"

# Apply migrations to Supabase
echo_info "Applying migrations to Supabase database..."
supabase db push --project-ref $SUPABASE_PROJECT_REF

echo_success "Database tables and policies set up successfully."

# Create Supabase Functions
FUNCTIONS_DIR="supabase/functions"
mkdir -p $FUNCTIONS_DIR

echo_info "Creating Supabase Functions..."

# a. Authentication Function
AUTH_FUNCTION_DIR="$FUNCTIONS_DIR/auth"
mkdir -p $AUTH_FUNCTION_DIR

cat > $AUTH_FUNCTION_DIR/index.ts <<EOL
import { serve } from "https://deno.land/x/sift@0.4.3/mod.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
);

serve(async (req) => {
  if (req.method === "POST") {
    const { email, password } = await req.json();

    const { data, error } = await supabase.auth.signUp({
      email,
      password,
    });

    if (error) {
      return new Response(JSON.stringify({ error: error.message }), { status: 400 });
    }

    return new Response(JSON.stringify({ message: "User registered successfully", data }), { status: 201 });
  }

  return new Response("Method Not Allowed", { status: 405 });
});
EOL

# b. License Management Function
LICENSE_FUNCTION_DIR="$FUNCTIONS_DIR/license"
mkdir -p $LICENSE_FUNCTION_DIR

cat > $LICENSE_FUNCTION_DIR/index.ts <<EOL
import { serve } from "https://deno.land/x/sift@0.4.3/mod.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { v4 } from "https://deno.land/std@0.178.0/uuid/mod.ts";

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
);

serve(async (req) => {
  if (req.method === "POST") {
    const { user_id, valid_until } = await req.json();
    const license_key = v4.generate();

    const { data, error } = await supabase.from("licenses").insert([
      {
        user_id,
        license_key,
        valid_until,
      },
    ]);

    if (error) {
      return new Response(JSON.stringify({ error: error.message }), { status: 400 });
    }

    return new Response(JSON.stringify({ message: "License created successfully", data }), { status: 201 });
  }

  if (req.method === "GET") {
    const url = new URL(req.url);
    const user_id = url.searchParams.get("user_id");

    if (!user_id) {
      return new Response(JSON.stringify({ error: "user_id is required" }), { status: 400 });
    }

    const { data, error } = await supabase.from("licenses").select("*").eq("user_id", user_id);

    if (error) {
      return new Response(JSON.stringify({ error: error.message }), { status: 400 });
    }

    return new Response(JSON.stringify({ licenses: data }), { status: 200 });
  }

  return new Response("Method Not Allowed", { status: 405 });
});
EOL

# c. Hardware Logging Function
HARDWARE_FUNCTION_DIR="$FUNCTIONS_DIR/hardware"
mkdir -p $HARDWARE_FUNCTION_DIR

cat > $HARDWARE_FUNCTION_DIR/index.ts <<EOL
import { serve } from "https://deno.land/x/sift@0.4.3/mod.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
);

serve(async (req) => {
  if (req.method === "POST") {
    const { user_id, hardware_id } = await req.json();
    const ip_address = req.headers.get("x-forwarded-for") || req.conn.remoteAddr.hostname;

    const { data, error } = await supabase.from("hardware_ids").insert([
      {
        user_id,
        hardware_id,
        ip_address,
      },
    ]);

    if (error) {
      return new Response(JSON.stringify({ error: error.message }), { status: 400 });
    }

    return new Response(JSON.stringify({ message: "Hardware ID logged successfully", data }), { status: 201 });
  }

  return new Response("Method Not Allowed", { status: 405 });
});
EOL

echo_success "Supabase Functions created successfully."

# Create Environment Variables File for Functions
echo_info "Creating environment variables for Supabase Functions..."

cat > .env <<EOL
SUPABASE_URL=$SUPABASE_URL
SUPABASE_SERVICE_ROLE_KEY=$SUPABASE_SERVICE_ROLE_KEY
SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY
PORT=$PORT
EOL

echo_success ".env file created successfully."

# Deploy Supabase Functions
echo_info "Deploying Supabase Functions..."

supabase functions deploy auth --project-ref $SUPABASE_PROJECT_REF
supabase functions deploy license --project-ref $SUPABASE_PROJECT_REF
supabase functions deploy hardware --project-ref $SUPABASE_PROJECT_REF

echo_success "Supabase Functions deployed successfully."

# Provide Function URLs
echo_info "Fetching deployed function URLs..."

AUTH_URL=$(supabase functions list --project-ref $SUPABASE_PROJECT_REF | grep auth | awk '{print $4}')
LICENSE_URL=$(supabase functions list --project-ref $SUPABASE_PROJECT_REF | grep license | awk '{print $4}')
HARDWARE_URL=$(supabase functions list --project-ref $SUPABASE_PROJECT_REF | grep hardware | awk '{print $4}')

echo_success "Functions deployed:"
echo -e "✅ Auth Function: \e[33m$AUTH_URL\e[0m"
echo -e "✅ License Function: \e[33m$LICENSE_URL\e[0m"
echo -e "✅ Hardware Function: \e[33m$HARDWARE_URL\e[0m"

# Start Supabase Local Development (Optional)
read -p "Do you want to start Supabase local development? (y/n): " START_LOCAL
if [[ "$START_LOCAL" == "y" || "$START_LOCAL" == "Y" ]]; then
    echo_info "Starting Supabase local development..."
    supabase start --project-ref $SUPABASE_PROJECT_REF
fi

echo_success "Automated setup completed successfully!"
echo -e "Your Supabase Functions are ready to be integrated into your desktop application."

echo -e "\n📚 Next Steps:"
echo -e "1. Use the provided function URLs in your desktop application to interact with the backend."
echo -e "2. Ensure your desktop application securely handles the Supabase keys."
echo -e "3. Refer to the API Documentation for usage details.\n"
