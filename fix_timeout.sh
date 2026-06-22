#!/usr/bin/env bash
# fix_timeout.sh – رفع تایم‌اوت Vercel و بهینه‌سازی درخواست‌ها

cd ~/chess-engine

echo "=== ۱. کاهش عمق جستجو در backend/app.py ==="
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
    # حداکثر عمق ۳ برای جلوگیری از تایم‌اوت
    depth = min(int(request.args.get('depth', 3)), 3)
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

echo "=== ۲. هماهنگ‌سازی فرانت‌اند با محدودیت Vercel ==="
# کاهش عمق درخواست‌ها و timeout به ۸ ثانیه
sed -i 's|const depth = Math.min(level + 2, 6);|const depth = Math.min(level + 1, 3);|' bw-project/src/main/assets/script.js
sed -i 's|const timeout = setTimeout(() => controller.abort(), 12000);|const timeout = setTimeout(() => controller.abort(), 8000);|' bw-project/src/main/assets/script.js
sed -i 's|const resp = await fetch(`${API_URL}?fen=${encodeURIComponent(game.fen())}&depth=4`|const resp = await fetch(`${API_URL}?fen=${encodeURIComponent(game.fen())}&depth=3`|' bw-project/src/main/assets/script.js

# اصلاح fetchBestMoveForCoach (مربی)
sed -i 's|fetch(`${API_URL}?fen=${encodeURIComponent(game.fen())}&depth=4`|fetch(`${API_URL}?fen=${encodeURIComponent(game.fen())}&depth=2`|' bw-project/src/main/assets/script.js

echo "=== ۳. به‌روزرسانی frontend/script.js (برای وب) ==="
if [ -f frontend/script.js ]; then
    sed -i 's|const depth = Math.min(level + 2, 6);|const depth = Math.min(level + 1, 3);|' frontend/script.js
    sed -i 's|const timeout = setTimeout(() => controller.abort(), 12000);|const timeout = setTimeout(() => controller.abort(), 8000);|' frontend/script.js
fi

echo ""
echo "✅ تغییرات اعمال شد."
echo "اکنون دستورات زیر را اجرا کنید:"
echo "  git add -A && git commit -m 'Fix Vercel timeout: reduce depth to 3, timeout 8s' && git push"
echo "  سپس یک Release جدید (مثلاً v1.1.3) در گیت‌هاب بسازید."
