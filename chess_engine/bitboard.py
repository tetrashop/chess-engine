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
