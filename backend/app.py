import sys, os, traceback, uuid
from flask import Flask, request, jsonify, send_from_directory

IS_VERCEL = os.environ.get('VERCEL') is not None
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from chess_engine.board import Board
from chess_engine.search import Search

app = Flask(__name__,
            static_folder='../frontend' if not IS_VERCEL else None,
            static_url_path='' if not IS_VERCEL else None)

# حافظهٔ موقت سرور برای نگهداری state کاربران
sessions = {}

@app.after_request
def add_cors(response):
    response.headers['Access-Control-Allow-Origin'] = '*'
    response.headers['Access-Control-Allow-Headers'] = 'Content-Type'
    response.headers['Access-Control-Allow-Methods'] = 'GET, POST, PUT, OPTIONS'
    return response

# ── endpointهای session ──
@app.route('/api/session', methods=['POST'])
def create_session():
    sid = str(uuid.uuid4())
    sessions[sid] = {
        'fen': 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
        'history': [],
        'level': 1, 'wins': 0, 'bonusPoints': 0,
        'userColor': 'w'
    }
    return jsonify({'session_id': sid})

@app.route('/api/session/<sid>', methods=['GET'])
def get_session(sid):
    if sid in sessions:
        return jsonify(sessions[sid])
    return jsonify({'error': 'Session not found'}), 404

@app.route('/api/session/<sid>', methods=['PUT'])
def update_session(sid):
    data = request.get_json()
    if sid in sessions:
        sessions[sid].update(data)
        return jsonify({'status': 'ok'})
    return jsonify({'error': 'Session not found'}), 404

# ── endpoint بهترین حرکت (همان قبلی) ──
@app.route('/api/bestmove', methods=['GET', 'OPTIONS'])
def bestmove():
    if request.method == 'OPTIONS':
        return jsonify({}), 200
    fen = request.args.get('fen', 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1')
    depth = min(int(request.args.get('depth', 3)), 3)
    try:
        board = Board(fen)
        search = Search(board)
        search.search(depth)
        move = search.best_move
        if move:
            from_sq, to_sq, promo = move
            promo_str = ''
            if promo: promo_str = 'nbrq'[promo-2]
            from chess_engine.bitboard import square_to_str
            move_str = square_to_str(from_sq) + square_to_str(to_sq) + promo_str
        else:
            move_str = None
        return jsonify({'bestmove': move_str, 'depth': depth, 'nodes': search.nodes})
    except Exception:
        return jsonify({'error': traceback.format_exc()}), 500

# سرو فایل‌های استاتیک در حالت لوکال
if not IS_VERCEL:
    @app.route('/')
    def index():
        return send_from_directory('../frontend', 'index.html')
    @app.route('/<path:path>')
    def serve_static(path):
        return send_from_directory('../frontend', path)

if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=5000)
