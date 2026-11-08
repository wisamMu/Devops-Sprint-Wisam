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

# 🧪 Lab — Build a VPC by hand and serve nginx

**Time:** about 2 hours. **Where:** WSL terminal with the AWS CLI (`aws login`). Watch it appear in **VPC console → Your VPCs → (sprint-vpc) → Resource map**.

### The target network
```text
                         Internet
                            │
                  ┌─────────┴─────────┐
                  │ Internet gateway  │  sprint-igw
                  └─────────┬─────────┘
┌───────────────────────────┼──────────── VPC sprint-vpc 10.0.0.0/16 ─────────────┐
│         us-east-1a        │                          us-east-1b                  │
│  ┌──────────────────────────────┐            ┌──────────────────────────────┐    │
│  │ public-a   10.0.1.0/24       │            │ public-b   10.0.2.0/24       │    │
│  │   [ EC2 sprint-web: nginx ]  │            │   (empty, second AZ)         │    │
│  └──────────────────────────────┘            └──────────────────────────────┘    │
│        route table public-rt:  10.0.0.0/16 → local,  0.0.0.0/0 → sprint-igw      │
│                                                                                  │
│  ┌──────────────────────────────┐            ┌──────────────────────────────┐    │
│  │ private-a  10.0.11.0/24      │            │ private-b  10.0.12.0/24      │    │
│  └──────────────────────────────┘            └──────────────────────────────┘    │
│        route table private-rt: 10.0.0.0/16 → local   (nothing else)              │
└──────────────────────────────────────────────────────────────────────────────────┘
```

| Part | What you build | Cost |
|---|---|---|
| 1 | Prep: identity, variables file, default VPC DNS check | Free |
| 2 | VPC and 4 subnets | Free |
| 3 | Internet gateway and route tables | Free |
| 4 | Security group (port 80 from your IP only) | Free |
| 5 | `t3.micro` with nginx in public-a | Credits |
| 6 | Prove it, and break/fix the route | Free |
| 7 | Teardown in reverse order | — |

---

## Part 1 — Prep

### 1.1 Identity and region
```bash
aws sts get-caller-identity --query Arn --output text
export AWS_REGION=us-east-1
```
| Part | Meaning |
|---|---|
| `aws sts get-caller-identity` | "Who am I?" Fails if the login expired — then run `aws login` |
| `--query Arn --output text` | Print only the ARN, as plain text |
| `export AWS_REGION=us-east-1` | Every later `aws` command in this shell uses `us-east-1` |

### 1.2 The variables file
Every resource ID (`vpc-…`, `subnet-…`) is needed later, including at teardown. This file keeps them, so a new terminal doesn't lose them. It lives in your home folder, **not** in the repo.
```bash
cat > ~/day03-lab.env <<'EOF'
export AWS_REGION=us-east-1
save() { export "$1=$2"; echo "export $1=$2" >> ~/day03-lab.env; echo "saved $1=$2"; }
tags() { echo "ResourceType=$1,Tags=[{Key=Name,Value=$2},{Key=Project,Value=devops-sprint}]"; }
EOF
source ~/day03-lab.env
```
| Part | Meaning |
|---|---|
| `cat > file <<'EOF' … EOF` | Heredoc: writes the lines into the file. Quoted `'EOF'` keeps `$1` literal. |
| `save NAME VALUE` | Sets the variable **and** appends `export NAME=VALUE` to the file |
| `tags TYPE NAME` | Prints the tag text every resource gets: `Name` + `Project=devops-sprint` |
| `source ~/day03-lab.env` | Loads the functions and saved IDs into **this** shell |

> New terminal later? Run `source ~/day03-lab.env` and every ID is back.

### 1.3 DNS attributes of the default VPC (read-only)
```bash
DEFAULT_VPC=$(aws ec2 describe-vpcs --filters Name=is-default,Values=true --query 'Vpcs[0].VpcId' --output text)
aws ec2 describe-vpc-attribute --vpc-id "$DEFAULT_VPC" --attribute enableDnsSupport
aws ec2 describe-vpc-attribute --vpc-id "$DEFAULT_VPC" --attribute enableDnsHostnames
```
| Part | Meaning |
|---|---|
| `--filters Name=is-default,Values=true` | Only the default VPC AWS created for the account |
| `'Vpcs[0].VpcId'` | The ID of the first (only) result |
| `enableDnsSupport` | Is the Amazon resolver at base+2 on? |
| `enableDnsHostnames` | Do instances get public DNS names? |

**Expected:** both `"Value": true`.

---

## Part 2 — VPC and 4 subnets

### 2.1 The VPC
```bash
save VPC_ID "$(aws ec2 create-vpc --cidr-block 10.0.0.0/16 \
  --tag-specifications "$(tags vpc sprint-vpc)" \
  --query Vpc.VpcId --output text)"

aws ec2 modify-vpc-attribute --vpc-id "$VPC_ID" --enable-dns-hostnames Value=true
```
| Part | Meaning |
|---|---|
| `create-vpc --cidr-block 10.0.0.0/16` | The private network: 65,536 addresses `10.0.0.0`–`10.0.255.255` |
| `--tag-specifications "$(tags vpc sprint-vpc)"` | Tags it at creation (`Name=sprint-vpc`, `Project=devops-sprint`) |
| `--query Vpc.VpcId --output text` | Prints just the new ID |
| `save VPC_ID "$( … )"` | Stores the ID in `$VPC_ID` and in the env file |
| `--enable-dns-hostnames Value=true` | New VPCs have hostnames off; this turns them on |

### 2.2 The subnets
```bash
save PUB_A "$(aws ec2 create-subnet --vpc-id "$VPC_ID" --cidr-block 10.0.1.0/24 \
  --availability-zone us-east-1a --tag-specifications "$(tags subnet public-a)" \
  --query Subnet.SubnetId --output text)"

save PUB_B "$(aws ec2 create-subnet --vpc-id "$VPC_ID" --cidr-block 10.0.2.0/24 \
  --availability-zone us-east-1b --tag-specifications "$(tags subnet public-b)" \
  --query Subnet.SubnetId --output text)"

save PRIV_A "$(aws ec2 create-subnet --vpc-id "$VPC_ID" --cidr-block 10.0.11.0/24 \
  --availability-zone us-east-1a --tag-specifications "$(tags subnet private-a)" \
  --query Subnet.SubnetId --output text)"

save PRIV_B "$(aws ec2 create-subnet --vpc-id "$VPC_ID" --cidr-block 10.0.12.0/24 \
  --availability-zone us-east-1b --tag-specifications "$(tags subnet private-b)" \
  --query Subnet.SubnetId --output text)"
```
| Part | Meaning |
|---|---|
| `--cidr-block 10.0.1.0/24` | 256 addresses carved out of the VPC's `/16` |
| `--availability-zone us-east-1a` | The data center the subnet lives in; each a/b pair spans two AZs |
| `public-a`, `private-a` … | Only **names** so far. "Public" comes from the route table in Part 3. |
| `10.0.1x` vs `10.0.11.x` | A numbering convention: low numbers public, 11+ private — readable at a glance |

### 2.3 Verify
```bash
aws ec2 describe-subnets --filters Name=vpc-id,Values="$VPC_ID" \
  --query 'Subnets[].[Tags[?Key==`Name`]|[0].Value,CidrBlock,AvailabilityZone,AvailableIpAddressCount]' \
  --output table
```
| Part | Meaning |
|---|---|
| `Name=vpc-id,Values="$VPC_ID"` | Only subnets in this VPC |
| The `Tags[?Key==…]` part | A JMESPath filter: pull the `Name` tag's value out of the tag list |
| `AvailableIpAddressCount` | Free addresses in the subnet |

**Expected:** 4 rows with **251** free IPs each (256 − 5 reserved).

---

## Part 3 — Internet gateway and route tables

### 3.1 Create and attach the internet gateway
```bash
save IGW_ID "$(aws ec2 create-internet-gateway \
  --tag-specifications "$(tags internet-gateway sprint-igw)" \
  --query InternetGateway.InternetGatewayId --output text)"

aws ec2 attach-internet-gateway --internet-gateway-id "$IGW_ID" --vpc-id "$VPC_ID"
```
| Part | Meaning |
|---|---|
| `create-internet-gateway` | Creates the door — not yet connected to anything |
| `attach-internet-gateway` | Connects it to the VPC. One IGW per VPC. Free. |

An attached IGW alone changes nothing: **no subnet uses it until a route points to it.**

### 3.2 The public route table
```bash
save PUB_RT "$(aws ec2 create-route-table --vpc-id "$VPC_ID" \
  --tag-specifications "$(tags route-table public-rt)" \
  --query RouteTable.RouteTableId --output text)"

aws ec2 create-route --route-table-id "$PUB_RT" \
  --destination-cidr-block 0.0.0.0/0 --gateway-id "$IGW_ID"

save PUB_A_ASSOC "$(aws ec2 associate-route-table --route-table-id "$PUB_RT" --subnet-id "$PUB_A" --query AssociationId --output text)"
save PUB_B_ASSOC "$(aws ec2 associate-route-table --route-table-id "$PUB_RT" --subnet-id "$PUB_B" --query AssociationId --output text)"
```
| Part | Meaning |
|---|---|
| `create-route-table` | A new table; it starts with only the `local` route |
| `create-route --destination-cidr-block 0.0.0.0/0 --gateway-id` | "Everything not local → the IGW". **This line makes a subnet public.** Prints `"Return": true`. |
| `associate-route-table` | Makes the subnet use this table. The returned association ID is needed to undo it at teardown. |

### 3.3 The private route table
```bash
save PRIV_RT "$(aws ec2 create-route-table --vpc-id "$VPC_ID" \
  --tag-specifications "$(tags route-table private-rt)" \
  --query RouteTable.RouteTableId --output text)"

save PRIV_A_ASSOC "$(aws ec2 associate-route-table --route-table-id "$PRIV_RT" --subnet-id "$PRIV_A" --query AssociationId --output text)"
save PRIV_B_ASSOC "$(aws ec2 associate-route-table --route-table-id "$PRIV_RT" --subnet-id "$PRIV_B" --query AssociationId --output text)"
```
| Part | Meaning |
|---|---|
| A table with **no** extra route | Only `10.0.0.0/16 → local`. That is what keeps these subnets private. |
| Why not just use the main table? | The main table is the silent default for every *new* subnet. Leaving it untouched and associating explicitly makes the design visible and safe: nobody makes a subnet public by accident. |

### 3.4 Give public subnets public IPs automatically
```bash
aws ec2 modify-subnet-attribute --subnet-id "$PUB_A" --map-public-ip-on-launch
aws ec2 modify-subnet-attribute --subnet-id "$PUB_B" --map-public-ip-on-launch
```
| Part | Meaning |
|---|---|
| `--map-public-ip-on-launch` | Instances launched here get a temporary public IPv4 (requirement 3 of 4). Billed at $0.005/hour from credits while the instance runs. |

### 3.5 Verify the routes
```bash
aws ec2 describe-route-tables --route-table-ids "$PUB_RT" "$PRIV_RT" \
  --query 'RouteTables[].{name: Tags[?Key==`Name`]|[0].Value, routes: Routes[].[DestinationCidrBlock, GatewayId]}'
```
**Expected:**
```text
public-rt  : 10.0.0.0/16 → local,  0.0.0.0/0 → igw-…
private-rt : 10.0.0.0/16 → local
```

---

## Part 4 — Security group

```bash
save MY_IP "$(curl -s https://checkip.amazonaws.com)"

save SG_ID "$(aws ec2 create-security-group --group-name web-sg \
  --description "HTTP from my IP only" --vpc-id "$VPC_ID" \
  --tag-specifications "$(tags security-group web-sg)" \
  --query GroupId --output text)"

aws ec2 authorize-security-group-ingress --group-id "$SG_ID" \
  --ip-permissions "IpProtocol=tcp,FromPort=80,ToPort=80,IpRanges=[{CidrIp=${MY_IP}/32,Description=my-laptop}]"
```
| Part | Meaning |
|---|---|
| `curl -s https://checkip.amazonaws.com` | Your public IP as the internet sees it (WSL leaves through the same Windows connection) |
| `create-security-group` | A new SG in **this VPC**: inbound nothing, outbound everything |
| `IpProtocol=tcp,FromPort=80,ToPort=80` | Only HTTP |
| `CidrIp=${MY_IP}/32` | Only **your** address — least privilege instead of `0.0.0.0/0` |
| No port 22 rule | No SSH at all. Nothing else is reachable. |

> On a VPN or a changing home IP, the browser may time out later. Re-run the `curl` and add the new IP.

---

## Part 5 — The nginx instance

### 5.1 The user-data script (`day03/userdata.sh` in the repo)
User data is a script EC2 runs **once, as root, on first boot**.
```bash
#!/bin/bash
set -euxo pipefail

# 1 GB swap first: a t3.micro (1 GB RAM) can freeze while dnf runs (lesson from Day 1)
fallocate -l 1G /swapfile
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
echo '/swapfile none swap defaults 0 0' >> /etc/fstab

# Install and start nginx
dnf install -y nginx
cat > /usr/share/nginx/html/index.html <<EOF
<h1>Day 3 VPC lab</h1>
<p>Served by nginx on $(hostname) in subnet public-a (10.0.1.0/24).</p>
EOF
systemctl enable --now nginx
```
| Line | Meaning |
|---|---|
| `set -euxo pipefail` | Day 2 strict mode, plus `-x` to print every command into `/var/log/cloud-init-output.log` |
| `fallocate` … `swapon` | Create, protect, format and enable a 1 GB swap file |
| `>> /etc/fstab` | Keep the swap after a reboot |
| `dnf install -y nginx` | Install nginx without prompting |
| `<<EOF` (unquoted) | Here `$(hostname)` **does** expand, on the instance at boot |
| `systemctl enable --now nginx` | Start now and on every boot |

### 5.2 Launch
```bash
cd ~/Devops-Sprint-Wisam/day03

save AMI_ID "$(aws ssm get-parameter \
  --name /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64 \
  --query Parameter.Value --output text)"

save INSTANCE_ID "$(aws ec2 run-instances --image-id "$AMI_ID" \
  --instance-type t3.micro --subnet-id "$PUB_A" --security-group-ids "$SG_ID" \
  --user-data file://userdata.sh \
  --metadata-options HttpTokens=required,HttpEndpoint=enabled \
  --credit-specification CpuCredits=standard \
  --tag-specifications "$(tags instance sprint-web)" "$(tags volume sprint-web)" \
  --query 'Instances[0].InstanceId' --output text)"

aws ec2 wait instance-running --instance-ids "$INSTANCE_ID"

save PUBLIC_IP "$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" \
  --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)"
```
| Part | Meaning |
|---|---|
| `aws ssm get-parameter --name /aws/service/ami-…` | AWS publishes the latest Amazon Linux 2023 AMI ID here — no hard-coded IDs |
| `--instance-type t3.micro` | The only type allowed in the sprint |
| `--subnet-id "$PUB_A"` | Launch into the **public** subnet |
| `--security-group-ids "$SG_ID"` | Attach `web-sg` |
| `--user-data file://userdata.sh` | Send the script; the CLI base64-encodes it |
| `HttpTokens=required` | **IMDSv2 only** (Day 1) |
| `CpuCredits=standard` | T3 defaults to *unlimited*, which can bill extra CPU. *Standard* just slows down instead — no surprise charges. |
| Two `tags …` | Tag both the instance and its disk |
| No `--key-name` | No SSH key: nothing to leak, port 22 is closed anyway |
| `wait instance-running` | Blocks until the state is `running` |
| `PublicIpAddress` | The address the IGW maps to the instance's private IP |

---

## Part 6 — Prove it

### 6.1 Reach nginx
Wait **2–3 minutes** for user data to finish, then:
```bash
curl -s -m 5 "http://$PUBLIC_IP"
curl -sI -m 5 "http://$PUBLIC_IP" | head -n 3
```
| Part | Meaning |
|---|---|
| `-s -m 5` | Silent, give up after 5 seconds |
| `-I` | Headers only: expect `HTTP/1.1 200 OK` and `Server: nginx` |

Also open `http://<public-ip>` in your browser. (`http`, not `https` — there is no certificate.)

**If it fails, use Section 5:** *refused* → nginx not running yet (user data still working); *timeout* → SG (your IP changed?) or route.

### 6.2 Prove the security group works
```bash
nc -zv -w 5 "$PUBLIC_IP" 22
```
**Expected:** a **timeout**, not "refused" — the SG drops it silently before it reaches the instance.

### 6.3 Break and fix the route (a mini drill)
```bash
aws ec2 delete-route --route-table-id "$PUB_RT" --destination-cidr-block 0.0.0.0/0
curl -s -m 5 "http://$PUBLIC_IP" || echo "timeout: no route to the IGW"

aws ec2 create-route --route-table-id "$PUB_RT" --destination-cidr-block 0.0.0.0/0 --gateway-id "$IGW_ID"
curl -s -m 5 "http://$PUBLIC_IP"
```
**Lesson:** the instance, its public IP, the IGW and the SG were all unchanged. Removing **one route** turned public-a into a private subnet — exactly the definition in Section 6.

### 6.4 Show the evidence for the private subnets
```bash
aws ec2 describe-route-tables --route-table-ids "$PRIV_RT" \
  --query 'RouteTables[0].Routes[].[DestinationCidrBlock,GatewayId]' --output table
```
**Expected:** a single row, `10.0.0.0/16 | local`.

---

## Why the private subnets have no internet

Check the four requirements against `private-a` / `private-b`:

| # | Requirement | Private subnet |
|---|---|---|
| 1 | IGW attached to the VPC | ✅ The VPC has one |
| 2 | Route `0.0.0.0/0 → IGW` | ❌ **`private-rt` has only `local`** |
| 3 | Public IP on the instance | ❌ `map-public-ip-on-launch` is off |
| 4 | SG/NACL allow it | (irrelevant — the packet has nowhere to go) |

A packet to `8.8.8.8` from `10.0.11.7` looks up `private-rt`; the only route is `10.0.0.0/16`, which doesn't match, so **there is no next hop and the packet is dropped**. Traffic **inside** the VPC still works through `local` (if SGs allow).

**This is the point:** databases and internal services sit there with **no path from the internet at all**, even if someone opens a security group by mistake (defence in depth).

### The NAT path — drawn, not paid for
Sometimes private instances must reach **out** (OS updates, calling an API) while staying unreachable from outside. That is the job of a **NAT gateway**.

```text
                                   Internet
                                      ▲  │ replies only
                                      │  ▼
                            ┌──────────────────┐
                            │ Internet gateway │
                            └──────────────────┘
                                      ▲  │
            public-rt: 0.0.0.0/0 → IGW │  │
┌─────────────────── public-a 10.0.1.0/24 ──────────────────┐
│   ┌──────────────────────────────┐                         │
│   │ NAT gateway  + Elastic IP    │  rewrites the source:    │
│   │ (would cost ~$32/month)      │  10.0.11.7 → Elastic IP  │
│   └──────────────────────────────┘                         │
└────────────────────────────▲───────────────────────────────┘
                             │  │
 private-rt: 0.0.0.0/0 → NAT │  │  replies mapped back to 10.0.11.7
┌──────────────────── private-a 10.0.11.0/24 ───────────────┐
│   [ EC2 10.0.11.7 ]  starts:  dnf update → internet       │
└───────────────────────────────────────────────────────────┘

   Connections started FROM the internet → no mapping on the NAT → dropped.
```

| Step | What happens |
|---|---|
| 1 | Private instance sends to the internet; `private-rt` would say `0.0.0.0/0 → nat-…` |
| 2 | The NAT gateway (in a **public** subnet) replaces the source IP with its **Elastic IP** and remembers the mapping |
| 3 | `public-rt` sends it to the IGW and out |
| 4 | The reply returns to the Elastic IP; the NAT looks up its mapping and forwards it to `10.0.11.7` |
| 5 | A new connection **from** the internet has no mapping → dropped. **Outbound only.** |

**What it would take (not built):** an Elastic IP, `create-nat-gateway` in `public-a`, and one route in `private-rt` (`0.0.0.0/0 → nat-…`). For high availability, one NAT per AZ.

**Why we don't build it:**
| Item | Price (us-east-1) |
|---|---|
| NAT gateway | ~$0.045/hour ≈ **$32/month**, even idle |
| Data processed | ~$0.045 per GB |
| Elastic IP | $0.005/hour |

**Free alternatives later in the sprint:** a **gateway VPC endpoint** for S3 or DynamoDB is free and lets private instances reach those services without NAT. Interface endpoints (for SSM, ECR…) cost money per hour.

---

## Part 7 — Teardown (same day)

Delete in **reverse** order — a resource can't be deleted while something still depends on it.
```bash
source ~/day03-lab.env

aws ec2 terminate-instances --instance-ids "$INSTANCE_ID" \
  --query 'TerminatingInstances[0].CurrentState.Name' --output text
aws ec2 wait instance-terminated --instance-ids "$INSTANCE_ID"

aws ec2 delete-security-group --group-id "$SG_ID"

for a in "$PUB_A_ASSOC" "$PUB_B_ASSOC" "$PRIV_A_ASSOC" "$PRIV_B_ASSOC"; do
  aws ec2 disassociate-route-table --association-id "$a"
done
aws ec2 delete-route-table --route-table-id "$PUB_RT"
aws ec2 delete-route-table --route-table-id "$PRIV_RT"

aws ec2 detach-internet-gateway --internet-gateway-id "$IGW_ID" --vpc-id "$VPC_ID"
aws ec2 delete-internet-gateway --internet-gateway-id "$IGW_ID"

for s in "$PUB_A" "$PUB_B" "$PRIV_A" "$PRIV_B"; do
  aws ec2 delete-subnet --subnet-id "$s"
done

aws ec2 delete-vpc --vpc-id "$VPC_ID"
```
| Step | Why this order |
|---|---|
| Terminate + **wait** | The instance's network interface blocks the SG and subnet deletes; the public IP stops billing |
| Delete SG | No instance uses it any more |
| Disassociate, then delete route tables | A table in use can't be deleted |
| Detach, then delete the IGW | An attached IGW can't be deleted |
| Delete subnets, then the VPC | A VPC with subnets can't be deleted |

### Verify nothing is left
```bash
aws ec2 describe-vpcs --filters Name=tag:Project,Values=devops-sprint --query 'Vpcs[].VpcId'
aws ec2 describe-instances --filters Name=tag:Project,Values=devops-sprint \
  Name=instance-state-name,Values=pending,running,stopping,stopped \
  --query 'Reservations[].Instances[].InstanceId'
rm ~/day03-lab.env
```
**Expected:** `[]` and `[]`. Then delete the env file — its IDs point to nothing now.

---

## Lessons

| # | Lesson |
|---|---|
| 1 | **A subnet is public only because of its route table.** Delete `0.0.0.0/0 → IGW` and a "public" subnet becomes private. |
| 2 | Reaching an instance needs **all four**: IGW attached, route, public IP, SG/NACL. |
| 3 | **Timeout = something dropped it** (SG, NACL, route). **Refused = reached the host, nothing listening.** |
| 4 | Security groups are stateful and allow-only; least privilege means **your IP `/32`**, no port 22. |
| 5 | Private subnets are protected by **the absence of a route**, not just by a firewall rule. |
| 6 | NAT gives private subnets **outbound-only** internet and costs ~$32/month — understand it, draw it, don't leave one running. |
| 7 | Save every resource ID while building; teardown runs in **reverse order** of dependencies. |
| 8 | `CpuCredits=standard` and same-day teardown keep a Free-plan account at **$0 out of pocket**. |

## Files in this folder
| File | Purpose |
|---|---|
| `README.md` | These notes |
| `userdata.sh` | The first-boot script: swap + nginx |
