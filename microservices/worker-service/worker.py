"""
Background Worker Microservice - Cloud Native Application
Processes background tasks and data cleanup operations
"""
import psycopg2
import os
import time
import logging
from datetime import datetime, timedelta

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Database configuration from environment variables
DB_CONFIG = {
    'host': os.getenv('DB_HOST', 'localhost'),
    'port': os.getenv('DB_PORT', '5432'),
    'database': os.getenv('DB_NAME', 'appdb'),
    'user': os.getenv('DB_USER', 'postgres'),
    'password': os.getenv('DB_PASSWORD', 'postgres'),
    'sslmode': 'require',
    'connect_timeout': 10
}

# Worker configuration
WORKER_INTERVAL = int(os.getenv('WORKER_INTERVAL', '60'))  # seconds
CLEANUP_DAYS = int(os.getenv('CLEANUP_DAYS', '30'))  # days


def get_db_connection():
    """Establish database connection"""
    try:
        conn = psycopg2.connect(**DB_CONFIG)
        return conn
    except Exception as e:
        logger.error(f"Database connection failed: {e}")
        return None


def cleanup_old_items():
    """Remove items older than specified days"""
    conn = get_db_connection()
    if not conn:
        logger.error("Cannot perform cleanup - database unavailable")
        return

    try:
        cur = conn.cursor()
        cleanup_date = datetime.now() - timedelta(days=CLEANUP_DAYS)

        cur.execute(
            'DELETE FROM items WHERE created_at < %s',
            (cleanup_date,)
        )
        deleted_count = cur.rowcount
        conn.commit()

        logger.info(f"Cleanup complete: {deleted_count} items removed")

        cur.close()
        conn.close()
    except Exception as e:
        logger.error(f"Error during cleanup: {e}")
        if conn:
            conn.close()


def process_pending_tasks():
    """Process any pending background tasks"""
    conn = get_db_connection()
    if not conn:
        logger.error("Cannot process tasks - database unavailable")
        return

    try:
        cur = conn.cursor()

        # Example: Update statistics or process queued items
        cur.execute('SELECT COUNT(*) FROM items')
        item_count = cur.fetchone()[0]

        logger.info(f"Current item count: {item_count}")

        cur.close()
        conn.close()
    except Exception as e:
        logger.error(f"Error processing tasks: {e}")
        if conn:
            conn.close()


def initialize_database():
    """Initialize database schema if needed"""
    conn = get_db_connection()
    if not conn:
        logger.error("Cannot initialize database - connection unavailable")
        return False

    try:
        cur = conn.cursor()

        # Create items table if it doesn't exist
        cur.execute('''
            CREATE TABLE IF NOT EXISTS items (
                id SERIAL PRIMARY KEY,
                name VARCHAR(255) NOT NULL,
                description TEXT,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        ''')

        # Create index for better query performance
        cur.execute('''
            CREATE INDEX IF NOT EXISTS idx_items_created_at
            ON items(created_at)
        ''')

        conn.commit()
        logger.info("Database schema initialized successfully")

        cur.close()
        conn.close()
        return True
    except Exception as e:
        logger.error(f"Error initializing database: {e}")
        if conn:
            conn.close()
        return False


def run_worker():
    """Main worker loop"""
    logger.info("Background worker starting...")
    logger.info(f"Worker interval: {WORKER_INTERVAL} seconds")
    logger.info(f"Cleanup threshold: {CLEANUP_DAYS} days")

    # Initialize database on startup
    if not initialize_database():
        logger.error("Failed to initialize database. Retrying...")
        time.sleep(10)
        initialize_database()

    iteration = 0

    while True:
        try:
            iteration += 1
            logger.info(f"Worker iteration {iteration} starting...")

            # Process pending tasks
            process_pending_tasks()

            # Cleanup old items (every 10 iterations)
            if iteration % 10 == 0:
                cleanup_old_items()

            logger.info(f"Worker iteration {iteration} completed")

        except Exception as e:
            logger.error(f"Error in worker loop: {e}")

        # Wait before next iteration
        time.sleep(WORKER_INTERVAL)


if __name__ == '__main__':
    run_worker()
