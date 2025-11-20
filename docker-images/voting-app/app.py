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
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: linear-gradient(135deg, #f093fb 0%, #f5576c 100%);
            min-height: 100vh;
            padding: 20px;
        }
        .container {
            max-width: 900px;
            margin: 0 auto;
            background: white;
            border-radius: 20px;
            box-shadow: 0 20px 60px rgba(0,0,0,0.3);
            overflow: hidden;
        }
        header {
            background: linear-gradient(135deg, #f093fb 0%, #f5576c 100%);
            color: white;
            padding: 40px;
            text-align: center;
        }
        header h1 {
            font-size: 2.5em;
            margin-bottom: 10px;
            text-shadow: 2px 2px 4px rgba(0,0,0,0.2);
        }
        .content {
            padding: 40px;
        }
        .question {
            font-size: 1.5em;
            color: #333;
            margin-bottom: 30px;
            text-align: center;
            font-weight: 600;
        }
        .vote-section {
            background: linear-gradient(135deg, #f8f9fa 0%, #e9ecef 100%);
            padding: 40px;
            border-radius: 15px;
            margin: 30px 0;
            text-align: center;
        }
        .vote-buttons {
            display: flex;
            gap: 20px;
            justify-content: center;
            margin-top: 20px;
        }
        .vote-btn {
            padding: 15px 40px;
            font-size: 1.2em;
            font-weight: 600;
            border: none;
            border-radius: 30px;
            cursor: pointer;
            transition: all 0.3s;
            text-transform: uppercase;
            letter-spacing: 1px;
        }
        .vote-btn-yes {
            background: linear-gradient(135deg, #11998e 0%, #38ef7d 100%);
            color: white;
            box-shadow: 0 5px 15px rgba(17, 153, 142, 0.4);
        }
        .vote-btn-yes:hover {
            transform: translateY(-3px);
            box-shadow: 0 8px 25px rgba(17, 153, 142, 0.6);
        }
        .vote-btn-no {
            background: linear-gradient(135deg, #eb3349 0%, #f45c43 100%);
            color: white;
            box-shadow: 0 5px 15px rgba(235, 51, 73, 0.4);
        }
        .vote-btn-no:hover {
            transform: translateY(-3px);
            box-shadow: 0 8px 25px rgba(235, 51, 73, 0.6);
        }
        .results {
            background: #f8f9fa;
            padding: 30px;
            border-radius: 15px;
            margin: 30px 0;
        }
        .results h2 {
            color: #333;
            margin-bottom: 20px;
            text-align: center;
        }
        .results-grid {
            display: grid;
            grid-template-columns: repeat(3, 1fr);
            gap: 20px;
            text-align: center;
        }
        .result-item {
            padding: 20px;
            background: white;
            border-radius: 10px;
            box-shadow: 0 3px 10px rgba(0,0,0,0.1);
        }
        .result-label {
            font-size: 0.9em;
            color: #666;
            margin-bottom: 10px;
        }
        .result-value {
            font-size: 2em;
            font-weight: 700;
            color: #f5576c;
        }
        .comment-section {
            background: #f8f9fa;
            padding: 30px;
            border-radius: 15px;
            margin: 30px 0;
        }
        .comment-section h3 {
            color: #333;
            margin-bottom: 20px;
        }
        textarea {
            width: 100%;
            padding: 15px;
            border: 2px solid #ddd;
            border-radius: 10px;
            font-family: inherit;
            font-size: 1em;
            resize: vertical;
        }
        .submit-btn {
            margin-top: 15px;
            padding: 12px 30px;
            background: linear-gradient(135deg, #f093fb 0%, #f5576c 100%);
            color: white;
            border: none;
            border-radius: 25px;
            font-weight: 600;
            cursor: pointer;
            transition: all 0.3s;
        }
        .submit-btn:hover {
            transform: translateY(-2px);
            box-shadow: 0 5px 15px rgba(245, 87, 108, 0.4);
        }
        .comments {
            margin-top: 30px;
            padding: 20px;
            background: #f8f9fa;
            border-radius: 15px;
        }
        .comments h3 {
            color: #333;
            margin-bottom: 15px;
        }
        .footer-links {
            margin-top: 40px;
            text-align: center;
            padding-top: 20px;
            border-top: 2px solid #eee;
        }
        .footer-links a {
            color: #f5576c;
            text-decoration: none;
            margin: 0 15px;
            font-weight: 600;
            transition: all 0.3s;
        }
        .footer-links a:hover {
            color: #f093fb;
        }
    </style>
</head>
<body>
    <div class="container">
        <header>
            <h1>🗳️ Security Survey</h1>
        </header>
        <div class="content">
            <div class="question">Question: Is this system secure?</div>
            
            <div class="vote-section">
                <form method="POST" action="/vote">
                    <input type="hidden" name="question_id" value="1">
                    <div class="vote-buttons">
                        <button type="submit" name="vote" value="yes" class="vote-btn vote-btn-yes">✓ YES</button>
                        <button type="submit" name="vote" value="no" class="vote-btn vote-btn-no">✗ NO</button>
                    </div>
                </form>
            </div>
            
            <div class="results">
                <h2>📊 Current Results</h2>
                <div class="results-grid">
                    <div class="result-item">
                        <div class="result-label">YES Votes</div>
                        <div class="result-value">{{ yes_count }}</div>
                    </div>
                    <div class="result-item">
                        <div class="result-label">NO Votes</div>
                        <div class="result-value">{{ no_count }}</div>
                    </div>
                    <div class="result-item">
                        <div class="result-label">Total</div>
                        <div class="result-value">{{ total }}</div>
                    </div>
                </div>
            </div>
            
            <div class="comment-section">
                <h3>💬 Add Comment</h3>
                <form method="POST" action="/comment">
                    <textarea name="comment" rows="4" placeholder="Share your thoughts..."></textarea><br>
                    <button type="submit" class="submit-btn">Submit Comment</button>
                </form>
            </div>
            
            <div class="comments">
                <h3>Recent Comments</h3>
                {{ comments|safe }}
            </div>
            
            <div class="footer-links">
                <a href="/admin">🔐 Admin Panel</a>
                <a href="/api/votes">📡 API Endpoint</a>
                <a href="/debug">🔍 Debug Info</a>
            </div>
        </div>
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
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            padding: 20px;
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
            background: white;
            border-radius: 20px;
            box-shadow: 0 20px 60px rgba(0,0,0,0.3);
            overflow: hidden;
        }
        header {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 30px 40px;
        }
        header h1 {
            font-size: 2em;
            margin-bottom: 10px;
        }
        .content {
            padding: 40px;
        }
        table {
            width: 100%;
            border-collapse: collapse;
            margin-top: 20px;
            background: white;
            border-radius: 10px;
            overflow: hidden;
            box-shadow: 0 3px 10px rgba(0,0,0,0.1);
        }
        th, td {
            padding: 12px;
            text-align: left;
            border-bottom: 1px solid #eee;
        }
        th {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            font-weight: 600;
        }
        tr:hover {
            background: #f8f9fa;
        }
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

