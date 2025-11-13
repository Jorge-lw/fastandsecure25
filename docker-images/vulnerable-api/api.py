from flask import Flask, request, jsonify
import os
import subprocess
import pickle
import yaml

app = Flask(__name__)

# Vulnerability: Hardcoded secrets
SECRET_KEY = "insecure_secret_key_12345"
ADMIN_TOKEN = "admin_token_never_change"

# Vulnerability: Unsafe deserialization
@app.route('/unpickle', methods=['POST'])
def unpickle_data():
    data = request.data
    obj = pickle.loads(data)
    return jsonify({"status": "unpickled"})

# Vulnerability: YAML deserialization
@app.route('/yaml', methods=['POST'])
def yaml_load():
    data = request.data
    config = yaml.load(data, Loader=yaml.Loader)
    return jsonify(config)

# Vulnerability: Command injection
@app.route('/ping', methods=['GET'])
def ping():
    host = request.args.get('host', 'localhost')
    result = subprocess.run(['ping', '-c', '4', host], capture_output=True, text=True)
    return result.stdout

# Vulnerability: Path traversal
@app.route('/read', methods=['GET'])
def read_file():
    filename = request.args.get('file')
    with open(filename, 'r') as f:
        return f.read()

# Vulnerability: Expose environment variables
@app.route('/env', methods=['GET'])
def get_env():
    return jsonify(dict(os.environ))

# Vulnerability: Weak authentication
@app.route('/admin', methods=['GET'])
def admin():
    token = request.headers.get('X-Token')
    if token == ADMIN_TOKEN:
        return jsonify({"message": "Admin access granted", "secrets": SECRET_KEY})
    return jsonify({"error": "Unauthorized"}), 401

# Vulnerability: SSRF
@app.route('/fetch', methods=['GET'])
def fetch_url():
    import urllib.request
    url = request.args.get('url')
    response = urllib.request.urlopen(url)
    return response.read()

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)
