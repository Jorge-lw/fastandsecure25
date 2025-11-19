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
        body { font-family: Arial; max-width: 900px; margin: 50px auto; padding: 20px; }
        .post { margin: 30px 0; padding: 20px; border: 1px solid #ddd; }
        nav { margin-bottom: 30px; }
    </style>
</head>
<body>
    <h1>Tech Blog</h1>
    <nav>
        <a href="/">Home</a> | 
        <a href="/posts">All Posts</a> | 
        <a href="/about">About</a>
    </nav>
    
    <h2>Latest Posts</h2>
    {% for post in posts %}
    <div class="post">
        <h3><a href="/post/{{ post.id }}">{{ post.title }}</a></h3>
        <p><small>By {{ post.author }} on {{ post.date }}</small></p>
        <p>{{ post.content }}</p>
        <a href="/post/{{ post.id }}">Read more...</a>
    </div>
    {% endfor %}
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

