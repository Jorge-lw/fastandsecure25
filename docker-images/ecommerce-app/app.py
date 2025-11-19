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
        body { font-family: Arial; max-width: 1000px; margin: 50px auto; padding: 20px; }
        .product { display: inline-block; margin: 20px; padding: 15px; border: 1px solid #ddd; width: 200px; }
        nav { margin-bottom: 30px; }
    </style>
</head>
<body>
    <h1>E-Commerce Store</h1>
    <nav>
        <a href="/">Home</a> | 
        <a href="/products">Products</a> | 
        <a href="/cart">Cart</a> | 
        <a href="/checkout">Checkout</a>
    </nav>
    
    <h2>Featured Products</h2>
    {% for product in products[:3] %}
    <div class="product">
        <h3>{{ product.name }}</h3>
        <p>${{ product.price }}</p>
        <p><a href="/product/{{ product.id }}">View Details</a></p>
    </div>
    {% endfor %}
</body>
</html>
'''

PRODUCTS_TEMPLATE = '''
<!DOCTYPE html>
<html>
<head>
    <title>All Products</title>
</head>
<body>
    <nav><a href="/">Home</a> | <a href="/products">Products</a></nav>
    <h1>All Products</h1>
    {% for product in products %}
    <div class="product">
        <h3>{{ product.name }}</h3>
        <p>${{ product.price }}</p>
        <p>Category: {{ product.category }}</p>
        <p><a href="/product/{{ product.id }}">View Details</a></p>
    </div>
    {% endfor %}
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

