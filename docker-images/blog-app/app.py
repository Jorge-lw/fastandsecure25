#!/usr/bin/env python3
"""
Simple Blog Application
Legitimate content with some vulnerabilities for testing
"""

from flask import Flask, render_template_string, request, redirect, url_for
import os
from datetime import datetime

app = Flask(__name__)

# Legitimate blog posts
BLOG_POSTS = [
    {
        'id': 1,
        'title': 'Getting Started with Cloud Security',
        'content': 'Cloud security is essential for modern applications...',
        'author': 'Admin',
        'date': '2025-11-15'
    },
    {
        'id': 2,
        'title': 'Best Practices for Kubernetes',
        'content': 'Kubernetes provides powerful orchestration capabilities...',
        'author': 'DevOps Team',
        'date': '2025-11-14'
    },
    {
        'id': 3,
        'title': 'Understanding Container Security',
        'content': 'Containers require careful security considerations...',
        'author': 'Security Team',
        'date': '2025-11-13'
    }
]

INDEX_TEMPLATE = '''
<!DOCTYPE html>
<html>
<head>
    <title>Tech Blog</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: linear-gradient(135deg, #4facfe 0%, #00f2fe 100%);
            min-height: 100vh;
            padding: 20px;
        }
        .container {
            max-width: 1000px;
            margin: 0 auto;
            background: white;
            border-radius: 20px;
            box-shadow: 0 20px 60px rgba(0,0,0,0.3);
            overflow: hidden;
        }
        header {
            background: linear-gradient(135deg, #4facfe 0%, #00f2fe 100%);
            color: white;
            padding: 50px 40px;
            text-align: center;
        }
        header h1 {
            font-size: 3em;
            margin-bottom: 15px;
            text-shadow: 2px 2px 4px rgba(0,0,0,0.2);
        }
        nav {
            display: flex;
            justify-content: center;
            gap: 25px;
            margin-top: 20px;
        }
        nav a {
            color: white;
            text-decoration: none;
            padding: 10px 20px;
            border-radius: 25px;
            background: rgba(255,255,255,0.2);
            transition: all 0.3s;
            font-weight: 600;
        }
        nav a:hover {
            background: rgba(255,255,255,0.3);
            transform: translateY(-2px);
        }
        .content {
            padding: 40px;
        }
        .section-title {
            font-size: 2em;
            color: #333;
            margin-bottom: 30px;
            text-align: center;
        }
        .posts-grid {
            display: grid;
            gap: 30px;
        }
        .post {
            background: linear-gradient(135deg, #f8f9fa 0%, #ffffff 100%);
            padding: 30px;
            border-radius: 15px;
            box-shadow: 0 5px 15px rgba(0,0,0,0.1);
            transition: all 0.3s;
            border-left: 5px solid #4facfe;
        }
        .post:hover {
            transform: translateY(-5px);
            box-shadow: 0 10px 30px rgba(79, 172, 254, 0.3);
        }
        .post h3 {
            margin-bottom: 15px;
        }
        .post h3 a {
            color: #333;
            text-decoration: none;
            font-size: 1.5em;
            transition: color 0.3s;
        }
        .post h3 a:hover {
            color: #4facfe;
        }
        .post-meta {
            color: #666;
            font-size: 0.9em;
            margin-bottom: 15px;
            display: flex;
            gap: 15px;
            align-items: center;
        }
        .post-content {
            color: #555;
            line-height: 1.6;
            margin-bottom: 15px;
        }
        .read-more {
            color: #4facfe;
            text-decoration: none;
            font-weight: 600;
            transition: all 0.3s;
        }
        .read-more:hover {
            color: #00f2fe;
        }
    </style>
</head>
<body>
    <div class="container">
        <header>
            <h1>📝 Tech Blog</h1>
            <nav>
                <a href="/">Home</a>
                <a href="/posts">All Posts</a>
                <a href="/about">About</a>
            </nav>
        </header>
        <div class="content">
            <h2 class="section-title">Latest Posts</h2>
            {% for post in posts %}
            <div class="post">
                <h3><a href="/post/{{ post.id }}">{{ post.title }}</a></h3>
                <div class="post-meta">
                    <span>👤 {{ post.author }}</span>
                    <span>📅 {{ post.date }}</span>
                </div>
                <div class="post-content">{{ post.content }}</div>
                <a href="/post/{{ post.id }}" class="read-more">Read more →</a>
            </div>
            {% endfor %}
        </div>
    </div>
</body>
</html>
'''

POST_TEMPLATE = '''
<!DOCTYPE html>
<html>
<head>
    <title>{{ post.title }}</title>
</head>
<body>
    <nav><a href="/">Home</a> | <a href="/posts">All Posts</a></nav>
    <h1>{{ post.title }}</h1>
    <p><small>By {{ post.author }} on {{ post.date }}</small></p>
    <div>{{ post.content }}</div>
    <p><a href="/">Back to Home</a></p>
</body>
</html>
'''

@app.route('/')
def index():
    """Home page with latest posts"""
    return render_template_string(INDEX_TEMPLATE, posts=BLOG_POSTS[:3])

@app.route('/posts')
def posts():
    """All posts page"""
    return render_template_string(INDEX_TEMPLATE, posts=BLOG_POSTS)

@app.route('/post/<int:post_id>')
def post(post_id):
    """Individual post page"""
    # Vulnerability: No input validation
    post = next((p for p in BLOG_POSTS if p['id'] == post_id), None)
    if not post:
        return "Post not found", 404
    return render_template_string(POST_TEMPLATE, post=post)

@app.route('/about')
def about():
    """About page"""
    return '''
    <html>
    <head><title>About</title></head>
    <body>
        <nav><a href="/">Home</a></nav>
        <h1>About Our Blog</h1>
        <p>We write about technology, security, and cloud computing.</p>
    </body>
    </html>
    '''

@app.route('/search')
def search():
    """Search functionality - Vulnerability: XSS"""
    query = request.args.get('q', '')
    # Vulnerability: XSS - Direct output without sanitization
    return f'<h1>Search Results for: {query}</h1><p>No results found.</p>'

@app.route('/api/posts')
def api_posts():
    """API endpoint for posts"""
    return {'posts': BLOG_POSTS}

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080, debug=True)

