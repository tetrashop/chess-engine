"""
Alpha-beta search with quiescence search (basic).
"""
from .evaluate import evaluate
from .movegen import MoveGenerator
import time

class Search:
    def __init__(self, board):
        self.board = board
        self.nodes = 0
        self.best_move = None

    def search(self, depth: int):
        self.nodes = 0
        self.best_move = None
        start = time.time()
        score = self._alpha_beta(depth, -999999, 999999)
        elapsed = time.time() - start
        nps = int(self.nodes / elapsed) if elapsed > 0 else 0
        print(f"info depth {depth} score cp {score} nodes {self.nodes} time {int(elapsed*1000)} nps {nps}")
        if self.best_move:
            print(f"bestmove {self._move_to_str(self.best_move)}")

    def _alpha_beta(self, depth, alpha, beta):
        if depth == 0:
            return self._quiescence(alpha, beta)
        self.nodes += 1
        moves = MoveGenerator(self.board).generate_moves()
        if not moves:
            # Checkmate or stalemate? TODO: detect check
            return -99999 + (self.board.full_move_number * 10)  # prefer later mate
        for move in moves:
            self.board.apply_move(move)
            score = -self._alpha_beta(depth - 1, -beta, -alpha)
            self.board.undo_move()
            if score >= beta:
                return beta
            if score > alpha:
                alpha = score
                if depth == self.max_depth:  # keep best move at root
                    self.best_move = move
        return alpha

    def _quiescence(self, alpha, beta):
        self.nodes += 1
        stand_pat = evaluate(self.board)
        if stand_pat >= beta:
            return beta
        if stand_pat > alpha:
            alpha = stand_pat
        # Generate only capture moves (simplified)
        # For now, return stand_pat
        return alpha

    def _move_to_str(self, move):
        # move format: from_sq to_sq
        from_sq, to_sq = move  # placeholders
        from .bitboard import square_to_str
        return square_to_str(from_sq) + square_to_str(to_sq)
