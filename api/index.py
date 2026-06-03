# api/index.py
from flask import Flask, request, jsonify
import sys
import os
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from chess_engine.board import Board
from chess_engine.search import Search

app = Flask(__name__)

@app.route('/')
def home():
    return "ChessEnginePy API is running. Use /bestmove?fen=...&depth=... or /eval?fen=..."

@app.route('/bestmove', methods=['GET'])
def bestmove():
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
            'nodes': search.nodes,
            'score': search.best_score if hasattr(search, 'best_score') else None
        })
    except Exception as e:
        return jsonify({'error': str(e)}), 400

@app.route('/eval', methods=['GET'])
def evaluate_position():
    fen = request.args.get('fen', 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1')
    try:
        from chess_engine.evaluate import evaluate
        board = Board(fen)
        score = evaluate(board)
        return jsonify({'score': score, 'fen': fen})
    except Exception as e:
        return jsonify({'error': str(e)}), 400

# Vercel requires the app to be callable as a module-level variable
# but Flask will be detected automatically if we just define 'app'
