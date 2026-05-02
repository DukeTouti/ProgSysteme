#!/usr/bin/env bash
set -euo pipefail

echo "Configuring HTTPS on Ubuntu Server..."

# 1. Enable modules and site (The critical FIX)
ip netns exec ubuntu a2enmod ssl > /dev/null
ip netns exec ubuntu a2ensite default-ssl > /dev/null

# 2. Generate the certificate (if not already present)
ip netns exec ubuntu openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/ssl/private/apache-selfsigned.key \
    -out /etc/ssl/certs/apache-selfsigned.crt \
    -subj "/C=MA/ST=Rabat/L=Rabat/O=UIR/OU=Engineering/CN=srv.uir.ma"

# 3. Point to the correct certificates in the config
ip netns exec ubuntu sed -i 's|/etc/ssl/certs/ssl-cert-snakeoil.pem|/etc/ssl/certs/apache-selfsigned.crt|g' /etc/apache2/sites-available/default-ssl.conf
ip netns exec ubuntu sed -i 's|/etc/ssl/private/ssl-cert-snakeoil.key|/etc/ssl/private/apache-selfsigned.key|g' /etc/apache2/sites-available/default-ssl.conf

# 4. Clean restart
ip netns exec ubuntu service apache2 restart

# 5. The HTML (Modern HTML5 Corporate Page)
sudo ip netns exec ubuntu sh -c "cat <<'EOF' > /var/www/html/index.html
<!DOCTYPE html>
<html lang='en'>
<head>
    <meta charset='UTF-8'>
    <title>Al Massar - Career Opportunities</title>
    <style>
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            text-align: center;
            padding: 40px;
            background-color: #eef2f5;
            color: #333;
        }
        .container {
            background: white;
            padding: 40px;
            border-radius: 12px;
            box-shadow: 0 8px 20px rgba(0,0,0,0.1);
            display: inline-block;
            max-width: 650px;
        }
        h1 { color: #003366; font-size: 2.5em; margin-bottom: 10px; }
        h2 { color: #00509e; margin-top: 35px; font-size: 1.5em; border-bottom: 2px solid #00509e; display: inline-block; padding-bottom: 5px; }
        p { line-height: 1.6; font-size: 1.1em; color: #555; }
        .status {
            color: #155724;
            background-color: #d4edda;
            font-weight: bold;
            padding: 10px 20px;
            border: 1px solid #c3e6cb;
            border-radius: 5px;
            display: inline-block;
            margin-bottom: 20px;
        }
        .btn {
            display: inline-block;
            padding: 12px 25px;
            margin: 15px 5px;
            background-color: #003366;
            color: white;
            text-decoration: none;
            border-radius: 6px;
            font-weight: bold;
            transition: background 0.3s;
        }
        .btn:hover { background-color: #00509e; }
        .contact-info {
            background: #f9f9f9;
            padding: 20px;
            border-radius: 8px;
            margin-top: 20px;
            text-align: left;
            border-left: 4px solid #003366;
        }
    </style>
</head>
<body>
    <div class='container'>

        <h1>Welcome to Al Massar</h1>
        <p>Your gateway to the future. Explore endless opportunities, connect with industry leaders, and build the career of your dreams.</p>

        <h2>Discover Our Job Offers</h2>
        <p>We are constantly looking for talented engineers and tech enthusiasts to join our ecosystem. Whether you are into Cloud Infrastructure, Software-Defined Networking, or Systems Engineering, your path starts here.</p>
        <a href='#' class='btn'>Explore Open Positions</a>
        <a href='#' class='btn' style='background-color: #555;'>Submit Resume</a>

        <h2>Contact Us</h2>
        <div class='contact-info'>
            <p><strong>Email:</strong> recruitment@almassar.uir.ma</p>
            <p><strong>Location:</strong> Building 5, UIR Campus, Tech Hub</p>
            <p><strong>Phone:</strong> +212 530 36 00 00</p>
        </div>
    </div>
</body>
</html>
EOF"


echo "HTTPS is ready at https://srv.uir.ma"
