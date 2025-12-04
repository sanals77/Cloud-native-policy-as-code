"""
REST API Microservice - Cloud Native Application
Provides RESTful endpoints with health checks and database connectivity
"""
from flask import Flask, jsonify, request
from flask_cors import CORS
from prometheus_client import (
    Counter, Histogram, Gauge,
    generate_latest, CONTENT_TYPE_LATEST
)
from functools import wraps
import psycopg2
import os
import logging
import time
from datetime import datetime

app = Flask(__name__)
CORS(app)

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Prometheus metrics
REQUEST_COUNT = Counter(
    'api_requests_total',
    'Total API requests',
    ['method', 'endpoint', 'status']
)
REQUEST_DURATION = Histogram(
    'api_request_duration_seconds',
    'API request duration',
    ['method', 'endpoint']
)
DB_CONNECTIONS = Gauge(
    'api_db_connections_active',
    'Active database connections'
)
ITEMS_TOTAL = Gauge('api_items_total', 'Total items in database')


def track_request_time(f):
    """Decorator to track request duration"""
    @wraps(f)
    def decorated_function(*args, **kwargs):
        start_time = time.time()
        try:
            result = f(*args, **kwargs)
            duration = time.time() - start_time
            REQUEST_DURATION.labels(
                method=request.method,
                endpoint=request.path
            ).observe(duration)
            return result
        except Exception:
            duration = time.time() - start_time
            REQUEST_DURATION.labels(
                method=request.method,
                endpoint=request.path
            ).observe(duration)
            raise
    return decorated_function


# Database configuration from environment variables
DB_CONFIG = {
    'host': os.getenv('DB_HOST', 'localhost'),
    'port': os.getenv('DB_PORT', '5432'),
    'database': os.getenv('DB_NAME', 'appdb'),
    'user': os.getenv('DB_USER', 'postgres'),
    'password': os.getenv('DB_PASSWORD', 'postgres'),
    'sslmode': 'require',
    'connect_timeout': 5
}


def get_db_connection():
    """Establish database connection"""
    try:
        conn = psycopg2.connect(**DB_CONFIG)
        return conn
    except Exception as e:
        logger.error(f"Database connection failed: {e}")
        return None


@app.route('/health', methods=['GET'])
def health():
    """Health check endpoint"""
    return jsonify({
        'status': 'healthy',
        'service': 'api-service',
        'timestamp': datetime.utcnow().isoformat()
    }), 200


@app.route('/ready', methods=['GET'])
def ready():
    """Readiness probe - checks database connectivity"""
    conn = get_db_connection()
    if conn:
        conn.close()
        return jsonify({
            'status': 'ready',
            'database': 'connected'
        }), 200
    else:
        return jsonify({
            'status': 'not ready',
            'database': 'disconnected'
        }), 503


@app.route('/api/items', methods=['GET'])
@track_request_time
def get_items():
    """Get all items from database"""
    REQUEST_COUNT.labels(
        method='GET',
        endpoint='/api/items',
        status='success'
    ).inc()

    conn = get_db_connection()
    if not conn:
        REQUEST_COUNT.labels(
            method='GET',
            endpoint='/api/items',
            status='error'
        ).inc()
        return jsonify({'error': 'Database unavailable'}), 503

    try:
        cur = conn.cursor()
        cur.execute(
            'SELECT id, name, description, created_at FROM items '
            'ORDER BY created_at DESC'
        )
        items = cur.fetchall()
        cur.close()
        conn.close()

        return jsonify({
            'items': [
                {
                    'id': item[0],
                    'name': item[1],
                    'description': item[2],
                    'created_at': item[3].isoformat() if item[3] else None
                }
                for item in items
            ]
        }), 200
    except Exception as e:
        logger.error(f"Error fetching items: {e}")
        return jsonify({'error': 'Failed to fetch items'}), 500


@app.route('/api/items', methods=['POST'])
@track_request_time
def create_item():
    """Create a new item"""
    REQUEST_COUNT.labels(
        method='POST',
        endpoint='/api/items',
        status='success'
    ).inc()

    data = request.get_json(force=True)

    if not data or 'name' not in data:
        REQUEST_COUNT.labels(
            method='POST',
            endpoint='/api/items',
            status='error'
        ).inc()
        return jsonify({'error': 'Name is required'}), 400

    conn = get_db_connection()
    if not conn:
        return jsonify({'error': 'Database unavailable'}), 503

    try:
        cur = conn.cursor()
        cur.execute(
            'INSERT INTO items (name, description) VALUES (%s, %s) '
            'RETURNING id',
            (data['name'], data.get('description', ''))
        )
        item_id = cur.fetchone()[0]
        conn.commit()
        cur.close()
        conn.close()

        return jsonify({
            'id': item_id,
            'message': 'Item created successfully'
        }), 201
    except Exception as e:
        logger.error(f"Error creating item: {e}")
        return jsonify({'error': 'Failed to create item'}), 500


@app.route('/api/items/<int:item_id>', methods=['DELETE'])
def delete_item(item_id):
    """Delete an item"""
    conn = get_db_connection()
    if not conn:
        return jsonify({'error': 'Database unavailable'}), 503

    try:
        cur = conn.cursor()
        cur.execute('DELETE FROM items WHERE id = %s', (item_id,))
        conn.commit()
        cur.close()
        conn.close()

        return jsonify({'message': 'Item deleted successfully'}), 200
    except Exception as e:
        logger.error(f"Error deleting item: {e}")
        return jsonify({'error': 'Failed to delete item'}), 500


@app.route('/metrics', methods=['GET'])
def metrics():
    """Prometheus metrics endpoint"""
    # Update item count gauge
    conn = get_db_connection()
    if conn:
        try:
            cur = conn.cursor()
            cur.execute('SELECT COUNT(*) FROM items')
            count = cur.fetchone()[0]
            ITEMS_TOTAL.set(count)
            cur.close()
            conn.close()
        except Exception:
            pass

    return generate_latest(), 200, {'Content-Type': CONTENT_TYPE_LATEST}


if __name__ == '__main__':
    port = int(os.getenv('PORT', 8080))
    app.run(host='0.0.0.0', port=port)
