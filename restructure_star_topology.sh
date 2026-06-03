#!/usr/bin/env bash
# restructure_star_topology.sh – بازآرایی پروژه به معماری ستاره‌ای

cd ~/chess-engine

echo "=== بازآرایی به معماری ستاره‌ای (Backend ↔ Frontend) ==="

# 1. پوشه‌های جدید را بسازید
mkdir -p backend frontend

# 2. انتقال موتور شطرنج به پوشه‌ی backend (همان ماژول chess_engine)
#    (با حفظ نسخه‌ی اصلی در ریشه – می‌توانید بعداً حذف کنید)
cp -r chess_engine backend/chess_engine

# 3. ایجاد فایل backend/app.py (فقط سرویس API، بدون سرو استاتیک)
cat > backend/app.py << 'EOF'
import sys, os, traceback
from flask import Flask, request, jsonify

# اضافه کردن پوشه‌ی backend به مسیر جستجوی ماژول‌ها
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from chess_engine.board import Board
from chess_engine.search import Search

app = Flask(__name__)

# CORS
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
    depth = min(int(request.args.get('depth', 2)), 3)
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

# (اختیاری) اجرای مستقیم برای تست
if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=5000)
EOF

# 4. انتقال فایل‌های فرانت‌اند به پوشه‌ی frontend
if [ -f public/index.html ]; then
    mv public/index.html frontend/
    mv public/script.js frontend/
    mv public/style.css frontend/
    echo "فایل‌های frontend منتقل شدند."
else
    # اگر فایل‌ها قبلاً انتقال داده شده یا وجود ندارند، نسخه‌ی نهایی را می‌سازیم
    echo "ساخت فایل‌های frontend از نو..."
    cat > frontend/index.html << 'HTMLEOF'
<!DOCTYPE html>
<html lang="fa" dir="rtl">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>ChessEnginePy – بازی شطرنج با هوش مصنوعی</title>
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/chessboard-js/1.0.0/chessboard-1.0.0.min.css">
    <link rel="stylesheet" href="style.css">
</head>
<body>
    <div class="container">
        <h1>♟️ ChessEnginePy – معماری ستاره‌ای</h1>
        <div id="board" style="width: 400px; margin: 0 auto;"></div>
        <div class="controls">
            <button id="newGameBtn">🔄 بازی جدید</button>
            <button id="flipBtn">🔃 چرخاندن صفحه</button>
        </div>
        <div id="status">نوبت شما (سفید)</div>
        <p style="font-size:12px; color:#aaa;">کلاینت (Frontend) → درخواست به Backend</p>
    </div>

    <script src="https://code.jquery.com/jquery-3.6.0.min.js"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/chess.js/0.10.3/chess.min.js"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/chessboard-js/1.0.0/chessboard-1.0.0.min.js"></script>
    <script src="script.js"></script>
</body>
</html>
HTMLEOF
    cat > frontend/script.js << 'JSEOF'
const API_URL = "/api/bestmove";  // مسیر نسبی به همان سرور
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
    const move = game.move({ from: source, to: target, promotion: 'q' });
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
        if (data.error) throw new Error(data.error);
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
JSEOF
    cat > frontend/style.css << 'CSSEOF'
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
CSSEOF
fi

# 5. به‌روزرسانی vercel.json برای معماری ستاره‌ای
cat > vercel.json << 'EOF'
{
  "builds": [
    { "src": "backend/app.py", "use": "@vercel/python" },
    { "src": "frontend/**", "use": "@vercel/static" }
  ],
  "routes": [
    { "src": "/api/(.*)", "dest": "backend/app.py" },
    { "src": "/", "dest": "frontend/index.html" },
    { "src": "/(.*)", "dest": "frontend/$1" }
  ]
}
EOF

# 6. فایل requirements.txt برای نصب Flask (در صورت نیاز)
echo "flask" > backend/requirements.txt

# 7. پاکسازی فایل‌های قدیمی (اختیاری – با احتیاط)
# می‌توانید پوشه‌های public و api قبلی را حذف کنید، اما برای امنیت نمی‌کنیم
echo ""
echo "✅ بازآرایی کامل شد. ساختار جدید:"
echo "   backend/   ← سرور هوش مصنوعی (API)"
echo "   frontend/  ← کلاینت‌های ستاره‌ای"
echo ""
echo "🚀 تست محلی:"
echo "   cd ~/chess-engine"
echo "   python backend/app.py"
echo "   سپس مرورگر را به http://localhost:5000 ببرید (توجه: فایل‌های استاتیک در این حالت سرو نمی‌شوند،"
echo "   باید از Vercel استفاده کنید یا یک سرور استاتیک جداگانه اجرا کنید)."
echo "   برای تست کامل محلی، می‌توانید فرانت‌اند را با live-server باز کنید و API_URL را به http://localhost:5000/api/bestmove تغییر دهید."
echo ""
echo "☁️ انتشار روی Vercel:"
echo "   git add -A && git commit -m 'Star topology: separate backend & frontend' && git push"
echo "   (Vercel به‌طور خودکار دیپلوی می‌کند)"
