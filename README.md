## 📚 Comprehensive Guide to Setting Up a Backend with Supabase Functions

### 🔍 Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Step 1: Install Supabase CLI](#step-1-install-supabase-cli)
4. [Step 2: Initialize Supabase Project](#step-2-initialize-supabase-project)
5. [Step 3: Configure the Database](#step-3-configure-the-database)
6. [Step 4: Create Supabase Functions](#step-4-create-supabase-functions)
7. [Step 5: Deploy Supabase Functions](#step-5-deploy-supabase-functions)
8. [Step 6: Obtain Function URLs](#step-6-obtain-function-urls)
9. [Step 7: Integrate with Your Desktop Application](#step-7-integrate-with-your-desktop-application)
10. [Optional: Automated Setup Script](#optional-automated-setup-script)
11. [Security Considerations](#security-considerations)
12. [Troubleshooting](#troubleshooting)
13. [Conclusion](#conclusion)

---

## Overview

This guide will help you set up a robust backend using **Supabase Functions**, enabling seamless communication between your desktop application and the Supabase backend. The setup includes user authentication, license management, hardware ID logging, and more—all managed through serverless functions.

---

## Prerequisites

Before proceeding, ensure you have the following installed on your system:

1. **Operating System**: Unix-like environment (e.g., Linux, macOS, or Windows Subsystem for Linux [WSL]).
2. **Node.js**: Version 14 or higher.
   - **Installation**:
     ```bash
     curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
     sudo apt-get install -y nodejs
     ```
     *(Replace `18.x` with your desired version if necessary.)*

3. **npm**: Comes bundled with Node.js.
4. **Git**:
   - **Installation**:
     ```bash
     sudo apt-get update
     sudo apt-get install -y git
     ```

5. **Deno**: A secure runtime for JavaScript and TypeScript.
   - **Installation**:
     ```bash
     curl -fsSL https://deno.land/x/install/install.sh | sh
     ```
   - **Verify Installation**:
     ```bash
     deno --version
     ```

6. **Supabase Account**: Sign up at [Supabase](https://supabase.com/).

7. **Access to the Supabase Project**: Ensure you have the necessary API keys and project reference ID.

---

## Step 1: Install Supabase CLI

Supabase CLI is essential for managing your Supabase projects and deploying functions. Follow these steps to install it correctly.

### **A. Install Using the `.deb` Package (For Debian/Ubuntu-Based Systems)**

1. **Download the Supabase CLI `.deb` Package**

   Replace `<VERSION>` with the desired version number (e.g., `v1.204.3`).

   ```bash
   wget https://github.com/supabase/cli/releases/download/v1.204.3/supabase_1.204.3_linux_amd64.deb -O supabase_cli.deb
   ```

2. **Install the `.deb` Package**

   ```bash
   sudo dpkg -i supabase_cli.deb
   ```

3. **Fix Any Dependency Issues**

   If the installation reports missing dependencies, fix them with:

   ```bash
   sudo apt-get install -f
   ```

4. **Verify Installation**

   ```bash
   supabase --version
   ```

   **Expected Output:**

   ```
   supabase-cli 1.204.3
   ```

### **B. Alternative: Install Using the Official Installation Script**

If you prefer using the installation script provided by Supabase:

1. **Run the Installation Script**

   ```bash
   curl -sSL https://cli.supabase.com/install.sh | sh
   ```

2. **Reload Your Shell Configuration**

   ```bash
   source ~/.bashrc
   ```
   
   *Or, if you use `zsh`:*

   ```bash
   source ~/.zshrc
   ```

3. **Verify Installation**

   ```bash
   supabase --version
   ```

   **Expected Output:**

   ```
   supabase-cli 1.204.3
   ```

---

## Step 2: Initialize Supabase Project

Now that the Supabase CLI is installed, initialize your local Supabase project.

1. **Log In to Supabase CLI**

   ```bash
   supabase login
   ```

   This command will open a browser window for authentication. Follow the prompts to log in.

2. **Initialize the Supabase Project**

   Navigate to your desired project directory and run:

   ```bash
   mkdir supabase_backend
   cd supabase_backend
   supabase init
   ```

   **Output:**

   ```
   initializing supabase
   ```

   This creates a `.supabase` directory containing configuration files.

---

## Step 3: Configure the Database

Set up the necessary tables and Row-Level Security (RLS) policies in your Supabase database.

### **A. Create Database Tables and RLS Policies**

1. **Create a Migration File**

   ```bash
   mkdir -p supabase/migrations
   MIGRATION_FILE="supabase/migrations/$(date +"%Y%m%d%H%M%S")_init.sql"
   ```

2. **Add SQL Commands to the Migration File**

   Open the migration file in your preferred text editor and add the following SQL commands:

   ```sql
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
   ```

3. **Apply the Migration**

   ```bash
   supabase db push
   ```

   **Output:**

   ```
   applying migration supabase/migrations/YYYYMMDDHHMMSS_init.sql
   ```

   This command applies the SQL migration to your Supabase database, creating the necessary tables and RLS policies.

---

## Step 4: Create Supabase Functions

Develop serverless functions to handle user registration, license management, and hardware ID logging.

### **A. Structure of Supabase Functions**

Your project directory should look like this:

```
supabase_backend/
├── supabase/
│   ├── migrations/
│   │   └── YYYYMMDDHHMMSS_init.sql
│   └── functions/
│       ├── auth/
│       │   └── index.ts
│       ├── license/
│       │   └── index.ts
│       └── hardware/
│           └── index.ts
└── .env
```

### **B. Create Function Files**

1. **Authentication Function (`auth`)**

   **Path**: `supabase/functions/auth/index.ts`

   ```typescript
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
   ```

2. **License Management Function (`license`)**

   **Path**: `supabase/functions/license/index.ts`

   ```typescript
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
   ```

3. **Hardware Logging Function (`hardware`)**

   **Path**: `supabase/functions/hardware/index.ts`

   ```typescript
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
   ```

---

## Step 5: Deploy Supabase Functions

Deploy the created functions to Supabase using the CLI.

1. **Navigate to Your Project Directory**

   Ensure you're in the `supabase_backend` directory:

   ```bash
   cd supabase_backend
   ```

2. **Deploy Each Function**

   - **Authentication Function**

     ```bash
     supabase functions deploy auth --project-ref YOUR_PROJECT_REF
     ```

   - **License Management Function**

     ```bash
     supabase functions deploy license --project-ref YOUR_PROJECT_REF
     ```

   - **Hardware Logging Function**

     ```bash
     supabase functions deploy hardware --project-ref YOUR_PROJECT_REF
     ```

   **Replace `YOUR_PROJECT_REF`** with your actual Supabase project reference ID (e.g., `xyz123`).

   **Note**: The first time you deploy functions, it may take a few moments.

3. **Verify Deployment**

   After deployment, you should see output confirming each function's deployment.

---

## Step 6: Obtain Function URLs

Retrieve the URLs of your deployed functions to integrate them into your desktop application.

1. **List Deployed Functions**

   ```bash
   supabase functions list --project-ref YOUR_PROJECT_REF
   ```

2. **Sample Output**

   ```
   +-----------+--------------------------------------------+----------+
   | Function  | URL                                        | Runtime  |
   +-----------+--------------------------------------------+----------+
   | auth      | https://xyz123.functions.supabase.co/auth  | deno     |
   | license   | https://xyz123.functions.supabase.co/license | deno   |
   | hardware  | https://xyz123.functions.supabase.co/hardware | deno  |
   +-----------+--------------------------------------------+----------+
   ```

3. **Note the URLs**

   Use these URLs in your desktop application to interact with the backend.

---

## Step 7: Integrate with Your Desktop Application

With your Supabase Functions deployed and their URLs obtained, integrate them into your desktop application.

### **A. User Registration**

- **Endpoint**: `POST https://<project-ref>.functions.supabase.co/auth`

- **Sample Request Using `fetch` (JavaScript)**

  ```javascript
  fetch('https://xyz123.functions.supabase.co/auth', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      email: 'user@example.com',
      password: 'securepassword'
    })
  })
    .then(response => response.json())
    .then(data => {
      if (data.error) {
        console.error('Registration Error:', data.error);
      } else {
        console.log('Registration Success:', data);
      }
    })
    .catch(error => console.error('Fetch Error:', error));
  ```

### **B. License Management**

#### **1. Create License**

- **Endpoint**: `POST https://<project-ref>.functions.supabase.co/license`

- **Sample Request**

  ```javascript
  fetch('https://xyz123.functions.supabase.co/license', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      user_id: 'user_uuid',
      valid_until: '2024-12-31T23:59:59Z'
    })
  })
    .then(response => response.json())
    .then(data => {
      if (data.error) {
        console.error('License Creation Error:', data.error);
      } else {
        console.log('License Created:', data);
      }
    })
    .catch(error => console.error('Fetch Error:', error));
  ```

#### **2. Retrieve Licenses**

- **Endpoint**: `GET https://<project-ref>.functions.supabase.co/license?user_id=<user_uuid>`

- **Sample Request**

  ```javascript
  fetch('https://xyz123.functions.supabase.co/license?user_id=user_uuid', {
    method: 'GET',
    headers: {
      'Content-Type': 'application/json'
    }
  })
    .then(response => response.json())
    .then(data => {
      if (data.error) {
        console.error('License Retrieval Error:', data.error);
      } else {
        console.log('User Licenses:', data.licenses);
      }
    })
    .catch(error => console.error('Fetch Error:', error));
  ```

### **C. Hardware ID and IP Logging**

- **Endpoint**: `POST https://<project-ref>.functions.supabase.co/hardware`

- **Sample Request**

  ```javascript
  fetch('https://xyz123.functions.supabase.co/hardware', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      user_id: 'user_uuid',
      hardware_id: 'unique_hardware_id'
    })
  })
    .then(response => response.json())
    .then(data => {
      if (data.error) {
        console.error('Hardware Logging Error:', data.error);
      } else {
        console.log('Hardware Logged:', data);
      }
    })
    .catch(error => console.error('Fetch Error:', error));
  ```

---

## Optional: Automated Setup Script

To further streamline the setup process, you can use an **automated bash script**. This script will:

1. **Check and install necessary dependencies**.
2. **Install the Supabase CLI** using the `.deb` package.
3. **Initialize the Supabase project**.
4. **Create database tables and RLS policies**.
5. **Create and deploy Supabase Functions**.
6. **Provide function URLs** for integration.

### **A. Create the Automated Setup Script**

1. **Download the Script File**

   ```bash
   git clone https://github.com/JPShag/AutoAuth.git
   chmod +x automated_setup.sh
   ```

2. **Run the Automated Setup Script**

   ```bash
   ./automated_setup.sh
   ```

   **Script Workflow:**

   - **Checks for Required Tools**: Verifies installation of Node.js, npm, Git, Deno, and Supabase CLI.
   - **Installs Supabase CLI**: Downloads and installs the `.deb` package if not already installed.
   - **Prompts for Project Details**: Collects necessary Supabase project information.
   - **Initializes Supabase Project**: Sets up local project configuration.
   - **Creates and Applies Database Migrations**: Sets up tables and RLS policies.
   - **Creates Supabase Functions**: Sets up serverless functions for auth, license management, and hardware logging.
   - **Deploys Functions**: Uploads functions to Supabase.
   - **Displays Function URLs**: Provides endpoints for integration.
   - **Optional Local Development**: Offers to start Supabase's local development environment.

   **Example Output:**

   ```
   [INFO] Supabase CLI not found. Installing Supabase CLI...
   [INFO] Downloading Supabase CLI from https://github.com/supabase/cli/releases/download/v1.204.3/supabase_v1.204.3_linux_amd64.deb...
   [INFO] Installing Supabase CLI...
   [SUCCESS] Supabase CLI installed successfully.
   [INFO] Please provide your Supabase project details.
   Enter your Supabase Project Reference (found in your Supabase project URL, e.g., xyz123):
   Enter your Supabase Service Role Key:
   Enter your Supabase Anon Key:
   Enter your Supabase URL (e.g., https://xyz123.supabase.co):
   Enter the port number for local development (default: 3000):
   [INFO] Initializing Supabase project locally...
   initializing supabase
   [INFO] Creating database tables and RLS policies...
   [SUCCESS] Database migration file created at supabase/migrations/20241010HHMMSS_init.sql
   [INFO] Applying migrations to Supabase database...
   applying migration supabase/migrations/20241010HHMMSS_init.sql
   [SUCCESS] Database tables and policies set up successfully.
   [INFO] Creating Supabase Functions...
   [SUCCESS] Supabase Functions created successfully.
   [INFO] Creating environment variables for Supabase Functions...
   [SUCCESS] .env file created successfully.
   [INFO] Deploying Supabase Functions...
   Deploying auth function...
   Deploying license function...
   Deploying hardware function...
   [SUCCESS] Supabase Functions deployed successfully.
   [INFO] Fetching deployed function URLs...
   [SUCCESS] Functions deployed:
   ✅ Auth Function: https://xyz123.functions.supabase.co/auth
   ✅ License Function: https://xyz123.functions.supabase.co/license
   ✅ Hardware Function: https://xyz123.functions.supabase.co/hardware
   Do you want to start Supabase local development? (y/n):
   ```

---

## Security Considerations

Ensuring the security of your backend and user data is paramount. Follow these best practices:

1. **Environment Variables**

   - **Protect `.env` File**: Contains sensitive information. **Never commit** this file to version control.
   - **Add to `.gitignore`**:

     ```bash
     echo ".env" >> .gitignore
     ```

2. **Service Role Key**

   - **Keep Secret**: This key has elevated privileges and can bypass RLS policies.
   - **Usage**: Only within server-side functions. **Do not expose** in client-side code.

3. **Row-Level Security (RLS)**

   - **Enforce Data Access**: Ensures users can only access their own data.
   - **Review Policies**: Adjust as per application requirements.
   - **Documentation**: Refer to [Supabase RLS Documentation](https://supabase.com/docs/guides/auth/row-level-security).

4. **HTTPS**

   - **Encrypted Communication**: All Supabase Functions are accessible over HTTPS.
   - **Ensure Clients Use HTTPS**: When making requests from your desktop application.

5. **Input Validation**

   - **Sanitize Inputs**: Prevent SQL injection and other malicious inputs.
   - **Implement Validation**: Use libraries or built-in methods to validate data types and formats.

6. **Rate Limiting**

   - **Prevent Abuse**: Limit the number of requests a user can make within a timeframe.
   - **Implementation**: Currently, Supabase Functions do not have built-in rate limiting. Consider implementing manually or using external services.

7. **Monitoring and Logging**

   - **Track Function Executions**: Use Supabase's logging capabilities to monitor and debug.
   - **Review Logs Regularly**: Identify and address potential security issues.

---

## Troubleshooting

If you encounter issues during the setup, refer to the following common problems and solutions.

### **1. Supabase CLI Installation Errors**

- **Error Message**:

  ```
  Installing Supabase CLI as a global module is not supported.
  Please use one of the supported package managers: https://github.com/supabase/cli#install-the-cli
  ```

- **Solution**:

  - Ensure you're using the correct installation method (either `.deb` package or official installation script).
  - Verify that you have the necessary permissions (use `sudo` when required).
  - Check the Supabase CLI GitHub repository for the latest installation instructions.

### **2. Migration Application Issues**

- **Error Message**:

  ```
  ERROR: permission denied for table users
  ```

- **Solution**:

  - Ensure that the **Service Role Key** has the necessary permissions.
  - Verify that RLS policies are correctly set up to allow the intended operations.
  - Check if the Supabase project URL and keys are correctly specified in the `.env` file.

### **3. Function Deployment Failures**

- **Error Message**:

  ```
  Error: Failed to deploy function auth
  ```

- **Solution**:

  - Verify that the function code is free of syntax errors.
  - Ensure that the Supabase CLI is authenticated (`supabase login`).
  - Check internet connectivity.
  - Review function logs for detailed error messages:

    ```bash
    supabase functions logs auth --project-ref YOUR_PROJECT_REF
    ```

### **4. Function URLs Not Displayed Correctly**

- **Issue**:

  - The script fails to extract the correct function URLs.

- **Solution**:

  - Manually retrieve function URLs via the Supabase dashboard.
  - Alternatively, list functions and extract URLs:

    ```bash
    supabase functions list --project-ref YOUR_PROJECT_REF
    ```

### **5. Deno Not Recognized**

- **Error Message**:

  ```
  deno: command not found
  ```

- **Solution**:

  - Ensure Deno is installed correctly.
  - Add Deno to your PATH if necessary.

    ```bash
    export DENO_INSTALL="/home/your_username/.deno"
    export PATH="$DENO_INSTALL/bin:$PATH"
    source ~/.bashrc
    ```

---

## Conclusion

By following this updated guide, you can successfully set up a backend using Supabase Functions, ensuring seamless communication between your desktop application and the Supabase backend. The automated setup script further simplifies the process, handling installations, project initialization, and function deployments efficiently.

**Key Benefits:**

- **Serverless Architecture**: No need to manage backend servers.
- **Scalability**: Functions automatically scale with demand.
- **Security**: Leveraging Supabase's RLS and secure function deployments.
- **Ease of Integration**: Clear function URLs for straightforward integration with your desktop application.

---

## Additional Resources

- **Supabase Documentation**: [https://supabase.com/docs](https://supabase.com/docs)
- **Supabase CLI GitHub Repository**: [https://github.com/supabase/cli](https://github.com/supabase/cli)
- **Deno Documentation**: [https://deno.land/manual](https://deno.land/manual)
- **Sift Framework for Deno**: [https://github.com/lukeed/sift](https://github.com/lukeed/sift)
- **Supabase Functions Documentation**: [https://supabase.com/docs/guides/functions](https://supabase.com/docs/guides/functions)

---

**If you encounter any further issues or need additional assistance, feel free to ask. I'm here to help!**
