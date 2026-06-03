#!/usr/bin/env bash
# debug_fix.sh – رفع مشکل توقف در نوبت کامپیوتر

cd ~/chess-engine

echo "=== 1. بررسی و اصلاح api/index.py (کاهش عمق + لاگ خطا) ==="
cat > api/index.py << 'EOF'
from flask import Flask, request, jsonify
import sys, os, traceback

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from chess_engine.board import Board
from chess_engine.search import Search

app = Flask(__name__)

@app.after_request
def add_cors(response):
    response.headers['Access-Control-Allow-Origin'] = '*'
    response.headers['Access-Control-Allow-Headers'] = 'Content-Type'
    response.headers['Access-Control-Allow-Methods'] = 'GET, POST, OPTIONS'
    return response

@app.route('/api/bestmove', methods=['GET', 'OPTIONS'])
def bestmove():
    if request.method == 'OPTIONS':
        return jsonify({}), 200
    fen = request.args.get('fen', 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1')
    depth = min(int(request.args.get('depth', 2)), 3)   # حداکثر عمق ۳ برای جلوگیری از timeout
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

if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=5000)
EOF

echo "=== 2. اصلاح public/script.js (افزودن timeout و پیام خطا) ==="
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
        const timeout = setTimeout(() => controller.abort(), 8000); // 8 ثانیه
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

echo "=== 3. تست سریع API (محلی) ==="
echo "اگر Flask نصب نیست، دستور زیر را اجرا کنید: pip install flask"
echo "سپس در یک ترمینال دیگر:"
echo "  cd ~/chess-engine && python api/index.py"
echo "و تست کنید:"
echo "  curl 'http://localhost:5000/api/bestmove?fen=startpos&depth=2'"
echo ""
echo "=== 4. انتشار در Vercel ==="
echo "  git add -A && git commit -m 'Fix AI freeze: timeout, depth control, error handling' && git push"
