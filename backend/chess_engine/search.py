from .evaluate import evaluate
from .movegen import MoveGenerator
import time

class Search:
    def __init__(self, board):
        self.board = board
        self.nodes = 0
        self.best_move = None
        self.max_depth = 1

    def search(self, depth):
        self.max_depth = depth
        self.nodes = 0
        start = time.time()
        best_score = 0
        for d in range(1, depth+1):
            self.best_move = None
            best_score = self._alpha_beta(d, -999999, 999999, True)
        elapsed = time.time() - start
        nps = int(self.nodes / elapsed) if elapsed > 0 else 0
        print(f"info depth {depth} score cp {best_score} nodes {self.nodes} time {int(elapsed*1000)} nps {nps}")
        if self.best_move:
            from_sq, to_sq, promo = self.best_move
            promo_str = ''
            if promo:
                promo_str = 'nbrq'[promo-2]  # 2=KNIGHT->n, 3=BISHOP->b, 4=ROOK->r, 5=QUEEN->q
            from .bitboard import square_to_str
            move_str = square_to_str(from_sq) + square_to_str(to_sq) + promo_str
            print(f"bestmove {move_str}")

    def _alpha_beta(self, depth, alpha, beta, root=False):
        if depth == 0:
            return self._quiescence(alpha, beta)
        self.nodes += 1
        moves = self.board.generate_legal_moves()
        if not moves:
            if self.board.is_in_check(self.board.side_to_move):
                return -99999 + (self.board.full_move_number * 10)
            else:
                return 0  # stalemate
        # Simple MVV-LVA ordering
        moves.sort(key=lambda m: self._mvvlva(m), reverse=True)
        for move in moves:
            self.board.make_move(move)
            score = -self._alpha_beta(depth-1, -beta, -alpha)
            self.board.undo_move()
            if score >= beta:
                return beta
            if score > alpha:
                alpha = score
                if root:
                    self.best_move = move
        return alpha

    def _quiescence(self, alpha, beta):
        self.nodes += 1
        stand_pat = evaluate(self.board)
        if stand_pat >= beta:
            return beta
        if stand_pat > alpha:
            alpha = stand_pat
        # Only capture/promotion moves from pseudo-legal generator
        moves = self.board._move_gen.generate_moves()
        captures = []
        for m in moves:
            to_sq = m[1]
            if 0 <= to_sq <= 63 and (self.board.pieces[to_sq] != -1 or m[2] is not None):
                captures.append(m)
        captures.sort(key=lambda m: self._mvvlva(m), reverse=True)
        for move in captures:
            self.board.make_move(move)
            # Check legality
            if not self.board.is_in_check(1 - self.board.side_to_move):
                score = -self._quiescence(-beta, -alpha)
                self.board.undo_move()
                if score >= beta:
                    return beta
                if score > alpha:
                    alpha = score
            else:
                self.board.undo_move()
        return alpha

    def _mvvlva(self, move):
        from_sq, to_sq, promo = move
        victim_idx = self.board.pieces[to_sq]
        if victim_idx == -1:
            return 0
        victim_pt = (victim_idx // 2) + 1
        return victim_pt * 10
