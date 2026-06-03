#!/usr/bin/env bash
# final_fix.sh – رفع کامل Not Found و یخ‌زدگی + آماده‌سازی برای Vercel و تست محلی

cd ~/chess-engine

# ────────────── 1. api/index.py (هم API هم static برای تست محلی) ──────────────
cat > api/index.py << 'EOF'
import os, sys, traceback
from flask import Flask, request, jsonify, send_from_directory

# تشخیص محیط: اگر روی Vercel نباشیم، فایل‌های استاتیک را هم سرو می‌کنیم
IS_VERCEL = os.environ.get('VERCEL') is not None

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from chess_engine.board import Board
from chess_engine.search import Search

app = Flask(__name__,
            static_folder='../public' if not IS_VERCEL else None,
            static_url_path='' if not IS_VERCEL else None)

# CORS
@app.after_request
def add_cors(response):
    response.headers['Access-Control-Allow-Origin'] = '*'
    response.headers['Access-Control-Allow-Headers'] = 'Content-Type'
    response.headers['Access-Control-Allow-Methods'] = 'GET, POST, OPTIONS'
    return response

# API endpoint
@app.route('/api/bestmove', methods=['GET', 'OPTIONS'])
def bestmove():
    if request.method == 'OPTIONS':
        return jsonify({}), 200
    fen = request.args.get('fen', 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1')
    depth = min(int(request.args.get('depth', 2)), 3)   # حداکثر ۳ برای سرعت
    try:
        board = Board(fen)
        search = Search(board)
        search.search(depth)
        move = search.best_move
        if move:
            from_sq, to_sq, promo = move
            promo_str = ''
            if promo:
                promo_str = 'nbrq'[promo-2]
            from chess_engine.bitboard import square_to_str
            move_str = square_to_str(from_sq) + square_to_str(to_sq) + promo_str
        else:
            move_str = None
        return jsonify({'bestmove': move_str, 'depth': depth, 'nodes': search.nodes})
    except Exception:
        return jsonify({'error': traceback.format_exc()}), 500

# فقط در محیط محلی: سرو فایل‌های استاتیک
if not IS_VERCEL:
    @app.route('/')
    def index():
        return send_from_directory('../public', 'index.html')

    @app.route('/<path:path>')
    def serve_static(path):
        return send_from_directory('../public', path)

if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=5000)
EOF

# ────────────── 2. vercel.json (تفکیک صحیح) ──────────────
cat > vercel.json << 'EOF'
{
  "builds": [
    { "src": "api/index.py", "use": "@vercel/python" },
    { "src": "public/**", "use": "@vercel/static" }
  ],
  "routes": [
    { "src": "/api/(.*)", "dest": "api/index.py" },
    { "src": "/", "dest": "public/index.html" },
    { "src": "/(.*)", "dest": "public/$1" }
  ]
}
EOF

# ────────────── 3. public/script.js (با timeout و عمق کم) ──────────────
cat > public/script.js << 'EOF'
const API_URL = "/api/bestmove";
let board = null;
let game = new Chess();
let playerColor = 'w';
let isThinking = false;

function initBoard() {
    board = Chessboard('board', {
        draggable: true,
        position: 'start',
        orientation: playerColor,
        onDragStart: onDragStart,
        onDrop: onDrop,
        onSnapEnd: onSnapEnd,
        pieceTheme: 'https://chessboardjs.com/img/chesspieces/wikipedia/{piece}.png'
    });
    updateStatus();
}

function onDragStart(source, piece, position, orientation) {
    if (game.game_over() || isThinking || game.turn() !== playerColor) return false;
}

function onDrop(source, target) {
    const move = game.move({
        from: source,
        to: target,
        promotion: 'q'
    });
    if (move === null) return 'snapback';
    updateStatus();
    setTimeout(makeAIMove, 300);
}

function onSnapEnd() { board.position(game.fen()); }

async function makeAIMove() {
    if (game.game_over() || isThinking) return;
    isThinking = true;
    $('#status').text('در حال فکر کردن...');
    try {
        const controller = new AbortController();
        const timeout = setTimeout(() => controller.abort(), 8000);
        const resp = await fetch(`${API_URL}?fen=${encodeURIComponent(game.fen())}&depth=2`, {
            signal: controller.signal
        });
        clearTimeout(timeout);
        const data = await resp.json();
        if (data.error) {
            throw new Error(data.error);
        }
        if (data.bestmove) {
            const from = data.bestmove.substring(0,2);
            const to = data.bestmove.substring(2,4);
            const promo = data.bestmove.length > 4 ? data.bestmove[4] : undefined;
            game.move({ from, to, promotion: promo });
            board.position(game.fen());
        }
    } catch (e) {
        console.error(e);
        $('#status').text('خطا در دریافت حرکت از سرور');
    }
    isThinking = false;
    updateStatus();
}

function updateStatus() {
    let status = '';
    if (game.in_checkmate()) {
        status = game.turn() === playerColor ? 'کیش و مات! شما باختید.' : 'کیش و مات! شما برنده شدید.';
    } else if (game.in_draw()) {
        status = 'مساوی';
    } else {
        status = 'نوبت ' + (game.turn() === 'w' ? 'سفید' : 'سیاه');
    }
    $('#status').text(status);
}

$('#newGameBtn').click(() => { game.reset(); board.start(); isThinking = false; updateStatus(); });
$('#flipBtn').click(() => {
    playerColor = playerColor === 'w' ? 'b' : 'w';
    board.orientation(playerColor);
    updateStatus();
});

$(document).ready(initBoard);
EOF

echo ""
echo "✅ همه فایل‌ها اصلاح شدند."
echo ""
echo "🚀 برای تست محلی:"
echo "  python api/index.py"
echo "  سپس مرورگر را به http://localhost:5000 ببرید."
echo ""
echo "☁️ برای انتشار در Vercel:"
echo "  git add -A && git commit -m 'Final fix: static serving + anti-freeze' && git push"
