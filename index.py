from flask import Flask, request, jsonify, make_response

app = Flask(__name__)

def add_cors_headers(response):
    response.headers['Access-Control-Allow-Origin'] = '*'
    response.headers['Access-Control-Allow-Headers'] = 'Content-Type'
    response.headers['Access-Control-Allow-Methods'] = 'GET, POST, OPTIONS'
    return response

app.after_request(add_cors_headers)

@app.route('/bestmove', methods=['GET', 'OPTIONS'])
def bestmove():
    if request.method == 'OPTIONS':
        return jsonify({}), 200
    # ... بقیه کد مانند قبل ...
