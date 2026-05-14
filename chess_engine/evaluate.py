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
