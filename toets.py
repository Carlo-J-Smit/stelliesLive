import requests

url = "http://127.0.0.1:8000/event/"
data = {
    "venue": "Bohemia",
    "name": "toets",
    "date": "2025-03-15",
    "type": "A live music concert."
}

response = requests.post(url, json=data)
print(response.json())
