const express = require('express');
const fs = require('fs');
const app = express();

// Vulnerability: No input validation
app.use(express.json());

// Vulnerability: Path traversal
app.get('/file', (req, res) => {
  const filename = req.query.name;
  const content = fs.readFileSync(filename, 'utf8');
  res.send(content);
});

// Vulnerability: SQL Injection (simulated)
app.get('/users', (req, res) => {
  const query = `SELECT * FROM users WHERE id = ${req.query.id}`;
  res.send(`Executing: ${query}`);
});

// Vulnerability: XSS
app.get('/search', (req, res) => {
  const search = req.query.q;
  res.send(`<h1>Results for: ${search}</h1>`);
});

// Vulnerability: Expose sensitive information
app.get('/debug', (req, res) => {
  res.json({
    env: process.env,
    cwd: process.cwd(),
    user: process.getuid()
  });
});

// Vulnerability: Command injection
app.post('/execute', (req, res) => {
  const { command } = req.body;
  const { exec } = require('child_process');
  exec(command, (error, stdout, stderr) => {
    res.send(stdout);
  });
});

// Vulnerability: Expose secrets
app.get('/secrets', (req, res) => {
  const secrets = fs.readFileSync('/app/secrets.txt', 'utf8');
  res.send(secrets);
});

// Legitimate content - Home page
app.get('/', (req, res) => {
  res.send(`
    <!DOCTYPE html>
    <html>
    <head>
      <title>Welcome - E-Commerce Platform</title>
      <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
          font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
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
          padding: 40px;
          text-align: center;
        }
        header h1 {
          font-size: 3em;
          margin-bottom: 10px;
          text-shadow: 2px 2px 4px rgba(0,0,0,0.2);
        }
        nav {
          background: rgba(255,255,255,0.1);
          padding: 20px;
          display: flex;
          justify-content: center;
          gap: 30px;
          flex-wrap: wrap;
        }
        nav a {
          color: white;
          text-decoration: none;
          font-weight: 600;
          padding: 10px 20px;
          border-radius: 25px;
          transition: all 0.3s;
          background: rgba(255,255,255,0.2);
        }
        nav a:hover {
          background: rgba(255,255,255,0.3);
          transform: translateY(-2px);
        }
        .content {
          padding: 60px 40px;
          text-align: center;
        }
        .hero {
          font-size: 1.5em;
          color: #333;
          margin-bottom: 30px;
          line-height: 1.6;
        }
        .cta-button {
          display: inline-block;
          background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
          color: white;
          padding: 15px 40px;
          border-radius: 30px;
          text-decoration: none;
          font-weight: 600;
          font-size: 1.2em;
          margin-top: 20px;
          transition: all 0.3s;
          box-shadow: 0 5px 15px rgba(102, 126, 234, 0.4);
        }
        .cta-button:hover {
          transform: translateY(-3px);
          box-shadow: 0 8px 25px rgba(102, 126, 234, 0.6);
        }
        .features {
          display: grid;
          grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
          gap: 30px;
          margin-top: 60px;
        }
        .feature {
          padding: 30px;
          background: #f8f9fa;
          border-radius: 15px;
          transition: all 0.3s;
        }
        .feature:hover {
          transform: translateY(-5px);
          box-shadow: 0 10px 30px rgba(0,0,0,0.1);
        }
        .feature-icon {
          font-size: 3em;
          margin-bottom: 15px;
        }
      </style>
    </head>
    <body>
      <div class="container">
        <header>
          <h1>🛍️ Welcome to Our Store</h1>
          <nav>
            <a href="/">Home</a>
            <a href="/products">Products</a>
            <a href="/about">About</a>
            <a href="/contact">Contact</a>
          </nav>
        </header>
        <div class="content">
          <div class="hero">
            Discover our amazing products and services!<br>
            Quality products at unbeatable prices.
          </div>
          <a href="/products" class="cta-button">Browse Products →</a>
          <div class="features">
            <div class="feature">
              <div class="feature-icon">🚀</div>
              <h3>Fast Delivery</h3>
              <p>Get your orders delivered quickly</p>
            </div>
            <div class="feature">
              <div class="feature-icon">💎</div>
              <h3>Premium Quality</h3>
              <p>Only the best products</p>
            </div>
            <div class="feature">
              <div class="feature-icon">🔒</div>
              <h3>Secure Shopping</h3>
              <p>Safe and secure transactions</p>
            </div>
          </div>
        </div>
      </div>
    </body>
    </html>
  `);
});

// Legitimate content - Products page
app.get('/products', (req, res) => {
  res.send(`
    <!DOCTYPE html>
    <html>
    <head>
      <title>Products</title>
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
        nav {
          display: flex;
          gap: 20px;
          margin-top: 15px;
        }
        nav a {
          color: white;
          text-decoration: none;
          padding: 8px 16px;
          border-radius: 20px;
          background: rgba(255,255,255,0.2);
          transition: all 0.3s;
        }
        nav a:hover {
          background: rgba(255,255,255,0.3);
        }
        .content {
          padding: 40px;
        }
        h1 {
          font-size: 2.5em;
          margin-bottom: 30px;
          color: #333;
        }
        .products-grid {
          display: grid;
          grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
          gap: 30px;
          margin-top: 30px;
        }
        .product-card {
          background: white;
          border-radius: 15px;
          padding: 25px;
          box-shadow: 0 5px 15px rgba(0,0,0,0.1);
          transition: all 0.3s;
          border: 2px solid transparent;
        }
        .product-card:hover {
          transform: translateY(-5px);
          box-shadow: 0 10px 30px rgba(102, 126, 234, 0.3);
          border-color: #667eea;
        }
        .product-icon {
          font-size: 4em;
          text-align: center;
          margin-bottom: 15px;
        }
        .product-name {
          font-size: 1.5em;
          font-weight: 600;
          color: #333;
          margin-bottom: 10px;
        }
        .product-price {
          font-size: 1.8em;
          color: #667eea;
          font-weight: 700;
          margin: 15px 0;
        }
        .product-btn {
          width: 100%;
          padding: 12px;
          background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
          color: white;
          border: none;
          border-radius: 25px;
          font-weight: 600;
          cursor: pointer;
          transition: all 0.3s;
        }
        .product-btn:hover {
          transform: scale(1.05);
        }
      </style>
    </head>
    <body>
      <div class="container">
        <header>
          <h1>🛍️ Our Products</h1>
          <nav>
            <a href="/">Home</a>
            <a href="/products">Products</a>
            <a href="/about">About</a>
            <a href="/contact">Contact</a>
          </nav>
        </header>
        <div class="content">
          <div class="products-grid">
            <div class="product-card">
              <div class="product-icon">💻</div>
              <div class="product-name">Premium Laptop</div>
              <div class="product-price">$99.99</div>
              <button class="product-btn">Add to Cart</button>
            </div>
            <div class="product-card">
              <div class="product-icon">📱</div>
              <div class="product-name">Smartphone Pro</div>
              <div class="product-price">$149.99</div>
              <button class="product-btn">Add to Cart</button>
            </div>
            <div class="product-card">
              <div class="product-icon">⌚</div>
              <div class="product-name">Smart Watch</div>
              <div class="product-price">$199.99</div>
              <button class="product-btn">Add to Cart</button>
            </div>
          </div>
        </div>
      </div>
    </body>
    </html>
  `);
});

// Legitimate content - About page
app.get('/about', (req, res) => {
  res.send(`
    <!DOCTYPE html>
    <html>
    <head>
      <title>About Us</title>
      <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
          font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
          background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
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
          background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
          color: white;
          padding: 40px;
          text-align: center;
        }
        nav {
          display: flex;
          justify-content: center;
          gap: 20px;
          margin-top: 15px;
        }
        nav a {
          color: white;
          text-decoration: none;
          padding: 8px 16px;
          border-radius: 20px;
          background: rgba(255,255,255,0.2);
        }
        .content {
          padding: 50px 40px;
          line-height: 1.8;
          color: #333;
        }
        h1 { margin-bottom: 30px; color: #333; }
        p { margin-bottom: 20px; font-size: 1.1em; }
      </style>
    </head>
    <body>
      <div class="container">
        <header>
          <h1>📖 About Our Company</h1>
          <nav>
            <a href="/">Home</a>
            <a href="/products">Products</a>
            <a href="/about">About</a>
            <a href="/contact">Contact</a>
          </nav>
        </header>
        <div class="content">
          <h1>Who We Are</h1>
          <p>We are a leading e-commerce platform dedicated to providing the best shopping experience for our customers.</p>
          <p>With years of experience in the industry, we've built a reputation for quality, reliability, and exceptional customer service.</p>
          <p>Our mission is to make online shopping simple, secure, and enjoyable for everyone.</p>
        </div>
      </div>
    </body>
    </html>
  `);
});

// Legitimate content - Contact page
app.get('/contact', (req, res) => {
  res.send(`
    <!DOCTYPE html>
    <html>
    <head>
      <title>Contact</title>
      <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
          font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
          background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
          min-height: 100vh;
          padding: 20px;
        }
        .container {
          max-width: 700px;
          margin: 0 auto;
          background: white;
          border-radius: 20px;
          box-shadow: 0 20px 60px rgba(0,0,0,0.3);
          overflow: hidden;
        }
        header {
          background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
          color: white;
          padding: 40px;
          text-align: center;
        }
        nav {
          display: flex;
          justify-content: center;
          gap: 20px;
          margin-top: 15px;
        }
        nav a {
          color: white;
          text-decoration: none;
          padding: 8px 16px;
          border-radius: 20px;
          background: rgba(255,255,255,0.2);
        }
        .content {
          padding: 50px 40px;
        }
        .contact-item {
          background: #f8f9fa;
          padding: 25px;
          margin: 20px 0;
          border-radius: 15px;
          display: flex;
          align-items: center;
          gap: 20px;
        }
        .contact-icon {
          font-size: 2.5em;
        }
        .contact-info h3 {
          color: #667eea;
          margin-bottom: 5px;
        }
        .contact-info p {
          color: #666;
          font-size: 1.1em;
        }
      </style>
    </head>
    <body>
      <div class="container">
        <header>
          <h1>📞 Contact Us</h1>
          <nav>
            <a href="/">Home</a>
            <a href="/products">Products</a>
            <a href="/about">About</a>
            <a href="/contact">Contact</a>
          </nav>
        </header>
        <div class="content">
          <div class="contact-item">
            <div class="contact-icon">📧</div>
            <div class="contact-info">
              <h3>Email</h3>
              <p>contact@example.com</p>
            </div>
          </div>
          <div class="contact-item">
            <div class="contact-icon">📱</div>
            <div class="contact-info">
              <h3>Phone</h3>
              <p>+1-555-0123</p>
            </div>
          </div>
          <div class="contact-item">
            <div class="contact-icon">📍</div>
            <div class="contact-info">
              <h3>Address</h3>
              <p>123 Commerce Street, Business City, BC 12345</p>
            </div>
          </div>
        </div>
      </div>
    </body>
    </html>
  `);
});

app.listen(3000, '0.0.0.0', () => {
  console.log('Vulnerable web app running on port 3000');
});
