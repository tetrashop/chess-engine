#!/usr/bin/env bash
# setup_gui.sh – ChessEnginePy GUI & AI connection setup

cd ~/chess-engine

# Create directories
mkdir -p public api

# ────────────── api/index.py (Flask app with static serving) ──────────────
cat > api/index.py << 'EOF'
import os
from flask import Flask, request, jsonify, send_from_directory
import sys
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from chess_engine.board import Board
from chess_engine.search import Search

app = Flask(__name__, static_folder='../public', static_url_path='')

# CORS headers
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
    depth = int(request.args.get('depth', 4))
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
        return jsonify({
            'bestmove': move_str,
            'fen': fen,
            'depth': depth,
            'nodes': search.nodes
        })
    except Exception as e:
        return jsonify({'error': str(e)}), 400

# Serve static files (index.html, etc.)
@app.route('/')
def index():
    return send_from_directory(app.static_folder, 'index.html')

@app.route('/<path:path>')
def serve_static(path):
    return send_from_directory(app.static_folder, path)

if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=5000)
EOF

# ────────────── api/requirements.txt ──────────────
echo "flask" > api/requirements.txt

# ────────────── public/index.html ──────────────
cat > public/index.html << 'EOF'
<!DOCTYPE html>
<html lang="fa" dir="rtl">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>ChessEnginePy – بازی شطرنج با هوش مصنوعی</title>
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/chessboard-js/1.0.0/chessboard-1.0.0.min.css">
    <link rel="stylesheet" href="/style.css">
</head>
<body>
    <div class="container">
        <h1>♟️ ChessEnginePy</h1>
        <div id="board" style="width: 400px; margin: 0 auto;"></div>
        <div class="controls">
            <button id="newGameBtn">🔄 بازی جدید</button>
            <button id="flipBtn">🔃 چرخاندن صفحه</button>
        </div>
        <div id="status">نوبت شما (سفید)</div>
    </div>

    <script src="https://code.jquery.com/jquery-3.6.0.min.js"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/chess.js/0.10.3/chess.min.js"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/chessboard-js/1.0.0/chessboard-1.0.0.min.js"></script>
    <script src="/script.js"></script>
</body>
</html>
EOF

# ────────────── public/style.css ──────────────
cat > public/style.css << 'EOF'
body {
    margin: 0; padding: 20px;
    background-color: #2e2e2e; color: #f0d9b5;
    font-family: Tahoma, sans-serif;
    display: flex; justify-content: center;
}
.container { text-align: center; max-width: 500px; }
h1 { margin-bottom: 20px; }
.controls { margin: 15px 0; }
button {
    background: #4a4a4a; color: #fff;
    border: none; padding: 10px 20px; margin: 5px;
    font-size: 16px; border-radius: 5px; cursor: pointer;
}
button:hover { background: #666; }
#status { margin-top: 10px; font-size: 18px; font-weight: bold; min-height: 30px; }
EOF

# ────────────── public/script.js ──────────────
cat > public/script.js << 'EOF'
const API_URL = "/api/bestmove";  // relative path works locally & on Vercel

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
        pieceTheme: 'https://chessboardjs.com/img/chesspieces/wikipedia/{piece}.png' // تصاویر استاندارد ویکی‌پدیا
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
        const resp = await fetch(`${API_URL}?fen=${encodeURIComponent(game.fen())}&depth=3`);
        const data = await resp.json();
        if (data.bestmove) {
            const from = data.bestmove.substring(0,2);
            const to = data.bestmove.substring(2,4);
            const promo = data.bestmove.length > 4 ? data.bestmove[4] : undefined;
            game.move({ from, to, promotion: promo });
            board.position(game.fen());
        }
    } catch (e) {
        console.error(e);
        $('#status').text('خطا در ارتباط با موتور');
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

# ────────────── vercel.json (ساده‌شده) ──────────────
cat > vercel.json << 'EOF'
{
  "builds": [
    { "src": "api/index.py", "use": "@vercel/python" }
  ],
  "routes": [
    { "src": "/(.*)", "dest": "api/index.py" }
  ]
}
EOF

echo ""
echo "✅ تمام فایل‌ها با موفقیت ایجاد شدند."
echo "برای اجرای محلی:"
echo "  cd ~/chess-engine"
echo "  python api/index.py"
echo "سپس در مرورگر http://localhost:5000 را باز کنید."
echo ""
echo "برای انتشار روی Vercel:"
echo "  git add -A && git commit -m 'Final GUI + AI' && git push"
echo "  (Vercel به‌طور خودکار deploy می‌کند)"
