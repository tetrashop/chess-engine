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
