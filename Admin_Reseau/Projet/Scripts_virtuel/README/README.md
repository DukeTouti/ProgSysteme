This project automates the deployment of a complete network infrastructure using only **Linux Network Namespaces** (using only Linux Network Namespaces, no heavy virtual machines, just native Linux power).

Check the associated PDF documentation for extra details.

---

## Global Architecture (Abstraction)

The lab simulates an enterprise network segmented into VLANs:
* **Layer 2:** Linux bridges (`br-sw1`, `br-sw2`) handling VLAN tags (802.1Q).
* **Layer 3:** Inter-VLAN routing via a central router.
* **Edge:** A border router with **NAT** for real Internet access.
* **Services:** A virtualized Ubuntu server providing DHCP Relay, DNS (BIND9), Web (HTTPS/Apache), and FTPS.

---

## Project Structure

* `BOOT.sh` : **Main orchestrator.** (Run first).
* `CONF_WINDOW.sh` : Security interface (style) for validation.
* `CLEANUP.sh` : Cleanup script to properly reset the lab.
* `UBUNTU_SERV_SCRIPTS/` : Contains all service logic (DNS, HTTPS, FTP, DHCP).
* `TESTS/` : Automated verification scripts.
* `PCs.sh` & `UBUNTU_SERVER.sh` : End-hosts configuration.

---

## Installation & Execution

### 1. Requirements (will be installed automatically if not present)
Linux system (Compatible with usual Linux **packet managers**) : `apache2` `dnsmasq` `bridge-utils` `vlan` `iptables` `whiptail` `curl`

### 2. Launch
Simply run the orchestrator script as root:

```bash
sudo ./BOOT.sh
```

## Testing
Simply run the test script located in **TESTS** (**/TESTS/ALL_TEST.sh**) as root:

```bash
sudo /TESTS/ALL_TEST.sh
```

### Test Suite — `ALL_TESTS.sh`

The script runs the following tests sequentially from the `pc-vlan10` namespace:

- **[1] DHCP Reset** — Releases the current lease on `veth-pc10` (`dhclient -r`) and flushes residual addresses/routes (`ip addr flush`).
- **[1.1] DHCP DORA** — Triggers a full Discover → Offer → Request → Acknowledge cycle via `dhclient -v` to obtain a fresh IP lease.
- **[2.1] Inter-VLAN Routing** — Pings `172.17.3.10` (VLAN 30 host) from `pc-vlan10` to verify Layer 3 inter-VLAN routing.
- **[2.2] WAN Egress / NAT** — Pings `8.8.8.8` (Google Public DNS) to validate NAT and Internet reachability.
- **[3.1] DNS Resolution** — Runs `nslookup uir.ma` to verify that the BIND9 resolver correctly resolves domain names.
- **[3.2] DNS Resource Records** — Runs `dig uir.ma` for an in-depth inspection of returned DNS records (A, NS, TTL…).
- **[3.3] HTTPS Web Server** — Uses `curl -k https://uir.ma` to confirm that Apache responds over HTTPS (TLS, self-signed cert accepted).
- **[3.4] Visual Web Validation** — Opens `https://uir.ma` in the `links` TUI browser for a visual confirmation of page rendering.
- **[3.5] Explicit FTPS (TLS)** — Connects via `lftp` with `ftp:ssl-force true` to verify authenticated file transfer over explicit TLS.

## FTPS & Network Troubleshooting (Deep Dive)

> **Note:** These issues are usually **not** caused by the scripts themselves, but by resource conflicts between the **Host Kernel** and the **Network Namespaces**, or due to the strict nature of the FTP protocol over TLS.

### 1. FTPS Passive Mode & SSL Issues
FTP over TLS (FTPS) is notoriously difficult to route because it uses a secondary dynamic port range for data transfer.
* **Symptoms:** Connection established and logged in, but hangs on `ls` or `put/get`.
* **The Fix:** Ensure the client forces **Passive Mode**. If the self-signed certificate is rejected during the demo, use:
  `lftp -u user,pass -e "set ftp:passive-mode true; set ssl:verify-certificate no" ftps://uir.ma`

### 2. Port Conflicts (Host vs Namespace)
Since all Namespaces share the same Linux Kernel, a service running on your **Host** (like a local Apache or DNS) might "lock" a port and prevent the Namespace from binding it.
* **The Fix:** Check if a port is busy on the host using `sudo netstat -tulpn | grep :21`. 
* Use `sudo ip netns exec ubuntu fuser -k 21/tcp` to force-kill any process ghosting the FTP port within the namespace before restarting the service.

### 3. ACL & Statefulness
If the **Security Shield (ACL)** is active, it might block the dynamic return traffic of the FTP Data channel. 
* **The Fix:** If FTPS fails specifically when ACLs are ON, verify that the `iptables` rules on `sw-core` include the `ESTABLISHED,RELATED` state tracker:
  `sudo ip netns exec sw-core iptables -A FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT`

### 4. DNS Persistence
Sometimes the host's `systemd-resolved` or local cache interferes with the Namespace resolution.
* **The Fix:** Always verify the client's configuration with `ip netns exec pc-vlan10 cat /etc/resolv.conf`. It must point strictly to the Ubuntu Server IP (`172.17.4.10`).
