#!/usr/bin/env python3
"""
Vulnerable Voting Application
Multiple security vulnerabilities intentionally included for testing
"""

from flask import Flask, render_template_string, request, redirect, url_for, session, jsonify
import mysql.connector
import os
import subprocess
import pickle
import base64
import hashlib
from datetime import datetime

app = Flask(__name__)
app.secret_key = 'insecure_secret_key_12345'  # Vulnerability: Weak secret key

# Vulnerability: Hardcoded database credentials
DB_CONFIG = {
    'host': os.getenv('DB_HOST', 'vulnerable-database.vulnerable-apps.svc.cluster.local'),
    'port': int(os.getenv('DB_PORT', '3306')),
    'user': os.getenv('DB_USER', 'admin'),
    'password': os.getenv('DB_PASSWORD', 'admin123'),
    'database': os.getenv('DB_NAME', 'vulnerable_db')
}

# Vulnerability: Admin credentials hardcoded
ADMIN_USERNAME = 'admin'
ADMIN_PASSWORD = 'admin123'  # Vulnerability: Weak password

# HTML Templates with vulnerabilities
INDEX_TEMPLATE = '''
<!DOCTYPE html>
<html>
<head>
    <title>Voting System</title>
    <style>
        body { font-family: Arial; max-width: 800px; margin: 50px auto; padding: 20px; }
        .vote-section { margin: 30px 0; padding: 20px; border: 1px solid #ddd; }
        .vote-btn { padding: 10px 20px; margin: 10px; font-size: 16px; cursor: pointer; }
        .results { margin-top: 30px; }
        .comment-section { margin-top: 30px; }
        .admin-link { float: right; }
    </style>
</head>
<body>
    <h1>Security Survey</h1>
    <p>Question: Is this system secure?</p>
    
    <div class="vote-section">
        <form method="POST" action="/vote">
            <input type="hidden" name="question_id" value="1">
            <button type="submit" name="vote" value="yes" class="vote-btn">✓ YES</button>
            <button type="submit" name="vote" value="no" class="vote-btn">✗ NO</button>
        </form>
    </div>
    
    <div class="results">
        <h2>Current Results</h2>
        <p>YES: {{ yes_count }}</p>
        <p>NO: {{ no_count }}</p>
        <p>Total Votes: {{ total }}</p>
    </div>
    
    <div class="comment-section">
        <h3>Add Comment</h3>
        <form method="POST" action="/comment">
            <textarea name="comment" rows="4" cols="50" placeholder="Your comment..."></textarea><br>
            <input type="submit" value="Submit Comment">
        </form>
    </div>
    
    <div class="comments">
        <h3>Recent Comments</h3>
        {{ comments|safe }}
    </div>
    
    <div class="admin-link">
        <a href="/admin">Admin Panel</a>
    </div>
    
    <div style="margin-top: 30px;">
        <a href="/api/votes">API Endpoint</a> | 
        <a href="/debug">Debug Info</a>
    </div>
</body>
</html>
'''

ADMIN_TEMPLATE = '''
<!DOCTYPE html>
<html>
<head>
    <title>Admin Panel</title>
    <style>
        body { font-family: Arial; max-width: 1000px; margin: 50px auto; padding: 20px; }
        table { width: 100%; border-collapse: collapse; margin-top: 20px; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
    </style>
</head>
<body>
    <h1>Admin Panel</h1>
    {% if not is_admin %}
    <form method="POST" action="/admin">
        <h2>Login</h2>
        <p>Username: <input type="text" name="username"></p>
        <p>Password: <input type="password" name="password"></p>
        <input type="submit" value="Login">
    </form>
    {% else %}
    <h2>All Votes</h2>
    <table>
        <tr>
            <th>ID</th>
            <th>Vote</th>
            <th>IP Address</th>
            <th>Timestamp</th>
            <th>User Agent</th>
        </tr>
        {% for vote in votes %}
        <tr>
            <td>{{ vote[0] }}</td>
            <td>{{ vote[1] }}</td>
            <td>{{ vote[2] }}</td>
            <td>{{ vote[3] }}</td>
            <td>{{ vote[4] }}</td>
        </tr>
        {% endfor %}
    </table>
    
    <h2>Database Query</h2>
    <form method="POST" action="/admin/query">
        <textarea name="query" rows="5" cols="80" placeholder="SELECT * FROM votes..."></textarea><br>
        <input type="submit" value="Execute Query">
    </form>
    
    <h2>System Info</h2>
    <pre>{{ system_info }}</pre>
    
    <p><a href="/">Back to Voting</a></p>
    {% endif %}
</body>
</html>
'''

def get_db_connection():
    """Get database connection"""
    try:
        conn = mysql.connector.connect(**DB_CONFIG)
        return conn
    except Exception as e:
        print(f"Database connection error: {e}")
        return None

def init_database():
    """Initialize database tables"""
    conn = get_db_connection()
    if not conn:
        return False
    
    cursor = conn.cursor()
    try:
        # Vulnerability: No input validation, potential SQL injection
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS votes (
                id INT AUTO_INCREMENT PRIMARY KEY,
                question_id INT,
                vote VARCHAR(10),
                ip_address VARCHAR(50),
                timestamp DATETIME,
                user_agent TEXT
            )
        ''')
        
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS comments (
                id INT AUTO_INCREMENT PRIMARY KEY,
                comment TEXT,
                ip_address VARCHAR(50),
                timestamp DATETIME
            )
        ''')
        
        conn.commit()
        return True
    except Exception as e:
        print(f"Database init error: {e}")
        return False
    finally:
        cursor.close()
        conn.close()

@app.route('/')
def index():
    """Main voting page"""
    conn = get_db_connection()
    if not conn:
        return "Database connection failed", 500
    
    cursor = conn.cursor()
    
    # Vulnerability: SQL Injection possible
    try:
        cursor.execute("SELECT COUNT(*) FROM votes WHERE vote = 'yes'")
        yes_count = cursor.fetchone()[0]
        
        cursor.execute("SELECT COUNT(*) FROM votes WHERE vote = 'no'")
        no_count = cursor.fetchone()[0]
        
        # Vulnerability: XSS - Comments not sanitized
        cursor.execute("SELECT comment FROM comments ORDER BY timestamp DESC LIMIT 10")
        comments = cursor.fetchall()
        comments_html = "<ul>"
        for comment in comments:
            comments_html += f"<li>{comment[0]}</li>"  # Vulnerability: Direct output without sanitization
        comments_html += "</ul>"
        
    except Exception as e:
        yes_count = 0
        no_count = 0
        comments_html = f"<p>Error: {e}</p>"
    
    cursor.close()
    conn.close()
    
    return render_template_string(INDEX_TEMPLATE, 
                                 yes_count=yes_count, 
                                 no_count=no_count,
                                 total=yes_count + no_count,
                                 comments=comments_html)

@app.route('/vote', methods=['POST'])
def vote():
    """Handle vote submission"""
    # Vulnerability: No CSRF protection
    # Vulnerability: No rate limiting
    question_id = request.form.get('question_id', '1')
    vote_value = request.form.get('vote', '')
    ip_address = request.remote_addr
    user_agent = request.headers.get('User-Agent', '')
    
    conn = get_db_connection()
    if not conn:
        return "Database connection failed", 500
    
    cursor = conn.cursor()
    
    # Vulnerability: SQL Injection - Direct string interpolation
    try:
        query = f"INSERT INTO votes (question_id, vote, ip_address, timestamp, user_agent) VALUES ({question_id}, '{vote_value}', '{ip_address}', NOW(), '{user_agent}')"
        cursor.execute(query)
        conn.commit()
    except Exception as e:
        return f"Error: {e}", 500
    finally:
        cursor.close()
        conn.close()
    
    return redirect(url_for('index'))

@app.route('/comment', methods=['POST'])
def comment():
    """Handle comment submission"""
    # Vulnerability: XSS - No input sanitization
    # Vulnerability: No CSRF protection
    comment_text = request.form.get('comment', '')
    ip_address = request.remote_addr
    
    conn = get_db_connection()
    if not conn:
        return "Database connection failed", 500
    
    cursor = conn.cursor()
    
    # Vulnerability: SQL Injection
    try:
        query = f"INSERT INTO comments (comment, ip_address, timestamp) VALUES ('{comment_text}', '{ip_address}', NOW())"
        cursor.execute(query)
        conn.commit()
    except Exception as e:
        return f"Error: {e}", 500
    finally:
        cursor.close()
        conn.close()
    
    return redirect(url_for('index'))

@app.route('/admin', methods=['GET', 'POST'])
def admin():
    """Admin panel with vulnerabilities"""
    # Vulnerability: Weak authentication
    if request.method == 'POST':
        username = request.form.get('username', '')
        password = request.form.get('password', '')
        
        # Vulnerability: SQL Injection in login
        if username == ADMIN_USERNAME and password == ADMIN_PASSWORD:
            session['is_admin'] = True
            return redirect(url_for('admin'))
    
    is_admin = session.get('is_admin', False)
    
    if not is_admin:
        return render_template_string(ADMIN_TEMPLATE, is_admin=False, votes=[], system_info='')
    
    # Admin view
    conn = get_db_connection()
    if not conn:
        return "Database connection failed", 500
    
    cursor = conn.cursor()
    
    # Vulnerability: SQL Injection possible
    cursor.execute("SELECT id, vote, ip_address, timestamp, user_agent FROM votes ORDER BY timestamp DESC LIMIT 100")
    votes = cursor.fetchall()
    
    # Vulnerability: Command Injection possible
    system_info = ""
    try:
        system_info = subprocess.check_output(['uname', '-a'], shell=False).decode()
        system_info += "\n" + subprocess.check_output(['whoami'], shell=False).decode()
    except:
        pass
    
    cursor.close()
    conn.close()
    
    return render_template_string(ADMIN_TEMPLATE, is_admin=True, votes=votes, system_info=system_info)

@app.route('/admin/query', methods=['POST'])
def admin_query():
    """Execute arbitrary SQL queries - MAJOR VULNERABILITY"""
    if not session.get('is_admin', False):
        return "Unauthorized", 403
    
    query = request.form.get('query', '')
    
    conn = get_db_connection()
    if not conn:
        return "Database connection failed", 500
    
    cursor = conn.cursor()
    
    # Vulnerability: Arbitrary SQL execution
    try:
        cursor.execute(query)
        if query.strip().upper().startswith('SELECT'):
            results = cursor.fetchall()
            return jsonify({"results": results})
        else:
            conn.commit()
            return jsonify({"status": "Query executed"})
    except Exception as e:
        return jsonify({"error": str(e)}), 500
    finally:
        cursor.close()
        conn.close()

@app.route('/api/votes')
def api_votes():
    """API endpoint - Vulnerability: No authentication"""
    conn = get_db_connection()
    if not conn:
        return jsonify({"error": "Database connection failed"}), 500
    
    cursor = conn.cursor()
    
    # Vulnerability: SQL Injection via query parameter
    question_id = request.args.get('question_id', '1')
    query = f"SELECT * FROM votes WHERE question_id = {question_id}"
    cursor.execute(query)
    votes = cursor.fetchall()
    
    cursor.close()
    conn.close()
    
    return jsonify({"votes": votes})

@app.route('/debug')
def debug():
    """Debug endpoint - Vulnerability: Information disclosure"""
    # Vulnerability: Exposes sensitive information
    info = {
        "database_config": {
            "host": DB_CONFIG['host'],
            "user": DB_CONFIG['user'],
            "database": DB_CONFIG['database']
        },
        "environment": dict(os.environ),
        "session": dict(session),
        "request_headers": dict(request.headers)
    }
    return jsonify(info)

@app.route('/file')
def file_access():
    """File access endpoint - Vulnerability: Path Traversal"""
    filename = request.args.get('file', '')
    # Vulnerability: Path traversal - no validation
    try:
        with open(filename, 'r') as f:
            return f.read()
    except Exception as e:
        return f"Error: {e}", 500

@app.route('/exec')
def exec_command():
    """Command execution - Vulnerability: Command Injection"""
    command = request.args.get('cmd', '')
    # Vulnerability: Command injection - direct shell execution
    try:
        result = subprocess.check_output(command, shell=True).decode()
        return result
    except Exception as e:
        return f"Error: {e}", 500

@app.route('/deserialize')
def deserialize():
    """Deserialization endpoint - Vulnerability: Insecure Deserialization"""
    data = request.args.get('data', '')
    # Vulnerability: Insecure pickle deserialization
    try:
        decoded = base64.b64decode(data)
        obj = pickle.loads(decoded)
        return jsonify({"deserialized": str(obj)})
    except Exception as e:
        return f"Error: {e}", 500

if __name__ == '__main__':
    init_database()
    # Vulnerability: Running in debug mode
    app.run(host='0.0.0.0', port=8080, debug=True)

