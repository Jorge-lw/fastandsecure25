#!/usr/bin/env python3
"""
E-Commerce Application
Legitimate shopping functionality with vulnerabilities
"""

from flask import Flask, render_template_string, request, session
import os

app = Flask(__name__)
app.secret_key = 'insecure_secret_key_12345'

# Legitimate products
PRODUCTS = [
    {'id': 1, 'name': 'Laptop', 'price': 999.99, 'category': 'Electronics'},
    {'id': 2, 'name': 'Smartphone', 'price': 699.99, 'category': 'Electronics'},
    {'id': 3, 'name': 'Headphones', 'price': 149.99, 'category': 'Audio'},
    {'id': 4, 'name': 'Keyboard', 'price': 79.99, 'category': 'Accessories'},
    {'id': 5, 'name': 'Mouse', 'price': 29.99, 'category': 'Accessories'},
]

INDEX_TEMPLATE = '''
<!DOCTYPE html>
<html>
<head>
    <title>E-Commerce Store</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: linear-gradient(135deg, #fa709a 0%, #fee140 100%);
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
            background: linear-gradient(135deg, #fa709a 0%, #fee140 100%);
            color: white;
            padding: 40px;
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
            gap: 20px;
            margin-top: 20px;
            flex-wrap: wrap;
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
        .products-grid {
            display: grid;
            grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
            gap: 30px;
            margin-top: 30px;
        }
        .product {
            background: white;
            border-radius: 15px;
            padding: 25px;
            box-shadow: 0 5px 15px rgba(0,0,0,0.1);
            transition: all 0.3s;
            border: 2px solid transparent;
            text-align: center;
        }
        .product:hover {
            transform: translateY(-5px);
            box-shadow: 0 10px 30px rgba(250, 112, 154, 0.3);
            border-color: #fa709a;
        }
        .product-icon {
            font-size: 4em;
            margin-bottom: 15px;
        }
        .product h3 {
            font-size: 1.4em;
            color: #333;
            margin-bottom: 15px;
        }
        .product-price {
            font-size: 2em;
            color: #fa709a;
            font-weight: 700;
            margin: 15px 0;
        }
        .product-category {
            color: #666;
            font-size: 0.9em;
            margin-bottom: 15px;
        }
        .product-link {
            display: inline-block;
            margin-top: 15px;
            padding: 10px 25px;
            background: linear-gradient(135deg, #fa709a 0%, #fee140 100%);
            color: white;
            text-decoration: none;
            border-radius: 25px;
            font-weight: 600;
            transition: all 0.3s;
        }
        .product-link:hover {
            transform: scale(1.05);
            box-shadow: 0 5px 15px rgba(250, 112, 154, 0.4);
        }
    </style>
</head>
<body>
    <div class="container">
        <header>
            <h1>🛒 E-Commerce Store</h1>
            <nav>
                <a href="/">Home</a>
                <a href="/products">Products</a>
                <a href="/cart">Cart</a>
                <a href="/checkout">Checkout</a>
            </nav>
        </header>
        <div class="content">
            <h2 class="section-title">Featured Products</h2>
            <div class="products-grid">
                {% for product in products[:3] %}
                <div class="product">
                    <div class="product-icon">🛍️</div>
                    <h3>{{ product.name }}</h3>
                    <div class="product-category">{{ product.category }}</div>
                    <div class="product-price">${{ product.price }}</div>
                    <a href="/product/{{ product.id }}" class="product-link">View Details</a>
                </div>
                {% endfor %}
            </div>
        </div>
    </div>
</body>
</html>
'''

PRODUCTS_TEMPLATE = '''
<!DOCTYPE html>
<html>
<head>
    <title>All Products</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: linear-gradient(135deg, #fa709a 0%, #fee140 100%);
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
            background: linear-gradient(135deg, #fa709a 0%, #fee140 100%);
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
        }
        .content {
            padding: 40px;
        }
        h1 {
            font-size: 2.5em;
            color: #333;
            margin-bottom: 30px;
            text-align: center;
        }
        .products-grid {
            display: grid;
            grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
            gap: 30px;
        }
        .product {
            background: white;
            border-radius: 15px;
            padding: 25px;
            box-shadow: 0 5px 15px rgba(0,0,0,0.1);
            transition: all 0.3s;
            border: 2px solid transparent;
            text-align: center;
        }
        .product:hover {
            transform: translateY(-5px);
            box-shadow: 0 10px 30px rgba(250, 112, 154, 0.3);
            border-color: #fa709a;
        }
        .product-icon {
            font-size: 4em;
            margin-bottom: 15px;
        }
        .product h3 {
            font-size: 1.4em;
            color: #333;
            margin-bottom: 10px;
        }
        .product-price {
            font-size: 2em;
            color: #fa709a;
            font-weight: 700;
            margin: 15px 0;
        }
        .product-category {
            color: #666;
            font-size: 0.9em;
            margin-bottom: 15px;
        }
        .product-link {
            display: inline-block;
            margin-top: 15px;
            padding: 10px 25px;
            background: linear-gradient(135deg, #fa709a 0%, #fee140 100%);
            color: white;
            text-decoration: none;
            border-radius: 25px;
            font-weight: 600;
            transition: all 0.3s;
        }
        .product-link:hover {
            transform: scale(1.05);
        }
    </style>
</head>
<body>
    <div class="container">
        <header>
            <h1>🛒 All Products</h1>
            <nav>
                <a href="/">Home</a>
                <a href="/products">Products</a>
                <a href="/cart">Cart</a>
                <a href="/checkout">Checkout</a>
            </nav>
        </header>
        <div class="content">
            <div class="products-grid">
                {% for product in products %}
                <div class="product">
                    <div class="product-icon">🛍️</div>
                    <h3>{{ product.name }}</h3>
                    <div class="product-category">{{ product.category }}</div>
                    <div class="product-price">${{ product.price }}</div>
                    <a href="/product/{{ product.id }}" class="product-link">View Details</a>
                </div>
                {% endfor %}
            </div>
        </div>
    </div>
</body>
</html>
'''

PRODUCT_TEMPLATE = '''
<!DOCTYPE html>
<html>
<head>
    <title>{{ product.name }}</title>
</head>
<body>
    <nav><a href="/">Home</a> | <a href="/products">Products</a></nav>
    <h1>{{ product.name }}</h1>
    <p>Price: ${{ product.price }}</p>
    <p>Category: {{ product.category }}</p>
    <form method="POST" action="/add-to-cart">
        <input type="hidden" name="product_id" value="{{ product.id }}">
        <button type="submit">Add to Cart</button>
    </form>
</body>
</html>
'''

@app.route('/')
def index():
    """Home page"""
    return render_template_string(INDEX_TEMPLATE, products=PRODUCTS)

@app.route('/products')
def products():
    """Products listing"""
    category = request.args.get('category', '')
    # Vulnerability: SQL Injection simulation
    filtered = [p for p in PRODUCTS if not category or p['category'].lower() == category.lower()]
    return render_template_string(PRODUCTS_TEMPLATE, products=filtered)

@app.route('/product/<int:product_id>')
def product(product_id):
    """Product details"""
    product = next((p for p in PRODUCTS if p['id'] == product_id), None)
    if not product:
        return "Product not found", 404
    return render_template_string(PRODUCT_TEMPLATE, product=product)

@app.route('/add-to-cart', methods=['POST'])
def add_to_cart():
    """Add product to cart"""
    # Vulnerability: No CSRF protection
    product_id = request.form.get('product_id')
    if 'cart' not in session:
        session['cart'] = []
    session['cart'].append(int(product_id))
    return redirect('/cart')

@app.route('/cart')
def cart():
    """Shopping cart"""
    cart_items = session.get('cart', [])
    items = [p for p in PRODUCTS if p['id'] in cart_items]
    total = sum(p['price'] for p in items)
    
    return f'''
    <html>
    <head><title>Cart</title></head>
    <body>
        <nav><a href="/">Home</a> | <a href="/cart">Cart</a></nav>
        <h1>Shopping Cart</h1>
        <ul>
            {' '.join(f"<li>{item['name']} - ${item['price']}</li>" for item in items)}
        </ul>
        <p><strong>Total: ${total:.2f}</strong></p>
        <p><a href="/checkout">Proceed to Checkout</a></p>
    </body>
    </html>
    '''

@app.route('/checkout')
def checkout():
    """Checkout page"""
    return '''
    <html>
    <head><title>Checkout</title></head>
    <body>
        <nav><a href="/">Home</a></nav>
        <h1>Checkout</h1>
        <p>Please enter your payment information...</p>
        <form method="POST" action="/process-payment">
            <p>Card Number: <input type="text" name="card"></p>
            <p><button type="submit">Pay Now</button></p>
        </form>
    </body>
    </html>
    '''

@app.route('/process-payment', methods=['POST'])
def process_payment():
    """Process payment - Vulnerability: No validation"""
    card = request.form.get('card', '')
    # Vulnerability: Logging sensitive data
    print(f"Processing payment with card: {card}")
    return "Payment processed successfully!"

@app.route('/api/products')
def api_products():
    """API endpoint"""
    return {'products': PRODUCTS}

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080, debug=True)

