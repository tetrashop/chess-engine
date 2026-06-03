#!/usr/bin/env bash
# fix_vercel.sh – رفع خطای 404 در Vercel

cd ~/chess-engine

# ────────────── 1. به‌روزرسانی api/index.py (فقط API بدون static) ──────────────
cat > api/index.py << 'EOF'
from flask import Flask, request, jsonify
import sys, os

# مسیر اصلی پروژه را به sys.path اضافه می‌کنیم
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

# فقط برای تست محلی – Vercel از این خط استفاده نمی‌کند
if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=5000)
EOF

# ────────────── 2. به‌روزرسانی vercel.json (تفکیک static و api) ──────────────
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

# ────────────── 3. اطمینان از عدم وجود static_folder اضافی در Flask ──────────────
echo ""
echo "✅ فایل‌ها اصلاح شدند."
echo "حالا برای انتشار روی Vercel:"
echo "  git add -A && git commit -m 'Fix Vercel routing: separate static & API' && git push"
echo ""
echo "برای تست محلی (در صورت تمایل):"
echo "  python api/index.py"
echo "  (سپس public/index.html را جداگانه باز کنید – API روی localhost:5000 اجراست)"
