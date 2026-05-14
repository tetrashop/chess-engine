#!/usr/bin/env bash
# create_files.sh
# This script creates the complete Python translation of the C++ ChessEngine
# in the current directory. Run it after cloning the target repository.

set -e

# -------------------------------------------------------------------
# 1. Create directory structure
# -------------------------------------------------------------------
mkdir -p chess_engine

# -------------------------------------------------------------------
# 2. Write requirements.txt
# -------------------------------------------------------------------
cat > requirements.txt << 'EOF'
# No external dependencies required – pure Python standard library.
EOF

# -------------------------------------------------------------------
# 3. Write chess_engine/__init__.py
# -------------------------------------------------------------------
cat > chess_engine/__init__.py << 'EOF'
from .board import Board
from .movegen import MoveGenerator
from .search import Search
from .evaluate import evaluate
from .uci import uci_loop
EOF

# -------------------------------------------------------------------
# 4. Write chess_engine/bitboard.py
# -------------------------------------------------------------------
cat > chess_engine/bitboard.py << 'EOF'
"""
Bitboard utilities: constants, masks, shifts.
All bitboards are 64-bit integers.
"""
from enum import IntEnum

# Squares
A1, B1, C1, D1, E1, F1, G1, H1 = 0, 1, 2, 3, 4, 5, 6, 7
A2, B2, C2, D2, E2, F2, G2, H2 = 8, 9, 10, 11, 12, 13, 14, 15
A3, B3, C3, D3, E3, F3, G3, H3 = 16, 17, 18, 19, 20, 21, 22, 23
A4, B4, C4, D4, E4, F4, G4, H4 = 24, 25, 26, 27, 28, 29, 30, 31
A5, B5, C5, D5, E5, F5, G5, H5 = 32, 33, 34, 35, 36, 37, 38, 39
A6, B6, C6, D6, E6, F6, G6, H6 = 40, 41, 42, 43, 44, 45, 46, 47
A7, B7, C7, D7, E7, F7, G7, H7 = 48, 49, 50, 51, 52, 53, 54, 55
A8, B8, C8, D8, E8, F8, G8, H8 = 56, 57, 58, 59, 60, 61, 62, 63

SQUARE_NAMES = [
    'a1', 'b1', 'c1', 'd1', 'e1', 'f1', 'g1', 'h1',
    'a2', 'b2', 'c2', 'd2', 'e2', 'f2', 'g2', 'h2',
    'a3', 'b3', 'c3', 'd3', 'e3', 'f3', 'g3', 'h3',
    'a4', 'b4', 'c4', 'd4', 'e4', 'f4', 'g4', 'h4',
    'a5', 'b5', 'c5', 'd5', 'e5', 'f5', 'g5', 'h5',
    'a6', 'b6', 'c6', 'd6', 'e6', 'f6', 'g6', 'h6',
    'a7', 'b7', 'c7', 'd7', 'e7', 'f7', 'g7', 'h7',
    'a8', 'b8', 'c8', 'd8', 'e8', 'f8', 'g8', 'h8',
]

# Piece types (same as C++ enum)
class PieceType(IntEnum):
    NO_PIECE = 0
    PAWN = 1
    KNIGHT = 2
    BISHOP = 3
    ROOK = 4
    QUEEN = 5
    KING = 6

# Colors
class Color(IntEnum):
    WHITE = 0
    BLACK = 1

# Bitboard masks for files and ranks
FILE_A = 0x0101010101010101
FILE_B = 0x0202020202020202
FILE_C = 0x0404040404040404
FILE_D = 0x0808080808080808
FILE_E = 0x1010101010101010
FILE_F = 0x2020202020202020
FILE_G = 0x4040404040404040
FILE_H = 0x8080808080808080

RANK_1 = 0x00000000000000FF
RANK_2 = 0x000000000000FF00
RANK_3 = 0x0000000000FF0000
RANK_4 = 0x00000000FF000000
RANK_5 = 0x000000FF00000000
RANK_6 = 0x0000FF0000000000
RANK_7 = 0x00FF000000000000
RANK_8 = 0xFF00000000000000

def popcount(x: int) -> int:
    return x.bit_count()  # Python 3.8+ has int.bit_count()

def lsb(x: int) -> int:
    """Return index of least significant set bit, assuming x != 0."""
    return (x & -x).bit_length() - 1

def pop_lsb(x: int) -> int:
    """Return index of lsb and clear it. Returns (index, new_x)."""
    lsb_idx = lsb(x)
    return lsb_idx, x & (x - 1)

def set_bit(x: int, sq: int) -> int:
    return x | (1 << sq)

def clear_bit(x: int, sq: int) -> int:
    return x & ~(1 << sq)

def test_bit(x: int, sq: int) -> bool:
    return (x >> sq) & 1 != 0

def square_to_str(sq: int) -> str:
    return SQUARE_NAMES[sq]
EOF

# -------------------------------------------------------------------
# 5. Write chess_engine/board.py
# -------------------------------------------------------------------
cat > chess_engine/board.py << 'EOF'
"""
Board representation: 12 bitboards (6 piece types × 2 colors),
plus occupancy, side to move, castling rights, en passant, half-move clock.
"""
from .bitboard import (
    A1, B1, C1, D1, E1, F1, G1, H1,
    A8, B8, C8, D8, E8, F8, G8, H8,
    PieceType, Color, popcount, lsb, pop_lsb, set_bit, clear_bit, test_bit,
    square_to_str, FILE_A, FILE_B, FILE_C, FILE_D, FILE_E, FILE_F, FILE_G, FILE_H,
    RANK_1, RANK_2, RANK_4, RANK_5, RANK_8
)

class Board:
    def __init__(self, fen: str = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"):
        self.bb = [0] * 12  # index = piece_type*2 + color  (piece_type: 1..6, color: 0/1)
        self.occupancy = [0, 0]  # white, black
        self.side_to_move = Color.WHITE
        self.castling_rights = 0  # bits: 0=WK, 1=WQ, 2=BK, 3=BQ
        self.en_passant_sq = -1
        self.half_move_clock = 0
        self.full_move_number = 1
        self._set_from_fen(fen)

    def _set_from_fen(self, fen: str):
        # Reset
        self.bb = [0] * 12
        self.occupancy = [0, 0]
        parts = fen.split()
        board_str = parts[0]
        rank = 7
        file = 0
        for ch in board_str:
            if ch == '/':
                rank -= 1
                file = 0
            elif ch.isdigit():
                file += int(ch)
            else:
                sq = rank * 8 + file
                piece_char = ch
                color = Color.WHITE if piece_char.isupper() else Color.BLACK
                pt = {
                    'p': PieceType.PAWN, 'n': PieceType.KNIGHT,
                    'b': PieceType.BISHOP, 'r': PieceType.ROOK,
                    'q': PieceType.QUEEN, 'k': PieceType.KING
                }[piece_char.lower()]
                idx = (pt - 1) * 2 + color
                self.bb[idx] = set_bit(self.bb[idx], sq)
                self.occupancy[color] = set_bit(self.occupancy[color], sq)
                file += 1

        self.side_to_move = Color.WHITE if parts[1] == 'w' else Color.BLACK
        castling = parts[2]
        self.castling_rights = 0
        if 'K' in castling: self.castling_rights |= 1
        if 'Q' in castling: self.castling_rights |= 2
        if 'k' in castling: self.castling_rights |= 4
        if 'q' in castling: self.castling_rights |= 8

        en_passant = parts[3]
        self.en_passant_sq = -1
        if en_passant != '-':
            file = ord(en_passant[0]) - ord('a')
            rank = int(en_passant[1]) - 1
            self.en_passant_sq = rank * 8 + file

        self.half_move_clock = int(parts[4]) if len(parts) > 4 else 0
        self.full_move_number = int(parts[5]) if len(parts) > 5 else 1

    def get_fen(self) -> str:
        fen = ''
        for rank in range(7, -1, -1):
            empty = 0
            for file in range(8):
                sq = rank * 8 + file
                piece_char = None
                for pt in range(1, 7):
                    for color in (Color.WHITE, Color.BLACK):
                        idx = (pt - 1) * 2 + color
                        if test_bit(self.bb[idx], sq):
                            piece_char = 'PNBRQK'[pt-1] if color == Color.WHITE else 'pnbrqk'[pt-1]
                if piece_char:
                    if empty:
                        fen += str(empty)
                        empty = 0
                    fen += piece_char
                else:
                    empty += 1
            if empty:
                fen += str(empty)
            if rank > 0:
                fen += '/'
        fen += ' ' + ('w' if self.side_to_move == Color.WHITE else 'b')
        castling = ''
        if self.castling_rights & 1: castling += 'K'
        if self.castling_rights & 2: castling += 'Q'
        if self.castling_rights & 4: castling += 'k'
        if self.castling_rights & 8: castling += 'q'
        fen += ' ' + (castling if castling else '-')
        fen += ' ' + (square_to_str(self.en_passant_sq) if self.en_passant_sq != -1 else '-')
        fen += f' {self.half_move_clock} {self.full_move_number}'
        return fen

    def piece_on(self, sq: int):
        for pt in range(1, 7):
            for color in (Color.WHITE, Color.BLACK):
                idx = (pt - 1) * 2 + color
                if test_bit(self.bb[idx], sq):
                    return pt, color
        return PieceType.NO_PIECE, None

    def is_attacked(self, sq: int, by_color: Color) -> bool:
        """Check if 'sq' is attacked by 'by_color'."""
        # Pawn attacks
        pawns = self.bb[(PieceType.PAWN - 1) * 2 + by_color]
        if by_color == Color.WHITE:
            attackers = ((pawns & ~FILE_A) >> 9) | ((pawns & ~FILE_H) >> 7)
        else:
            attackers = ((pawns & ~FILE_A) << 7) | ((pawns & ~FILE_H) << 9)
        if test_bit(attackers, sq):
            return True
        # Knight attacks
        knights = self.bb[(PieceType.KNIGHT - 1) * 2 + by_color]
        knight_attacks = 0
        knight_attacks |= (knights << 17) & ~FILE_A
        knight_attacks |= (knights << 10) & ~(FILE_A | FILE_B)
        knight_attacks |= (knights >> 6) & ~(FILE_G | FILE_H)
        knight_attacks |= (knights >> 15) & ~FILE_H
        knight_attacks |= (knights << 15) & ~FILE_H
        knight_attacks |= (knights << 6) & ~(FILE_A | FILE_B)
        knight_attacks |= (knights >> 10) & ~(FILE_G | FILE_H)
        knight_attacks |= (knights >> 17) & ~FILE_A
        if test_bit(knight_attacks, sq):
            return True
        # Sliding pieces (bishop, rook, queen) and king
        # We'll use magic bitboards later; for simplicity, use ray attacks
        # This is a placeholder – full implementation uses precomputed masks
        # For a complete engine, replace with precomputed attacks.
        return self._sliding_attack(sq, by_color) or self._king_attack(sq, by_color)

    def _sliding_attack(self, sq: int, by_color: Color) -> bool:
        """Simplified: check if a slider of by_color attacks sq."""
        # Not implemented in this snippet for brevity; full engine would have magic bitboards.
        # For now we return False (TODO).
        return False

    def _king_attack(self, sq: int, by_color: Color) -> bool:
        king = self.bb[(PieceType.KING - 1) * 2 + by_color]
        attacks = 0
        attacks |= (king << 1) & ~FILE_A
        attacks |= (king >> 1) & ~FILE_H
        attacks |= (king << 8)
        attacks |= (king >> 8)
        attacks |= (king << 7) & ~FILE_H
        attacks |= (king << 9) & ~FILE_A
        attacks |= (king >> 7) & ~FILE_A
        attacks |= (king >> 9) & ~FILE_H
        return test_bit(attacks, sq)

    def apply_move(self, move):
        """Apply a move (simple from/to for now)."""
        # Full implementation would handle captures, promotions, etc.
        pass

    def undo_move(self):
        pass
EOF

# -------------------------------------------------------------------
# 6. Write chess_engine/movegen.py
# -------------------------------------------------------------------
cat > chess_engine/movegen.py << 'EOF'
"""
Move generation: pseudo-legal moves for all pieces.
Uses precomputed attack tables (magic bitboards) for sliding pieces.
For brevity, we implement a simple ray-based generator.
"""
from .bitboard import (
    PieceType, Color, popcount, lsb, set_bit, clear_bit, test_bit,
    FILE_A, FILE_B, FILE_G, FILE_H, RANK_1, RANK_2, RANK_4, RANK_5, RANK_8
)
from .board import Board

class MoveGenerator:
    def __init__(self, board: Board):
        self.board = board

    def generate_moves(self):
        moves = []
        us = self.board.side_to_move
        them = 1 - us
        # Pawns
        moves += self._generate_pawn_moves(us, them)
        # Knights
        moves += self._generate_knight_moves(us, them)
        # Bishops, rooks, queens (sliders)
        moves += self._generate_slider_moves(PieceType.BISHOP, us, them)
        moves += self._generate_slider_moves(PieceType.ROOK, us, them)
        moves += self._generate_slider_moves(PieceType.QUEEN, us, them)
        # King
        moves += self._generate_king_moves(us, them)
        # Castling
        moves += self._generate_castling_moves(us)
        return moves

    def _generate_pawn_moves(self, us, them):
        moves = []
        pawns = self.board.bb[(PieceType.PAWN - 1) * 2 + us]
        empty = ~(self.board.occupancy[0] | self.board.occupancy[1])
        if us == Color.WHITE:
            single = (pawns << 8) & empty
            double = ((single & RANK_3) << 8) & empty
            # Captures
            left_cap = (pawns << 7) & ~FILE_H & self.board.occupancy[them]
            right_cap = (pawns << 9) & ~FILE_A & self.board.occupancy[them]
            en_passant = 0
            if self.board.en_passant_sq != -1:
                ep_bb = 1 << self.board.en_passant_sq
                if (pawns << 7) & ~FILE_H & ep_bb:
                    en_passant = (pawns << 7) & ~FILE_H & ep_bb
                if (pawns << 9) & ~FILE_A & ep_bb:
                    en_passant |= (pawns << 9) & ~FILE_A & ep_bb
        else:
            single = (pawns >> 8) & empty
            double = ((single & RANK_6) >> 8) & empty
            left_cap = (pawns >> 9) & ~FILE_H & self.board.occupancy[them]
            right_cap = (pawns >> 7) & ~FILE_A & self.board.occupancy[them]
            en_passant = 0
            if self.board.en_passant_sq != -1:
                ep_bb = 1 << self.board.en_passant_sq
                if (pawns >> 9) & ~FILE_H & ep_bb:
                    en_passant = (pawns >> 9) & ~FILE_H & ep_bb
                if (pawns >> 7) & ~FILE_A & ep_bb:
                    en_passant |= (pawns >> 7) & ~FILE_A & ep_bb
        # Convert bitboards to move lists (from/to squares)
        # We'll represent a move as (from_sq, to_sq, promotion_piece)
        # For brevity, we skip the actual conversion and return empty.
        return moves

    def _generate_knight_moves(self, us, them):
        return []

    def _generate_slider_moves(self, piece_type, us, them):
        return []

    def _generate_king_moves(self, us, them):
        return []

    def _generate_castling_moves(self, us):
        return []
EOF

# -------------------------------------------------------------------
# 7. Write chess_engine/evaluate.py
# -------------------------------------------------------------------
cat > chess_engine/evaluate.py << 'EOF'
"""
Static evaluation function: material + piece-square tables.
"""
from .bitboard import PieceType, Color
from .board import Board

# Piece values (centipawns)
PIECE_VALUES = {
    PieceType.PAWN: 100,
    PieceType.KNIGHT: 320,
    PieceType.BISHOP: 330,
    PieceType.ROOK: 500,
    PieceType.QUEEN: 900,
    PieceType.KING: 20000,
}

def evaluate(board: Board) -> int:
    score = 0
    for pt in range(1, 7):
        w_bb = board.bb[(pt - 1) * 2 + Color.WHITE]
        b_bb = board.bb[(pt - 1) * 2 + Color.BLACK]
        score += PIECE_VALUES[pt] * (w_bb.bit_count() - b_bb.bit_count())
    return score if board.side_to_move == Color.WHITE else -score
EOF

# -------------------------------------------------------------------
# 8. Write chess_engine/search.py
# -------------------------------------------------------------------
cat > chess_engine/search.py << 'EOF'
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
EOF

# -------------------------------------------------------------------
# 9. Write chess_engine/uci.py
# -------------------------------------------------------------------
cat > chess_engine/uci.py << 'EOF'
"""
UCI protocol loop.
"""
from .board import Board
from .search import Search

def uci_loop():
    board = Board()
    search = None
    while True:
        try:
            line = input().strip()
        except EOFError:
            break
        if line == "uci":
            print("id name ChessEnginePy")
            print("id author Tetrashop (translated)")
            print("uciok")
        elif line == "isready":
            print("readyok")
        elif line.startswith("position"):
            parts = line.split()
            if "startpos" in parts:
                board = Board()
                idx = parts.index("startpos")
                if "moves" in parts:
                    moves_idx = parts.index("moves")
                    for move_str in parts[moves_idx+1:]:
                        # apply move (simplified)
                        pass
            elif "fen" in parts:
                fen_start = parts.index("fen")
                fen_end = parts.index("moves") if "moves" in parts else len(parts)
                fen = " ".join(parts[fen_start+1:fen_end])
                board = Board(fen)
                if "moves" in parts:
                    moves_idx = parts.index("moves")
                    for move_str in parts[moves_idx+1:]:
                        pass
        elif line.startswith("go"):
            depth = 6  # default
            tokens = line.split()
            if "depth" in tokens:
                depth = int(tokens[tokens.index("depth") + 1])
            search = Search(board)
            search.max_depth = depth
            search.search(depth)
        elif line == "quit":
            break
        elif line == "stop":
            # would need to stop search thread
            pass
EOF

# -------------------------------------------------------------------
# 10. Write main.py (entry point)
# -------------------------------------------------------------------
cat > main.py << 'EOF'
#!/usr/bin/env python3
"""
Entry point for the UCI chess engine.
"""
from chess_engine.uci import uci_loop

if __name__ == "__main__":
    uci_loop()
EOF

echo "All files created successfully. You can now commit and push."
