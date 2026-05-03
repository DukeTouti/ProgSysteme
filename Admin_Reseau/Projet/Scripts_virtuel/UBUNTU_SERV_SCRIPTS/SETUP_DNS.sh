#!/usr/bin/env bash
set -euo pipefail

# 1. Configure listen options
sudo ip netns exec ubuntu sh -c 'cat <<EOF > /etc/bind/named.conf.options
options {
    directory "/var/cache/bind";
    recursion yes;
    allow-query { any; };
    listen-on { any; };
    dnssec-validation auto;
};
EOF'

# 2. Configure the zone
cat <<'EOF' | ip netns exec ubuntu tee /etc/bind/named.conf.local > /dev/null
zone "uir.ma" { type master; file "/etc/bind/db.uir.ma"; };
EOF

# 3. Create the zone file (Note: No \ before $ here because we use 'EOF')
cat <<'EOF' | ip netns exec ubuntu tee /etc/bind/db.uir.ma > /dev/null
$TTL 604800
@ IN SOA srv.uir.ma. admin.uir.ma. ( 2 604800 86400 2419200 604800 )
@ IN NS srv.uir.ma.
@ IN A 172.17.4.10
srv IN A 172.17.4.10
www IN A 172.17.4.10
EOF

# 4. FIX: Force IPv4
# Give everything to bind to avoid read issues inside the namespace
sudo ip netns exec ubuntu chown -R bind:bind /etc/bind
sudo ip netns exec ubuntu chmod -R 755 /etc/bind

sudo ip netns exec ubuntu sh -c 'echo "OPTIONS=\"-u bind -4\"" > /etc/default/bind9'
# 5. Permissions and restart
ip netns exec ubuntu service bind9 restart

