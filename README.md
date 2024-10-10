# **Supabase-based HWID Locking and Multi-Product Licensing System**

## **Overview**

This guide outlines how to build a complete system for **HWID locking**, **multi-product licensing**, **rate limiting**, and **session tracking** using **Supabase** as the backend. The goal is to allow users to register, validate licenses for multiple products, restrict usage based on HWID, and enforce rate limits. The guide also provides instructions for creating a GitHub repository to save all configurations and scripts.

---

## **Table of Contents**
1. [Supabase Setup](#step-1-setting-up-supabase)
2. [Database Schema Design](#step-2-database-schema-design)
    - Users Table
    - Products Table
    - Licenses Table
    - HWID History Table
    - Sessions Table
3. [API and Supabase RPC Functions](#step-3-api-and-supabase-rpc-functions)
    - User Registration
    - HWID Login and Validation
    - License Management
    - Product Management
4. [Rate Limiting Implementation](#step-4-rate-limiting-implementation)
5. [Session Tracking](#step-5-session-tracking-implementation)
6. [Blocking Users](#step-6-blocking-users-and-automated-processes)
7. [Additional Features and Enhancements](#step-8-final-considerations)

---

## **Step 1: Setting Up Supabase**

1. **Create a Supabase Project**:
   - Go to [Supabase](https://supabase.io/) and sign up.
   - Create a new project and note down the **project URL** and **API keys** (both `anon` and `service_role`).

2. **Enable Row-Level Security (RLS)**:
   - For each table containing user-specific data, ensure that **RLS** is enabled for extra security.
   - You’ll apply specific policies as we go along.

---

## **Step 2: Database Schema Design**

### 2.1 **Users Table**

This table stores user information like their email, hashed password, HWID, and whether they are blocked from using the system.

```sql
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email VARCHAR NOT NULL UNIQUE,
    password_hash TEXT NOT NULL,
    hwid VARCHAR UNIQUE,
    is_blocked BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    last_login TIMESTAMPTZ
);
```

- **is_blocked**: This column will be used to block users when necessary.

### 2.2 **Products Table**

This table defines the products for which users can get licenses.

```sql
CREATE TABLE products (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR NOT NULL UNIQUE,
    description TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);
```

### 2.3 **Licenses Table**

This table links users to products and stores license information, including expiration dates.

```sql
CREATE TABLE licenses (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    product_id UUID REFERENCES products(id) ON DELETE CASCADE,
    license_key VARCHAR NOT NULL UNIQUE,
    expiration_date TIMESTAMPTZ,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);
```

### 2.4 **HWID History Table**

This table logs changes in the user’s HWID, useful for security audits.

```sql
CREATE TABLE hwid_history (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    hwid VARCHAR NOT NULL,
    change_timestamp TIMESTAMPTZ DEFAULT now(),
    changed_by UUID REFERENCES users(id)
);
```

### 2.5 **Sessions Table**

Logs user activity and sessions, including their HWID, product, and IP address.

```sql
CREATE TABLE sessions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    product_id UUID REFERENCES products(id),
    hwid VARCHAR NOT NULL,
    ip_address VARCHAR,
    session_token VARCHAR UNIQUE,
    is_valid BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT now(),
    expires_at TIMESTAMPTZ
);
```

---

## **Step 3: API and Supabase RPC Functions**

### 3.1 **User Registration API** (POST `/users`)

Allows users to register by providing their email, password, and HWID.

```http
POST /rest/v1/users
Authorization: Bearer <anon_key>
Content-Type: application/json

{
  "email": "user@example.com",
  "password_hash": "<hashed_password>",
  "hwid": "<user_hwid>"
}
```

### 3.2 **User Login with HWID Validation (Custom RPC)**

We create a custom RPC function that validates login and HWID.

```sql
CREATE OR REPLACE FUNCTION login_user(email TEXT, password_hash TEXT, hwid TEXT)
RETURNS TABLE(user_id UUID, email TEXT, valid_hwid BOOLEAN) 
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY 
    SELECT u.id, u.email, (u.hwid IS NULL OR u.hwid = hwid) AS valid_hwid
    FROM users u
    WHERE u.email = email AND u.password_hash = password_hash;
END;
$$;
```

**Login API Call**:
```http
POST /rest/v1/rpc/login_user
Authorization: Bearer <anon_key>
Content-Type: application/json

{
  "email": "user@example.com",
  "password_hash": "<hashed_password>",
  "hwid": "<current_hwid>"
}
```

### 3.3 **License Management API**

Fetch, create, and manage licenses for users:

- **Fetch User Licenses** (GET `/licenses`):
   ```http
   GET /rest/v1/licenses?user_id=eq.<user_id>
   Authorization: Bearer <anon_key>
   ```

- **Create a License** (POST `/licenses`):
   ```http
   POST /rest/v1/licenses
   Authorization: Bearer <service_role_key>
   Content-Type: application/json

   {
     "user_id": "<user_id>",
     "product_id": "<product_id>",
     "license_key": "<license_key>",
     "expiration_date": "2025-01-01T00:00:00"
   }
   ```

### 3.4 **Product Management API**

- **Fetch Products** (GET `/products`):
   ```http
   GET /rest/v1/products
   Authorization: Bearer <anon_key>
   ```

---

## **Step 4: Rate Limiting Implementation**

### 4.1 **Rate Limits Table**

Create a table to track API requests per user.

```sql
CREATE TABLE rate_limits (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    request_count INT DEFAULT 0,
    period_start TIMESTAMPTZ DEFAULT now(),
    period_end TIMESTAMPTZ DEFAULT now() + INTERVAL '1 hour',
    created_at TIMESTAMPTZ DEFAULT now()
);
```

### 4.2 **Rate Limiting Function**

A function that checks if a user has exceeded their rate limit.

```sql
CREATE OR REPLACE FUNCTION check_rate_limit(user_id UUID) 
RETURNS BOOLEAN
LANGUAGE plpgsql
AS $$
DECLARE
    limit_exceeded BOOLEAN := FALSE;
BEGIN
    -- Check if the user has an active rate limit period
    IF EXISTS (
        SELECT 1 FROM rate_limits 
        WHERE user_id = user_id AND period_end > now() AND request_count >= 100
    ) THEN
        limit_exceeded := TRUE;
    ELSE
        -- Increment the request count or reset if the period ended
        UPDATE rate_limits
        SET request_count = request_count + 1
        WHERE user_id = user_id AND period_end > now();

        IF NOT FOUND THEN
            -- Start a new rate limit period if none exists
            INSERT INTO rate_limits (user_id, request_count, period_start, period_end)
            VALUES (user_id, 1, now(), now() + INTERVAL '1 hour');
        END IF;
    END IF;

    RETURN limit_exceeded;
END;
$$;
```

---

## **Step 5: Session Tracking Implementation**

### 5.1 **Insert Session on Login**

Insert a new session into the `sessions` table upon successful login.

```sql
INSERT INTO sessions (user_id, product_id, hwid, ip_address, session_token)
VALUES (<user_id>, <product_id>, <hwid>, <ip_address>, <session_token>);
```

---

## **Step 6: Blocking Users and Automated Processes**

### 6.1 **Blocking a User Automatically Based on Conditions**

You can create a trigger or a stored procedure that will block a user if suspicious activity (like HWID mismatch or too many failed logins) is detected.

```sql
CREATE OR REPLACE FUNCTION block_user(user_id UUID)
RETURNS VOID


LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE users
    SET is_blocked = TRUE
    WHERE id = user_id;
END;
$$;
```

This function can be triggered when certain conditions are met, such as rate limit violations or HWID mismatches.

---

## **Step 7: Final Considerations**

### **Enable Row-Level Security (RLS)**
- Ensure that RLS is enabled for `users`, `licenses`, `sessions`, and `hwid_history` tables to secure user data.

### **Backup and Monitoring**
- Supabase automatically backs up your database, but make sure to verify the backup schedule.
- Use Supabase's built-in monitoring to track API usage and potential errors.
