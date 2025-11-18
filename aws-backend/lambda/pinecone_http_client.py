"""
Pinecone HTTP Client - Direct API calls without heavy dependencies
Uses only requests library to avoid numpy/compilation issues
"""

import requests
import json


class PineconeHTTPClient:
    """Direct HTTP client for Pinecone API"""

    def __init__(self, api_key, environment='us-east-1-aws'):
        self.api_key = api_key
        self.environment = environment
        self.headers = {
            'Api-Key': api_key,
            'Content-Type': 'application/json'
        }

    def list_indexes(self):
        """List all indexes"""
        url = f'https://api.pinecone.io/indexes'
        response = requests.get(url, headers=self.headers)
        response.raise_for_status()
        return response.json()

    def create_index(self, name, dimension=1536, metric='cosine', cloud='aws', region='us-east-1'):
        """Create a new index"""
        url = f'https://api.pinecone.io/indexes'
        data = {
            'name': name,
            'dimension': dimension,
            'metric': metric,
            'spec': {
                'serverless': {
                    'cloud': cloud,
                    'region': region
                }
            }
        }
        response = requests.post(url, headers=self.headers, json=data)
        response.raise_for_status()
        return response.json()

    def describe_index(self, index_name):
        """Get index details"""
        url = f'https://api.pinecone.io/indexes/{index_name}'
        response = requests.get(url, headers=self.headers)
        response.raise_for_status()
        return response.json()

    def get_index_host(self, index_name):
        """Get the host URL for an index"""
        index_info = self.describe_index(index_name)
        return index_info.get('host')

    def upsert_vectors(self, index_name, vectors, namespace=''):
        """Upsert vectors to index"""
        host = self.get_index_host(index_name)
        url = f'https://{host}/vectors/upsert'

        data = {
            'vectors': vectors,
            'namespace': namespace
        }

        response = requests.post(url, headers=self.headers, json=data)
        response.raise_for_status()
        return response.json()

    def query(self, index_name, vector, top_k=5, namespace='', include_metadata=True, filter_dict=None):
        """Query vectors"""
        host = self.get_index_host(index_name)
        url = f'https://{host}/query'

        data = {
            'vector': vector,
            'topK': top_k,
            'namespace': namespace,
            'includeMetadata': include_metadata
        }

        if filter_dict:
            data['filter'] = filter_dict

        response = requests.post(url, headers=self.headers, json=data)
        response.raise_for_status()
        return response.json()

    def delete_vectors(self, index_name, ids, namespace=''):
        """Delete vectors by ID"""
        host = self.get_index_host(index_name)
        url = f'https://{host}/vectors/delete'

        data = {
            'ids': ids,
            'namespace': namespace
        }

        response = requests.post(url, headers=self.headers, json=data)
        response.raise_for_status()
        return response.json()

    def describe_index_stats(self, index_name):
        """Get index statistics"""
        host = self.get_index_host(index_name)
        url = f'https://{host}/describe_index_stats'

        response = requests.post(url, headers=self.headers, json={})
        response.raise_for_status()
        return response.json()
