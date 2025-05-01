# 🧦 SockLock

**SockLock** is a lightweight, login-based proxy gateway that enables dynamic SOCKS5 or HTTP proxy access over a single port — with per-user routing and persistent IP assignment.

> One Port. One Login. One Locked Route.

---

## 🚀 Features

- 🔐 Login-based IP binding (1 user = 1 proxy)
- 🔄 Sticky IPs — working proxies stay locked to users
- 🧩 Single-port, multi-user access (SOCKS5 or HTTP)
- 🔁 Config reloads without downtime
- 🌐 Automatic proxy sourcing from external API
- 📦 Dockerized for easy deployment
- 📜 Outputs ready-to-use `proxies.txt`

---

## ⚙️ Environment Variables

| Variable      | Description                                  | Example                |
|---------------|----------------------------------------------|------------------------|
| `PORT`        | Gateway port                                 | `6000`                 |
| `CLIENT_PASS` | Password for all users                       | `pass`                 |
| `REMOTE_USER` | Parent proxy username                        | `username`             |
| `REMOTE_PASS` | Parent proxy password                        | `pass`                 |
| `REMOTE_PORT` | Parent proxy port                            | `3715`                 |
| `API_URL`     | Endpoint for proxy pool                      | `https://your.api.url` |
| `PROXY_MODE`  | `socks5` or `http`                           | `socks5`               |

---

## 🐳 Docker Compose Example

```yaml
version: '3.8'

services:
  socklock:
    container_name: socklock
    build: .
    image: socklock:latest
    ports:
      - "6000:6000"
    environment:
      PORT: 6000
      CLIENT_PASS: pass
      REMOTE_USER: username
      REMOTE_PASS: pass
      REMOTE_PORT: 3715
      API_URL: https://your.api.url
      PROXY_MODE: socks5
    volumes:
      - ./configs:/configs
    restart: unless-stopped
```

---

## 📂 Output Files

| File                   | Description                                    |
|------------------------|------------------------------------------------|
| `configs/3proxy.cfg`   | Main 3proxy configuration                      |
| `configs/proxies.txt`  | Login-based proxy list for clients             |
| `configs/user-map.txt` | User → proxy-IP mapping (persistent across updates) |

---

## 🧪 Sample Output

```
socks5://user1234:pass@your.server.ip:6000
socks5://user5678:pass@your.server.ip:6000
...
```

---

## 🔄 How It Works

1. Proxies are fetched from your API endpoint.
2. Each login (`userXXXX`) is mapped to one parent proxy.
3. Configuration is generated dynamically and reloaded without downtime.
4. On update:
   - Working proxies are preserved
   - Dead ones are replaced

---

## 🧠 Why "SockLock"?

> Because we lock each login to its own upstream SOCKS5 proxy — securely routed over one port.

---

## 🛠 Built With

- [3proxy](https://3proxy.ru/)
- Bash, curl, jq
- Docker & Docker Compose

---

## 📎 License

MIT — free for personal and commercial use.
