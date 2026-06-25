# RGWchart - Deployment Guide

This guide describes how to build, run, and manage the `RGWchart` (MODFLOW water budget viewer) application using Docker.

---

## 1. Prerequisites
Ensure the target server has the following installed:
* **Docker**
* **Git**
* A firewall utility (like **UFW**) configured

---

## 2. Server Setup (First Time Only)

1. Clone the repository to your server:
   ```bash
   git clone <your-repository-url> ~/apps/RGWchart
   ```
2. Navigate to the project directory:
   ```bash
   cd ~/apps/RGWchart
   ```

---

## 3. Build the Docker Image
Every time you pull updates from the repository, rebuild the Docker image to compile the changes:
```bash
docker build -t rgw_heads_app .
```
*(If you encounter permission issues, prepend the command with `sudo`)*

---

## 4. Run the Container
Start the container with a custom authentication password and port forwarding:

```bash
docker run -d \
  -p 3838:3838 \
  -e RGWCHART_PASSWORD="your_secure_password" \
  --restart unless-stopped \
  --name rgwchart_container \
  rgw_heads_app
```

### Options Breakdown:
* `-d`: Run container in detached mode (background).
* `-p 3838:3838`: Maps port `3838` on the server to port `3838` inside the container.
* `-e RGWCHART_PASSWORD="..."`: Configures the login password for the application. If not provided, it defaults to `"password"`.
* `--restart unless-stopped`: Ensures the container restarts automatically if the server reboots.
* `--name rgwchart_container`: Assigns a readable name to the container.

---

## 5. Configure Firewall (UFW)
To access the application externally, you must allow incoming traffic on port `3838`.

1. Allow the port:
   ```bash
   sudo ufw allow 3838/tcp
   ```
2. Reload/verify the firewall status:
   ```bash
   sudo ufw status
   ```

---

## 6. Accessing the Application
Open a web browser and go to:
```text
http://<your-server-ip-or-domain>:3838
```

* **Username:** `viewer`
* **Password:** The password configured via the `RGWCHART_PASSWORD` environment variable.

---

## 7. Container Administration & Troubleshooting

### Check Container Status
Verify that the container is active and healthy:
```bash
docker ps
```

### View Application Logs
Check runtime outputs or debug crashes:
```bash
docker logs rgwchart_container
```

### Stop/Start the App
* **Stop:**
  ```bash
  docker stop rgwchart_container
  ```
* **Start:**
  ```bash
  docker start rgwchart_container
  ```

### Recreate / Update the Password
If you need to change your password or update the container:
```bash
docker rm -f rgwchart_container
docker run -d -p 3838:3838 -e RGWCHART_PASSWORD="your_new_password" --restart unless-stopped --name rgwchart_container rgw_heads_app
```
