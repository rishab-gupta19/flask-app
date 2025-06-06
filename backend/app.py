import os
import psycopg2
from flask import Flask, request, jsonify
from dotenv import load_dotenv
from flask_cors import CORS

load_dotenv()

app = Flask(__name__)
CORS(app)
# Load env variables
DB_USER = os.getenv('DB_USER')
DB_PASSWORD = os.getenv('DB_PASSWORD')
DB_HOST = os.getenv('DB_HOST')
DB_PORT = os.getenv('DB_PORT')
DB_NAME = os.getenv('DB_NAME')

def get_conn():
    return psycopg2.connect(
        dbname=DB_NAME,
        user=DB_USER,
        password=DB_PASSWORD,
        host=DB_HOST,
        port=DB_PORT
    )

# Create table
def init_db():
    with get_conn() as conn:
        with conn.cursor() as cur:
            cur.execute('''
                CREATE TABLE IF NOT EXISTS products (
                    id SERIAL PRIMARY KEY,
                    name VARCHAR(100) NOT NULL,
                    description TEXT,
                    price FLOAT NOT NULL,
                    image_url VARCHAR(255)
                );
            ''')
        conn.commit()

# /health
@app.route('/health', methods=['GET'])
def health_check():
    try:
        with get_conn() as conn:
            with conn.cursor() as cur:
                cur.execute('SELECT 1')
        return jsonify({'status': 'ok', 'db': 'connected'}), 200
    except Exception as e:
        return jsonify({'status': 'fail', 'error': str(e)}), 500

@app.route('/api/products', methods=['GET', 'POST'])
def products():
    if request.method == 'GET':
        with get_conn() as conn:
            with conn.cursor() as cur:
                cur.execute('SELECT id, name, description, price, image_url FROM products')
                rows = cur.fetchall()
                products = [
                    {
                        'id': row[0],
                        'name': row[1],
                        'description': row[2],
                        'price': row[3],
                        'image_url': row[4]
                    } for row in rows
                ]
                return jsonify(products), 200

    elif request.method == 'POST':
        data = request.get_json()
        required_fields = ('name', 'description', 'price', 'image_url')
        if not all(field in data for field in required_fields):
            return jsonify({'error': 'Missing fields'}), 400

        with get_conn() as conn:
            with conn.cursor() as cur:
                cur.execute('''
                    INSERT INTO products (name, description, price, image_url)
                    VALUES (%s, %s, %s, %s)
                    RETURNING id
                ''', (data['name'], data['description'], data['price'], data['image_url']))
                product_id = cur.fetchone()[0]
            conn.commit()

        return jsonify({'message': 'Product added', 'product_id': product_id}), 201

init_db()

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)

