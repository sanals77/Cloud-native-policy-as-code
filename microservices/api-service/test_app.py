"""
Unit tests for API service
"""
import unittest
from unittest.mock import patch, MagicMock
import json
from app import app


class TestAPIService(unittest.TestCase):

    def setUp(self):
        self.app = app.test_client()
        self.app.testing = True

    def test_health_endpoint(self):
        """Test health check endpoint"""
        response = self.app.get('/health')
        self.assertEqual(response.status_code, 200)
        data = json.loads(response.data)
        self.assertEqual(data['status'], 'healthy')
        self.assertEqual(data['service'], 'api-service')

    @patch('app.get_db_connection')
    def test_ready_endpoint_success(self, mock_db):
        """Test readiness probe when database is available"""
        mock_conn = MagicMock()
        mock_db.return_value = mock_conn

        response = self.app.get('/ready')
        self.assertEqual(response.status_code, 200)
        data = json.loads(response.data)
        self.assertEqual(data['status'], 'ready')

    @patch('app.get_db_connection')
    def test_ready_endpoint_failure(self, mock_db):
        """Test readiness probe when database is unavailable"""
        mock_db.return_value = None

        response = self.app.get('/ready')
        self.assertEqual(response.status_code, 503)
        data = json.loads(response.data)
        self.assertEqual(data['status'], 'not ready')

    @patch('app.get_db_connection')
    def test_get_items(self, mock_db):
        """Test getting items from database"""
        mock_conn = MagicMock()
        mock_cursor = MagicMock()
        mock_cursor.fetchall.return_value = [
            (1, 'Item 1', 'Description 1', None),
            (2, 'Item 2', 'Description 2', None)
        ]
        mock_conn.cursor.return_value = mock_cursor
        mock_db.return_value = mock_conn

        response = self.app.get('/api/items')
        self.assertEqual(response.status_code, 200)
        data = json.loads(response.data)
        self.assertEqual(len(data['items']), 2)

    @patch('app.get_db_connection')
    def test_metrics_endpoint(self, mock_db):
        """Test metrics endpoint"""
        mock_conn = MagicMock()
        mock_cursor = MagicMock()
        mock_cursor.fetchone.return_value = (5,)
        mock_conn.cursor.return_value = mock_cursor
        mock_db.return_value = mock_conn

        response = self.app.get('/metrics')
        self.assertEqual(response.status_code, 200)
        # Metrics endpoint returns Prometheus format, not JSON
        self.assertIn(b'api_items_total', response.data)


if __name__ == '__main__':
    unittest.main()

