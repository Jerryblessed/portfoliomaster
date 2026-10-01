import os
import time
import sqlite3
import json
from datetime import datetime
from flask import Flask, request, jsonify
from flask_cors import CORS
from werkzeug.security import generate_password_hash, check_password_hash
from google import genai
from google.genai import types

app = Flask(__name__)
CORS(app)

# CONFIGURATION
GEMINI_API_KEY ="AQ.Ab8RN6L38tUETkvV4SAi0rlRfhjOSsCvSlmuBI8BhNbiU_pqiQ"
ADMIN_KEY = os.environ.get("ADMIN_KEY", "MyFallbackKey2026!")
client = genai.Client(api_key=GEMINI_API_KEY, http_options={'api_version': 'v1alpha'})

# DATABASE SETUP
def init_db():
    conn = sqlite3.connect('portfolio.db')
    c = conn.cursor()
    
    # Users table
    c.execute('''CREATE TABLE IF NOT EXISTS users 
                 (id INTEGER PRIMARY KEY AUTOINCREMENT, 
                  email TEXT UNIQUE, 
                  password TEXT, 
                  trials_remaining INTEGER DEFAULT 5,
                  analysis_credits INTEGER DEFAULT 0,
                  tier TEXT DEFAULT 'free',
                  alerts_enabled INTEGER DEFAULT 1)''')
    
    # Investments table
    c.execute('''CREATE TABLE IF NOT EXISTS investments
                 (id TEXT PRIMARY KEY,
                  user_id INTEGER,
                  name TEXT,
                  type TEXT,
                  quantity REAL,
                  purchase_price REAL,
                  current_price REAL,
                  currency TEXT DEFAULT 'USD',
                  purchase_date TEXT,
                  platform TEXT,
                  country TEXT,
                  sector TEXT,
                  maturity_date TEXT,
                  notes TEXT,
                  created_at TEXT,
                  FOREIGN KEY(user_id) REFERENCES users(id))''')
    
    conn.commit()
    conn.close()

init_db()

# === HELPER FUNCTIONS ===

def dict_factory(cursor, row):
    """Convert SQLite rows to dictionaries"""
    d = {}
    for idx, col in enumerate(cursor.description):
        d[col[0]] = row[idx]
    return d

# === AUTH ROUTES ===

@app.route('/auth/register', methods=['POST'])
def register():
    data = request.json
    email = data.get('email')
    password = generate_password_hash(data.get('password'))
    
    try:
        conn = sqlite3.connect('portfolio.db')
        c = conn.cursor()
        c.execute("INSERT INTO users (email, password) VALUES (?, ?)", (email, password))
        conn.commit()
        
        user_id = c.lastrowid
        conn.close()
        
        return jsonify({
            'success': True,
            'message': 'User registered',
            'user': {
                'user_id': str(user_id),
                'email': email,
                'trials_remaining': 5,
                'analysis_credits': 0,
                'tier': 'free',
                'alerts_enabled': True
            }
        })
    except sqlite3.IntegrityError:
        return jsonify({'success': False, 'message': 'User already exists'}), 400

@app.route('/auth/login', methods=['POST'])
def login():
    data = request.json
    conn = sqlite3.connect('portfolio.db')
    conn.row_factory = dict_factory
    c = conn.cursor()
    user = c.execute("SELECT * FROM users WHERE email = ?", (data.get('email'),)).fetchone()
    conn.close()
    
    if user and check_password_hash(user['password'], data.get('password')):
        return jsonify({
            'success': True,
            'user': {
                'user_id': str(user['id']),
                'email': user['email'],
                'trials_remaining': user['trials_remaining'],
                'analysis_credits': user['analysis_credits'],
                'tier': user['tier'],
                'alerts_enabled': bool(user['alerts_enabled'])
            }
        })
    return jsonify({'success': False, 'message': 'Invalid credentials'}), 401

@app.route('/auth/google', methods=['POST'])
def google_login():
    # For production, verify the Google ID token
    # For now, simplified implementation
    data = request.json
    email = data.get('email', 'google_user@example.com')
    
    conn = sqlite3.connect('portfolio.db')
    conn.row_factory = dict_factory
    c = conn.cursor()
    
    user = c.execute("SELECT * FROM users WHERE email = ?", (email,)).fetchone()
    
    if not user:
        # Create new user
        c.execute("INSERT INTO users (email, password) VALUES (?, ?)", 
                 (email, generate_password_hash('google_oauth')))
        conn.commit()
        user_id = c.lastrowid
        user = {
            'id': user_id,
            'email': email,
            'trials_remaining': 5,
            'analysis_credits': 0,
            'tier': 'free',
            'alerts_enabled': 1
        }
    
    conn.close()
    
    return jsonify({
        'success': True,
        'user': {
            'user_id': str(user['id']),
            'email': user['email'],
            'trials_remaining': user['trials_remaining'],
            'analysis_credits': user['analysis_credits'],
            'tier': user['tier'],
            'alerts_enabled': bool(user['alerts_enabled'])
        }
    })

# === INVESTMENT ROUTES ===

@app.route('/api/investments/<user_id>', methods=['GET'])
def get_investments(user_id):
    conn = sqlite3.connect('portfolio.db')
    conn.row_factory = dict_factory
    c = conn.cursor()
    
    investments = c.execute(
        "SELECT * FROM investments WHERE user_id = ? ORDER BY created_at DESC",
        (user_id,)
    ).fetchall()
    
    conn.close()
    
    return jsonify({'success': True, 'investments': investments})

@app.route('/api/investments', methods=['POST'])
def add_investment():
    data = request.json
    user_id = data.get('user_id')
    
    conn = sqlite3.connect('portfolio.db')
    c = conn.cursor()
    
    c.execute('''INSERT INTO investments 
                 (id, user_id, name, type, quantity, purchase_price, current_price, 
                  currency, purchase_date, platform, country, sector, maturity_date, 
                  notes, created_at)
                 VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
              (data.get('id'), user_id, data.get('name'), data.get('type'),
               data.get('quantity'), data.get('purchase_price'), data.get('current_price'),
               data.get('currency', 'USD'), data.get('purchase_date'),
               data.get('platform'), data.get('country'), data.get('sector'),
               data.get('maturity_date'), data.get('notes'),
               datetime.now().isoformat()))
    
    conn.commit()
    conn.close()
    
    return jsonify({'success': True, 'message': 'Investment added'})

@app.route('/api/investments/<investment_id>', methods=['PUT'])
def update_investment(investment_id):
    data = request.json
    
    conn = sqlite3.connect('portfolio.db')
    c = conn.cursor()
    
    c.execute('''UPDATE investments SET 
                 name=?, type=?, quantity=?, purchase_price=?, current_price=?,
                 currency=?, purchase_date=?, platform=?, country=?, sector=?,
                 maturity_date=?, notes=?
                 WHERE id=?''',
              (data.get('name'), data.get('type'), data.get('quantity'),
               data.get('purchase_price'), data.get('current_price'),
               data.get('currency'), data.get('purchase_date'),
               data.get('platform'), data.get('country'), data.get('sector'),
               data.get('maturity_date'), data.get('notes'), investment_id))
    
    conn.commit()
    conn.close()
    
    return jsonify({'success': True, 'message': 'Investment updated'})

@app.route('/api/investments/<investment_id>', methods=['DELETE'])
def delete_investment(investment_id):
    conn = sqlite3.connect('portfolio.db')
    c = conn.cursor()
    c.execute("DELETE FROM investments WHERE id=?", (investment_id,))
    conn.commit()
    conn.close()
    
    return jsonify({'success': True, 'message': 'Investment deleted'})

# === AI-POWERED ROUTES ===

@app.route('/api/get-price', methods=['POST'])
def get_asset_price():
    """Fetch real-time price using Gemini 3 Flash with Google Search grounding"""
    data = request.json
    asset_name = data.get('asset_name')
    asset_type = data.get('asset_type')
    
    try:
        # Use Gemini 3 Flash with Google Search for real-time price
        response = client.models.generate_content(
            model="gemini-3-flash-preview",
            contents=f"What is the current price of {asset_name} ({asset_type})? Return ONLY the numeric price value in USD.",
            config=types.GenerateContentConfig(
                tools=[{"google_search": {}}],
                thinking_config=types.ThinkingConfig(thinking_level="low"),
                response_mime_type="application/json"
            )
        )
        
        # Parse response to extract price
        price_data = json.loads(response.text)
        price = float(price_data.get('price', 0))
        
        return jsonify({
            'success': True,
            'price': price,
            'asset_name': asset_name
        })
    
    except Exception as e:
        return jsonify({
            'success': False,
            'message': f'Could not fetch price: {str(e)}'
        })

@app.route('/api/update-prices', methods=['POST'])
def update_prices():
    """Update prices for all listed assets using AI"""
    data = request.json
    user_id = data.get('user_id')
    
    conn = sqlite3.connect('portfolio.db')
    conn.row_factory = dict_factory
    c = conn.cursor()
    
    # Get all investments that need price updates
    investments = c.execute(
        "SELECT * FROM investments WHERE user_id = ? AND type IN ('stock', 'crypto', 'gold')",
        (user_id,)
    ).fetchall()
    
    updated_count = 0
    
    for inv in investments:
        try:
            # Use Gemini to fetch current price
            response = client.models.generate_content(
                model="gemini-3-flash-preview",
                contents=f"Current price of {inv['name']} in USD (just the number):",
                config=types.GenerateContentConfig(
                    tools=[{"google_search": {}}],
                    thinking_config=types.ThinkingConfig(thinking_level="minimal")
                )
            )
            
            # Extract numeric price
            price_text = response.text.strip()
            # Remove currency symbols and commas
            price_text = price_text.replace('$', '').replace(',', '')
            current_price = float(price_text)
            
            # Update database
            c.execute(
                "UPDATE investments SET current_price = ? WHERE id = ?",
                (current_price, inv['id'])
            )
            updated_count += 1
            
        except Exception as e:
            print(f"Error updating {inv['name']}: {e}")
            continue
    
    conn.commit()
    conn.close()
    
    return jsonify({
        'success': True,
        'updated_count': updated_count,
        'message': f'Updated {updated_count} investments'
    })

@app.route('/api/analyze-portfolio', methods=['POST'])
def analyze_portfolio():
    """AI-powered portfolio analysis using Gemini 3 Flash with high thinking"""
    data = request.json
    user_id = data.get('user_id')
    
    conn = sqlite3.connect('portfolio.db')
    conn.row_factory = dict_factory
    c = conn.cursor()
    
    # Get all investments
    investments = c.execute(
        "SELECT * FROM investments WHERE user_id = ?",
        (user_id,)
    ).fetchall()
    
    conn.close()
    
    if not investments:
        return jsonify({
            'success': False,
            'message': 'No investments to analyze'
        })
    
    # Prepare portfolio data for AI
    portfolio_summary = []
    total_value = 0
    total_cost = 0
    
    for inv in investments:
        inv_value = inv['quantity'] * inv['current_price']
        inv_cost = inv['quantity'] * inv['purchase_price']
        total_value += inv_value
        total_cost += inv_cost
        
        portfolio_summary.append({
            'name': inv['name'],
            'type': inv['type'],
            'value': inv_value,
            'cost': inv_cost,
            'country': inv['country'],
            'sector': inv['sector']
        })
    
    # Use Gemini 3 Flash with high thinking for deep analysis
    analysis_prompt = f"""
    Analyze this investment portfolio and provide detailed insights:
    
    Portfolio Data:
    {json.dumps(portfolio_summary, indent=2)}
    
    Total Portfolio Value: ${total_value:.2f}
    Total Investment Cost: ${total_cost:.2f}
    
    Please provide:
    1. Risk level assessment (Low, Medium, High, Very High)
    2. Country exposure breakdown (percentage for each country)
    3. Sector exposure breakdown (percentage for each sector)
    4. Asset allocation breakdown (percentage for each asset type)
    5. At least 5 specific recommendations to improve diversification
    
    Return a JSON object with this structure:
    {{
        "risk_level": "...",
        "country_exposure": {{"country": percentage, ...}},
        "sector_exposure": {{"sector": percentage, ...}},
        "asset_allocation": {{"type": percentage, ...}},
        "recommendations": ["...", "...", ...]
    }}
    """
    
    try:
        response = client.models.generate_content(
            model="gemini-3-flash-preview",
            contents=analysis_prompt,
            config=types.GenerateContentConfig(
                thinking_config=types.ThinkingConfig(thinking_level="high"),
                response_mime_type="application/json",
                tools=[
                    types.Tool(code_execution=types.ToolCodeExecution())
                ]
            )
        )
        
        analysis_data = json.loads(response.text)
        
        # Add calculated totals
        analysis_data['total_value'] = total_value
        analysis_data['total_cost'] = total_cost
        analysis_data['total_profit_loss'] = total_value - total_cost
        
        return jsonify({
            'success': True,
            'analysis': analysis_data
        })
    
    except Exception as e:
        return jsonify({
            'success': False,
            'message': f'Analysis failed: {str(e)}'
        })

# === HEALTH CHECK ===

@app.route('/health', methods=['GET'])
def health_check():
    return jsonify({
        'status': 'healthy',
        'service': 'PortfolioMaster API',
        'timestamp': datetime.now().isoformat()
    })

if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=5000)