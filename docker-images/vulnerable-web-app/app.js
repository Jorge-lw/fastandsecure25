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

app.listen(3000, '0.0.0.0', () => {
  console.log('Vulnerable web app running on port 3000');
});
