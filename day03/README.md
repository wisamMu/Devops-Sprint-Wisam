# Day 3 — Networking Essentials and an AWS VPC Built by Hand

**Goal:** understand how traffic finds its way (IP, CIDR, ports, DNS, HTTP/TLS), how to troubleshoot it layer by layer, and how AWS networking works (VPC, subnets, route tables, internet gateway, NAT, security groups, NACLs). Then **build a VPC by hand**, serve nginx from a public subnet, and explain why the private subnet has no internet.

**Cost rules for this day (AWS Free plan):** VPC, subnets, internet gateway, route tables and security groups are free. One `t3.micro` and its public IPv4 ($0.005/hour) are paid from Free-plan credits and deleted the same day. **No NAT gateway** (about $32/month): it is drawn, not built. No Elastic IP, no load balancer.

| Part | Content |
|---|---|
| 📖 Cheat sheet | The numbers and rules you need at a glance |
| Sections 1–7 | Concepts: IP/CIDR, ports, DNS, HTTP/TLS, troubleshooting, VPC, security groups vs NACLs |
| 🧪 Lab | Build the VPC with the AWS CLI, Parts 1–7 |
| Why private has no internet | The explanation, and the NAT path drawn instead of paid for |
| Lessons | What to remember |

---

## 📖 Networking cheat sheet

### CIDR sizes
| Prefix | Addresses | Usable in an AWS subnet | Typical use |
|---|---|---|---|
| `/32` | 1 | — | One exact host (a security group source such as your laptop) |
| `/28` | 16 | 11 | Smallest AWS subnet |
| `/24` | 256 | 251 | A normal subnet |
| `/16` | 65,536 | — | A whole VPC (the largest AWS allows) |
| `/0` | everything | — | "Anywhere" (`0.0.0.0/0`) |

**Formula:** addresses = 2^(32 − prefix). **AWS reserves 5 per subnet:** network (`.0`), router (`.1`), DNS (`.2`), future use (`.3`), broadcast (last).

### Private ranges (RFC 1918)
| Range | Size |
|---|---|
| `10.0.0.0/8` | 16.7 million |
| `172.16.0.0/12` | 1 million |
| `192.168.0.0/16` | 65,536 |

### Well-known ports
| Port | Service | Port | Service |
|---|---|---|---|
| 22 | SSH | 443 | HTTPS |
| 53 | DNS (UDP and TCP) | 3306 | MySQL |
| 80 | HTTP | 5432 | PostgreSQL |
| 123 | NTP | 1024–65535 | Ephemeral (client side) |

### Failure signatures
| You see | It means | Look at |
|---|---|---|
| `Could not resolve host` | DNS failed | `/etc/resolv.conf`, `dig` |
| **Connection refused** | Reached the machine, **nothing listening** on that port | The service (`ss -tlnp`, `systemctl`) |
| **Timeout** | Packets **silently dropped** | Firewall (SG/NACL) or routing |
| HTTP 4xx | **Client** problem (bad URL, no auth) | The request |
| HTTP 5xx | **Server** problem | The app and its logs |
| 502 / 503 / 504 | Proxy: bad upstream / unavailable / upstream too slow | The backend behind the proxy |
| Certificate error | TLS trust or name mismatch | `openssl s_client` — never `curl -k` |

### AWS VPC in one line each
| Thing | One line |
|---|---|
| VPC | Your private network in one region |
| Subnet | A slice of the VPC in **one AZ** |
| Route table | Where packets go next |
| Public subnet | Its route table has `0.0.0.0/0 → IGW` |
| Internet gateway | The VPC's door to the internet (and the 1:1 public IP translator) |
| NAT gateway | Outbound-only internet for private subnets; lives in a public subnet; costs money |
| Security group | **Stateful**, allow-only firewall on an instance |
| Network ACL | **Stateless**, ordered allow/deny firewall on a subnet |

---

## 1. IP addresses and CIDR

**An IP address** is a 32-bit number that identifies a network interface, written as four bytes: `10.0.1.25`.

**CIDR (Classless Inter-Domain Routing)** describes a **block** of addresses as `address/prefix`. The prefix says how many leading bits are **fixed** (the network part). The rest are free (the host part).

```text
10.0.1.0/24
└──────┘ └┘
 24 fixed bits = network "10.0.1"   8 free bits = 256 hosts (.0 – .255)
```

| Concept | Meaning |
|---|---|
| **Network part** | Identifies the network; identical for every host in the block |
| **Host part** | Identifies one machine inside the block |
| **Smaller prefix = bigger block** | `/16` (65,536) contains 256 `/24`s |
| **Subnetting** | Cutting a big block into smaller non-overlapping blocks: the lab's `/16` VPC is cut into `/24` subnets |
| **Overlap** | Two networks that share addresses cannot be connected (peering/VPN) — plan ranges up front |
| **Private vs public** | RFC 1918 addresses are not routed on the internet; public addresses are globally unique |

### Routing and longest prefix match
**A route** says "to reach this destination block, send the packet to this next hop". When several routes match, the **most specific** (longest prefix) wins.

| Destination | Target | Matches `10.0.11.7`? |
|---|---|---|
| `10.0.0.0/16` | local | ✅ (16 bits) — **wins** |
| `0.0.0.0/0` | internet gateway | ✅ (0 bits) |

So traffic to another instance in the VPC stays inside, and everything else goes to the gateway.

---

## 2. Ports, TCP and UDP

**An IP address finds the machine; a port finds the program** on it. A connection is identified by four values: source IP, source port, destination IP, destination port.

| | **TCP** | **UDP** |
|---|---|---|
| Connection | Yes: 3-way handshake first | No: just send |
| Delivery | Guaranteed, ordered, retransmitted | Best effort |
| Speed | Slower setup | Faster |
| Used by | HTTP(S), SSH, databases | DNS queries, NTP, video, games |

**The 3-way handshake:** `SYN` (client: "let's talk") → `SYN-ACK` (server: "OK") → `ACK` (client: "go"). Only then is data sent.

**Listening:** a server program **binds** to a port and waits. `0.0.0.0:80` means "every interface"; `127.0.0.1:80` means "only this machine" — the classic reason a service works locally but not from outside.

**Ephemeral ports:** the client side of a connection uses a random high port (1024–65535). Replies go **back to that port** — important for stateless firewalls (Section 7).

**Refused vs timeout** is the most useful clue in networking:
| Result | What happened |
|---|---|
| **Refused** | The packet arrived; the OS answered "nobody listens here" (a TCP RST). The network is fine — the **service** is not. |
| **Timeout** | No answer at all. Something **dropped** the packet: a firewall, a missing route, or the host is down. |

---

## 3. DNS

**DNS (Domain Name System)** translates names (`example.com`) into IP addresses. It is a distributed, cached, hierarchical database.

### The resolution chain
```text
App → stub resolver (/etc/hosts, then /etc/resolv.conf)
        → recursive resolver (your ISP, 8.8.8.8, or Amazon DNS at VPC base+2)
            → root servers (.)  → TLD servers (.com)  → authoritative server (example.com)
        ← answer, cached for TTL seconds
```

| Term | Meaning |
|---|---|
| **Recursive resolver** | Does the walking for you and caches answers |
| **Authoritative server** | The source of truth for one domain |
| **TTL** | How long an answer may be cached. Low TTL = fast changes, more queries. |
| **`/etc/hosts`** | Local overrides, checked **before** DNS |
| **`/etc/resolv.conf`** | Which resolver this machine asks |

### Record types
| Type | Points a name to | Example |
|---|---|---|
| **A** | An IPv4 address | `example.com → 93.184.215.14` |
| **AAAA** | An IPv6 address | |
| **CNAME** | Another **name** (an alias) | `www → example.com` |
| **MX** | Mail servers | |
| **TXT** | Free text (domain verification, SPF) | |
| **NS** | The authoritative name servers of a zone | |

**In AWS:** every VPC has a resolver at **base + 2** (`10.0.0.2` for `10.0.0.0/16`). Two VPC attributes control it: **`enableDnsSupport`** (the resolver works) and **`enableDnsHostnames`** (instances get DNS names). The default VPC has both on; a new VPC has hostnames **off** — the lab turns it on.

---

## 4. HTTP and TLS

**HTTP** is a request/response protocol on top of TCP. A request has a **method**, a **path**, **headers** and an optional **body**; the response has a **status code**, headers and a body.

| Method | Meaning | Status family | Meaning |
|---|---|---|---|
| GET | Read | **2xx** | Success (200 OK, 201 Created) |
| POST | Create / submit | **3xx** | Redirect (301 permanent, 302 temporary) |
| PUT / PATCH | Replace / update | **4xx** | **Client** error (400, 401, 403, 404) |
| DELETE | Remove | **5xx** | **Server** error (500, 502, 503, 504) |

**Headers** carry metadata: `Host` (which site — many sites share one IP), `Content-Type`, `Location` (redirect target), `Cache-Control`.

**TLS** (the "S" in HTTPS) gives **encryption** (nobody can read it), **integrity** (nobody can change it) and **authentication** (you talk to the real server).
| Concept | Meaning |
|---|---|
| **Certificate** | The server's public key plus its name, signed by a Certificate Authority |
| **Chain of trust** | Server cert ← intermediate CA ← root CA that your OS already trusts |
| **SNI** | The client says which hostname it wants during the handshake, so one IP can serve many certificates |
| **Common errors** | Expired, wrong hostname, self-signed, untrusted root |
| **Rule** | Fix the certificate; never disable verification (`curl -k`) |

---

## 5. Troubleshooting layer by layer

Work **bottom-up** and stop at the first broken layer:

| # | Question | Tool (local) |
|---|---|---|
| 1 | Does the name resolve? | `dig +short host` |
| 2 | Is there a route / is the host up? | `ping`, `traceroute`, `mtr` |
| 3 | Is the port open? (refused vs timeout) | `nc -zv host port` |
| 4 | Does the service answer correctly? | `curl -v`, `curl -I` |
| 5 | Is the certificate valid? | `openssl s_client -connect host:443 -servername host` |
| 6 | What is on the wire? | `tcpdump` |
| — | What listens on **this** machine? | `ss -tulnp` |

**Mindset:** one change at a time, read the exact error, and use the refused-vs-timeout clue to choose between "service" and "firewall/route".

---

## 6. AWS VPC

**A VPC (Virtual Private Cloud)** is your own isolated network inside one AWS **region**, defined by a CIDR block.

| Concept | Definition |
|---|---|
| **Region / AZ** | A region (`us-east-1`) has several **Availability Zones** — separate data centers. Spreading across AZs survives one failing. |
| **Subnet** | A slice of the VPC's CIDR that lives in **exactly one AZ** |
| **Route table** | Rules that decide where traffic leaving a subnet goes. Every subnet uses exactly one. |
| **`local` route** | Automatic and undeletable: the whole VPC CIDR is reachable from every subnet |
| **Main route table** | Used by any subnet without an explicit association |
| **Internet gateway (IGW)** | Attached to the VPC. Two jobs: (1) a target for internet routes, (2) translate an instance's private IP ↔ its public IP |
| **Public subnet** | A subnet whose route table has `0.0.0.0/0 → IGW`. **Nothing else** makes it public. |
| **Private subnet** | A subnet with no route to the IGW |
| **NAT gateway** | Lets private instances start connections **out** to the internet, never in. Lives in a public subnet. Costs ~$32/month + data. |
| **Public IP vs Elastic IP** | A public IP is temporary (lost on stop). An Elastic IP is a fixed address you own — and charged for. |

### Four things an instance needs to be reached from the internet
| # | Requirement |
|---|---|
| 1 | An **IGW attached** to the VPC |
| 2 | A route **`0.0.0.0/0 → IGW`** in its subnet's route table |
| 3 | A **public IP** on the instance |
| 4 | **Security group and NACL** allow the traffic |

---

## 7. Security groups vs network ACLs

Traffic passes **two firewalls**: the **NACL** at the subnet door, then the **security group** at the instance.

| | **Security group** | **Network ACL** |
|---|---|---|
| Level | Instance (network interface) | Subnet |
| Rules | Allow only | Allow **and deny** |
| State | **Stateful**: replies allowed automatically | **Stateless**: replies need their own rule |
| Evaluation | All rules; any allow wins | By number, lowest first; **first match wins** |
| Default | New SG: inbound none, outbound all | Default NACL: allow all. Custom NACL: deny all. |
| Source can be another SG | ✅ | ❌ CIDR only |
| Use | Everyday control | Coarse guardrails (block a range for a whole subnet) |

**Stateful** = remembers connections, so the reply to an allowed request gets back automatically. **Stateless** = judges every packet alone; with a NACL you must also allow the reply to the client's **ephemeral ports (1024–65535)**, or clients see a timeout.

**Order of checks for inbound traffic:** route → NACL inbound → SG inbound → the app (must listen on `0.0.0.0`) → reply: SG automatic → NACL outbound ephemeral ports.

**Rules of thumb:** least privilege; never open 22/3389 or databases to `0.0.0.0/0`; reference security groups instead of IPs between your own tiers; leave NACLs at default unless you need an explicit deny.


---

> **Lab:** building the VPC, nginx in the public subnet, why private has no internet, and the NAT path are on the **`git-lab`** branch: `day03/lab.md`.
