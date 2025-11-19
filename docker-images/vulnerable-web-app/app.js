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
    <head><title>Welcome - E-Commerce Platform</title></head>
    <body>
      <h1>Welcome to Our Store</h1>
      <nav>
        <a href="/">Home</a> | 
        <a href="/products">Products</a> | 
        <a href="/about">About</a> | 
        <a href="/contact">Contact</a>
      </nav>
      <p>Discover our amazing products and services!</p>
      <p><a href="/products">Browse Products</a></p>
    </body>
    </html>
  `);
});

// Legitimate content - Products page
app.get('/products', (req, res) => {
  res.send(`
    <!DOCTYPE html>
    <html>
    <head><title>Products</title></head>
    <body>
      <h1>Our Products</h1>
      <nav><a href="/">Home</a> | <a href="/products">Products</a></nav>
      <ul>
        <li>Product 1 - $99.99</li>
        <li>Product 2 - $149.99</li>
        <li>Product 3 - $199.99</li>
      </ul>
    </body>
    </html>
  `);
});

// Legitimate content - About page
app.get('/about', (req, res) => {
  res.send(`
    <!DOCTYPE html>
    <html>
    <head><title>About Us</title></head>
    <body>
      <h1>About Our Company</h1>
      <nav><a href="/">Home</a> | <a href="/about">About</a></nav>
      <p>We are a leading e-commerce platform...</p>
    </body>
    </html>
  `);
});

// Legitimate content - Contact page
app.get('/contact', (req, res) => {
  res.send(`
    <!DOCTYPE html>
    <html>
    <head><title>Contact</title></head>
    <body>
      <h1>Contact Us</h1>
      <nav><a href="/">Home</a> | <a href="/contact">Contact</a></nav>
      <p>Email: contact@example.com</p>
      <p>Phone: +1-555-0123</p>
    </body>
    </html>
  `);
});

app.listen(3000, '0.0.0.0', () => {
  console.log('Vulnerable web app running on port 3000');
});
