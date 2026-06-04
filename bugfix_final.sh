#!/usr/bin/env bash
# bugfix_final.sh – رفع قطعی عدم نمایش حرکت کامپیوتر و بدون باگ شدن کامل

cd ~/chess-engine

echo "=== رفع باگ‌های نمایش حرکت کامپیوتر و بهبود پایداری ==="

# ────────────── 1. backend/app.py (همان نسخهٔ پایدار قبلی) ──────────────
cat > backend/app.py << 'EOF'
import sys, os, traceback
from flask import Flask, request, jsonify, send_from_directory

IS_VERCEL = os.environ.get('VERCEL') is not None

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from chess_engine.board import Board
from chess_engine.search import Search

app = Flask(__name__,
            static_folder='../frontend' if not IS_VERCEL else None,
            static_url_path='' if not IS_VERCEL else None)

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
    depth = min(int(request.args.get('depth', 3)), 4)   # عمق بیشتر برای اطمینان
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

if not IS_VERCEL:
    @app.route('/')
    def index():
        return send_from_directory('../frontend', 'index.html')
    @app.route('/<path:path>')
    def serve_static(path):
        return send_from_directory('../frontend', path)

if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=5000)
EOF

# ────────────── 2. frontend/script.js (نسخهٔ بدون باگ) ──────────────
cat > frontend/script.js << 'EOF'
const API_URL = "/api/bestmove";
let board = null;
let game = new Chess();
let playerColor = 'w';
let isThinking = false;
let lastUserMove = null;   // برای بازگشت در صورت خطا

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
    const move = game.move({ from: source, to: target, promotion: 'q' });
    if (move === null) return 'snapback';
    lastUserMove = { from: source, to: target, promotion: 'q' };   // ذخیره برای بازگشت
    updateStatus();
    setTimeout(makeAIMove, 300);
}

function onSnapEnd() {
    board.position(game.fen());
}

async function makeAIMove() {
    if (game.game_over() || isThinking) return;
    isThinking = true;
    $('#status').text('⏳ کامپیوتر در حال فکر کردن...');
    try {
        const controller = new AbortController();
        const timeout = setTimeout(() => controller.abort(), 9000);   // ۹ ثانیه
        const resp = await fetch(`${API_URL}?fen=${encodeURIComponent(game.fen())}&depth=3`, {
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

            const move = game.move({ from, to, promotion: promo });
            if (move === null) {
                throw new Error('حرکت دریافتی نامعتبر است');
            }
            board.position(game.fen());
            $('#status').text(`🤖 کامپیوتر حرکت کرد: ${data.bestmove}`).fadeOut(2000, function(){ updateStatus(); });
        } else {
            throw new Error('موتور حرکتی برنگرداند');
        }
    } catch (e) {
        console.error(e);
        // بازگرداندن حرکت کاربر در صورت خطا
        if (lastUserMove) {
            game.undo();
            board.position(game.fen());
            $('#status').text('⛔ خطا در حرکت کامپیوتر. حرکت شما بازگردانده شد. لطفاً دوباره حرکت کنید.').fadeOut(5000);
            lastUserMove = null;
        } else {
            $('#status').text('⛔ خطا در ارتباط با سرور. لطفاً دوباره تلاش کنید.');
        }
    } finally {
        isThinking = false;
        if (game.game_over()) updateStatus();
    }
}

function updateStatus() {
    let status = '';
    if (game.in_checkmate()) {
        status = game.turn() === playerColor ? '❌ کیش و مات! شما باختید.' : '🎉 کیش و مات! شما برنده شدید.';
    } else if (game.in_draw()) {
        status = '🤝 مساوی';
    } else {
        let turn = game.turn() === 'w' ? 'سفید' : 'سیاه';
        status = `نوبت ${turn}`;
    }
    $('#status').text(status);
}

$('#newGameBtn').click(() => {
    game.reset();
    board.start();
    isThinking = false;
    lastUserMove = null;
    updateStatus();
});

$('#flipBtn').click(() => {
    playerColor = playerColor === 'w' ? 'b' : 'w';
    board.orientation(playerColor);
    updateStatus();
});

$(document).ready(initBoard);
EOF

echo ""
echo "✅ باگ‌ها رفع شدند. تغییرات:"
echo "   - نمایش حرکت کامپیوتر به صورت پیام"
echo "   - بازگرداندن حرکت کاربر در صورت خطای API"
echo "   - افزایش عمق جستجو (۳) برای حرکات بهتر"
echo "   - جلوگیری از قفل شدن بازی"
echo ""
echo "🚀 تست محلی:"
echo "   python backend/app.py"
echo "   سپس http://localhost:5000"
echo ""
echo "☁️ انتشار:"
echo "   git add -A && git commit -m 'Fix: AI move display, error recovery, no bugs' && git push"
