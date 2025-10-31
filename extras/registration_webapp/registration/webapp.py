#!/usr/bin/env python3
"""
Self-Service User Registration Web Application
High School Esports LAN Infrastructure

Simple web interface for players to create their own accounts

Can run on:
- Dedicated laptop (wireless)
- Any tournament machine
- Registration kiosk

Usage:
    python3 webapp.py
    Access at: http://laptop-ip:5000
"""

from flask import Flask, render_template_string, request, redirect, flash, session
import subprocess
import re
import secrets
import yaml
from pathlib import Path

app = Flask(__name__)
app.secret_key = secrets.token_hex(16)

# Configuration
CONFIG_FILE = Path(__file__).parent.parent / "config.yaml"
FILE_SERVER_IP = "192.168.1.12"

# Load config
try:
    with open(CONFIG_FILE) as f:
        config = yaml.safe_load(f)
        FILE_SERVER_IP = config['network']['file_server_ip']
        ORG_NAME = config['organization']['name']
except:
    ORG_NAME = "Esports Tournament"

# HTML Templates
MAIN_TEMPLATE = """
<!DOCTYPE html>
<html>
<head>
    <title>Player Registration - {{ org_name }}</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 20px;
        }
        .container {
            background: white;
            border-radius: 20px;
            padding: 40px;
            max-width: 500px;
            width: 100%;
            box-shadow: 0 20px 60px rgba(0,0,0,0.3);
        }
        h1 {
            color: #667eea;
            margin-bottom: 10px;
            text-align: center;
        }
        .subtitle {
            text-align: center;
            color: #666;
            margin-bottom: 30px;
        }
        .form-group {
            margin-bottom: 20px;
        }
        label {
            display: block;
            margin-bottom: 5px;
            color: #333;
            font-weight: 600;
        }
        input, select {
            width: 100%;
            padding: 12px;
            border: 2px solid #ddd;
            border-radius: 8px;
            font-size: 16px;
            transition: border-color 0.3s;
        }
        input:focus, select:focus {
            outline: none;
            border-color: #667eea;
        }
        .btn {
            width: 100%;
            padding: 15px;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            border: none;
            border-radius: 8px;
            font-size: 18px;
            font-weight: 600;
            cursor: pointer;
            transition: transform 0.2s;
        }
        .btn:hover {
            transform: translateY(-2px);
        }
        .btn:active {
            transform: translateY(0);
        }
        .alert {
            padding: 15px;
            margin-bottom: 20px;
            border-radius: 8px;
            font-weight: 500;
        }
        .alert-success {
            background: #d4edda;
            color: #155724;
            border: 1px solid #c3e6cb;
        }
        .alert-error {
            background: #f8d7da;
            color: #721c24;
            border: 1px solid #f5c6cb;
        }
        .help-text {
            font-size: 14px;
            color: #666;
            margin-top: 5px;
        }
        .rules {
            background: #f8f9fa;
            padding: 15px;
            border-radius: 8px;
            margin-bottom: 20px;
            font-size: 14px;
            color: #666;
        }
        .rules ul {
            margin-left: 20px;
            margin-top: 10px;
        }
        .footer {
            text-align: center;
            margin-top: 30px;
            color: #999;
            font-size: 14px;
        }
        .stats {
            text-align: center;
            margin-top: 20px;
            padding: 15px;
            background: #f8f9fa;
            border-radius: 8px;
        }
        .stats-number {
            font-size: 36px;
            font-weight: 700;
            color: #667eea;
        }
        .stats-label {
            color: #666;
            margin-top: 5px;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>🎮 {{ org_name }}</h1>
        <div class="subtitle">Player Registration</div>
        
        {% with messages = get_flashed_messages(with_categories=true) %}
            {% if messages %}
                {% for category, message in messages %}
                    <div class="alert alert-{{ category }}">{{ message }}</div>
                {% endfor %}
            {% endif %}
        {% endwith %}
        
        <div class="rules">
            <strong>Account Requirements:</strong>
            <ul>
                <li>Username: 3-15 characters, letters and numbers only</li>
                <li>Password: Minimum 8 characters</li>
                <li>Email: Valid email address</li>
            </ul>
        </div>
        
        <form method="POST" action="/register">
            <div class="form-group">
                <label for="username">Username *</label>
                <input type="text" id="username" name="username" 
                       pattern="[a-zA-Z0-9]{3,15}" 
                       required 
                       placeholder="player123">
                <div class="help-text">This will be your login name</div>
            </div>
            
            <div class="form-group">
                <label for="password">Password *</label>
                <input type="password" id="password" name="password" 
                       minlength="8" 
                       required
                       placeholder="Minimum 8 characters">
            </div>
            
            <div class="form-group">
                <label for="confirm_password">Confirm Password *</label>
                <input type="password" id="confirm_password" name="confirm_password" 
                       minlength="8" 
                       required
                       placeholder="Re-enter password">
            </div>
            
            <div class="form-group">
                <label for="email">Email Address *</label>
                <input type="email" id="email" name="email" 
                       required
                       placeholder="player@example.com">
                <div class="help-text">For password recovery only</div>
            </div>
            
            <div class="form-group">
                <label for="team">Team/School (Optional)</label>
                <input type="text" id="team" name="team" 
                       maxlength="50"
                       placeholder="Your school or team name">
            </div>
            
            <button type="submit" class="btn">Create Account</button>
        </form>
        
        <div class="stats">
            <div class="stats-number">{{ registered_count }}</div>
            <div class="stats-label">Players Registered</div>
        </div>
        
        <div class="footer">
            Need help? Contact tournament staff
        </div>
    </div>
</body>
</html>
"""

SUCCESS_TEMPLATE = """
<!DOCTYPE html>
<html>
<head>
    <title>Registration Success</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 20px;
        }
        .container {
            background: white;
            border-radius: 20px;
            padding: 40px;
            max-width: 500px;
            width: 100%;
            box-shadow: 0 20px 60px rgba(0,0,0,0.3);
            text-align: center;
        }
        .success-icon {
            font-size: 80px;
            margin-bottom: 20px;
        }
        h1 {
            color: #28a745;
            margin-bottom: 20px;
        }
        .credentials {
            background: #f8f9fa;
            padding: 20px;
            border-radius: 10px;
            margin: 20px 0;
            text-align: left;
        }
        .credentials strong {
            color: #667eea;
        }
        .instructions {
            background: #fff3cd;
            padding: 15px;
            border-radius: 8px;
            margin: 20px 0;
            font-size: 14px;
            color: #856404;
        }
        .btn {
            display: inline-block;
            padding: 15px 30px;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            border: none;
            border-radius: 8px;
            font-size: 16px;
            font-weight: 600;
            cursor: pointer;
            text-decoration: none;
            margin-top: 20px;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="success-icon">✅</div>
        <h1>Account Created!</h1>
        <p>Welcome to the tournament, <strong>{{ username }}</strong>!</p>
        
        <div class="credentials">
            <p><strong>Username:</strong> {{ username }}</p>
            <p><strong>Email:</strong> {{ email }}</p>
            <p style="margin-top: 10px; font-size: 14px; color: #666;">
                Keep these credentials safe!
            </p>
        </div>
        
        <div class="instructions">
            <strong>Next Steps:</strong>
            <ol style="margin-left: 20px; margin-top: 10px;">
                <li>Find any available gaming PC</li>
                <li>It will boot automatically (wait 5-10 minutes first boot)</li>
                <li>Login with your username and password</li>
                <li>Your settings will be saved automatically</li>
            </ol>
        </div>
        
        <a href="/" class="btn">Register Another Player</a>
    </div>
</body>
</html>
"""

def validate_username(username):
    """Validate username meets requirements."""
    if not username or len(username) < 3 or len(username) > 15:
        return False, "Username must be 3-15 characters"
    
    if not re.match(r'^[a-zA-Z0-9]+$', username):
        return False, "Username can only contain letters and numbers"
    
    return True, ""

def validate_password(password):
    """Validate password meets requirements."""
    if not password or len(password) < 8:
        return False, "Password must be at least 8 characters"
    
    return True, ""

def check_user_exists(username):
    """Check if username already exists on file server."""
    try:
        # SSH to file server and check
        result = subprocess.run(
            ['ssh', f'ansible@{FILE_SERVER_IP}', f'sudo pdbedit -L | grep -q "^{username}:"'],
            capture_output=True,
            timeout=5
        )
        return result.returncode == 0
    except:
        return False

def create_user(username, password, email, team=""):
    """Create user account on file server."""
    try:
        # SSH to file server and run create-user script
        cmd = f'sudo /usr/local/bin/create-user {username} {password}'
        result = subprocess.run(
            ['ssh', f'ansible@{FILE_SERVER_IP}', cmd],
            capture_output=True,
            timeout=10,
            text=True
        )
        
        if result.returncode != 0:
            return False, f"Error creating account: {result.stderr}"
        
        # Store email and team info (optional - could be in a database)
        # For now, just log it
        with open('/var/log/registration.log', 'a') as f:
            f.write(f"{username},{email},{team}\n")
        
        return True, "Account created successfully"
    
    except Exception as e:
        return False, f"Error: {str(e)}"

def get_registered_count():
    """Get count of registered users."""
    try:
        result = subprocess.run(
            ['ssh', f'ansible@{FILE_SERVER_IP}', 'sudo pdbedit -L | wc -l'],
            capture_output=True,
            timeout=5,
            text=True
        )
        return int(result.stdout.strip())
    except:
        return 0

@app.route('/')
def index():
    """Show registration form."""
    registered_count = get_registered_count()
    return render_template_string(
        MAIN_TEMPLATE,
        org_name=ORG_NAME,
        registered_count=registered_count
    )

@app.route('/register', methods=['POST'])
def register():
    """Process registration."""
    username = request.form.get('username', '').lower().strip()
    password = request.form.get('password', '')
    confirm_password = request.form.get('confirm_password', '')
    email = request.form.get('email', '').strip()
    team = request.form.get('team', '').strip()
    
    # Validate username
    valid, msg = validate_username(username)
    if not valid:
        flash(msg, 'error')
        return redirect('/')
    
    # Validate password
    valid, msg = validate_password(password)
    if not valid:
        flash(msg, 'error')
        return redirect('/')
    
    # Check passwords match
    if password != confirm_password:
        flash('Passwords do not match', 'error')
        return redirect('/')
    
    # Check if user already exists
    if check_user_exists(username):
        flash('Username already taken. Please choose another.', 'error')
        return redirect('/')
    
    # Create user
    success, msg = create_user(username, password, email, team)
    
    if not success:
        flash(msg, 'error')
        return redirect('/')
    
    # Success!
    return render_template_string(
        SUCCESS_TEMPLATE,
        username=username,
        email=email
    )

@app.route('/health')
def health():
    """Health check endpoint."""
    return {'status': 'ok', 'registered': get_registered_count()}

if __name__ == '__main__':
    # Run on all interfaces so it's accessible from network
    app.run(host='0.0.0.0', port=5000, debug=False)