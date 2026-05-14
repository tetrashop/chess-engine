import copy
from .bitboard import *
from .movegen import MoveGenerator   # for generating legal moves

class Board:
    def __init__(self, fen="rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"):
        self.bb = [0]*12          # index = (piece_type-1)*2 + color
        self.occupancy = [0,0]    # WHITE, BLACK
        self.pieces = [-1]*64     # sq -> piece index (0-11) or -1
        self.side_to_move = Color.WHITE
        self.castling_rights = 0  # bits: WK, WQ, BK, BQ
        self.en_passant_sq = -1
        self.half_move_clock = 0
        self.full_move_number = 1
        self._history = []        # for undo
        self._set_from_fen(fen)
        self._move_gen = MoveGenerator(self)

    def _piece_index(self, pt: PieceType, color: Color) -> int:
        return (pt - 1) * 2 + color

    def _set_from_fen(self, fen: str):
        self.bb = [0]*12
        self.occupancy = [0,0]
        self.pieces = [-1]*64
        parts = fen.split()
        board_part = parts[0]
        rank = 7
        file = 0
        for ch in board_part:
            if ch == '/':
                rank -= 1
                file = 0
            elif ch.isdigit():
                file += int(ch)
            else:
                sq = rank*8 + file
                color = Color.WHITE if ch.isupper() else Color.BLACK
                pt = {'p':PieceType.PAWN,'n':PieceType.KNIGHT,'b':PieceType.BISHOP,
                      'r':PieceType.ROOK,'q':PieceType.QUEEN,'k':PieceType.KING}[ch.lower()]
                idx = self._piece_index(pt, color)
                self.bb[idx] |= 1 << sq
                self.occupancy[color] |= 1 << sq
                self.pieces[sq] = idx
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
            self.en_passant_sq = (ord(en_passant[0]) - ord('a')) + (int(en_passant[1])-1)*8
        if len(parts) > 4:
            self.half_move_clock = int(parts[4])
            self.full_move_number = int(parts[5])

    def get_fen(self) -> str:
        fen = ""
        for rank in range(7, -1, -1):
            empty = 0
            for file in range(8):
                sq = rank*8 + file
                idx = self.pieces[sq]
                if idx == -1:
                    empty += 1
                else:
                    if empty:
                        fen += str(empty)
                        empty = 0
                    pt = (idx // 2) + 1
                    color = idx % 2
                    piece_char = "PNBRQK"[pt-1]
                    fen += piece_char if color == Color.WHITE else piece_char.lower()
            if empty:
                fen += str(empty)
            if rank > 0:
                fen += '/'
        fen += ' w' if self.side_to_move == Color.WHITE else ' b'
        castling = ''
        if self.castling_rights & 1: castling += 'K'
        if self.castling_rights & 2: castling += 'Q'
        if self.castling_rights & 4: castling += 'k'
        if self.castling_rights & 8: castling += 'q'
        fen += ' ' + (castling or '-')
        fen += ' ' + (square_to_str(self.en_passant_sq) if self.en_passant_sq != -1 else '-')
        fen += f' {self.half_move_clock} {self.full_move_number}'
        return fen

    def make_move(self, move):
        """move: (from_sq, to_sq, promotion_piece_type or None)"""
        from_sq, to_sq, promo = move
        # Save state for undo
        state = (self.bb[:], self.occupancy[:], self.pieces[:], self.side_to_move,
                 self.castling_rights, self.en_passant_sq, self.half_move_clock, self.full_move_number)
        self._history.append(state)

        us = self.side_to_move
        them = 1 - us
        piece_idx = self.pieces[from_sq]
        pt = (piece_idx // 2) + 1
        captured_idx = self.pieces[to_sq]

        # Update half move clock
        if pt == PieceType.PAWN or captured_idx != -1:
            self.half_move_clock = 0
        else:
            self.half_move_clock += 1

        # Handle en passant capture
        ep_capture = False
        if pt == PieceType.PAWN and to_sq == self.en_passant_sq:
            ep_capture = True
            if us == Color.WHITE:
                captured_sq = to_sq - 8
            else:
                captured_sq = to_sq + 8
            captured_idx = self.pieces[captured_sq]
            # Remove captured pawn
            self.bb[captured_idx] = clear_bit(self.bb[captured_idx], captured_sq)
            self.occupancy[them] = clear_bit(self.occupancy[them], captured_sq)
            self.pieces[captured_sq] = -1

        # Clear en passant square
        self.en_passant_sq = -1

        # Handle pawn double push (set new en passant)
        if pt == PieceType.PAWN and abs(from_sq - to_sq) == 16:
            if us == Color.WHITE:
                self.en_passant_sq = from_sq + 8
            else:
                self.en_passant_sq = from_sq - 8

        # Move piece: remove from source
        self.bb[piece_idx] = clear_bit(self.bb[piece_idx], from_sq)
        self.occupancy[us] = clear_bit(self.occupancy[us], from_sq)
        self.pieces[from_sq] = -1

        # Remove captured piece if any (and not already removed via ep)
        if captured_idx != -1 and not ep_capture:
            self.bb[captured_idx] = clear_bit(self.bb[captured_idx], to_sq)
            self.occupancy[them] = clear_bit(self.occupancy[them], to_sq)

        # Place piece at destination (handling promotion)
        if promo:
            promo_pt = promo  # PieceType value 2..5
            new_idx = self._piece_index(promo_pt, us)
            self.bb[new_idx] = set_bit(self.bb[new_idx], to_sq)
            self.occupancy[us] = set_bit(self.occupancy[us], to_sq)
            self.pieces[to_sq] = new_idx
        else:
            self.bb[piece_idx] = set_bit(self.bb[piece_idx], to_sq)
            self.occupancy[us] = set_bit(self.occupancy[us], to_sq)
            self.pieces[to_sq] = piece_idx

        # Castling updates
        if pt == PieceType.KING:
            # Remove castling rights
            if us == Color.WHITE:
                self.castling_rights &= ~3
            else:
                self.castling_rights &= ~12
            # Rook move if castling
            if abs(from_sq - to_sq) == 2:
                if to_sq > from_sq:  # Kingside
                    rook_from = to_sq + 1
                    rook_to = to_sq - 1
                else:                 # Queenside
                    rook_from = to_sq - 2
                    rook_to = to_sq + 1
                rook_idx = self._piece_index(PieceType.ROOK, us)
                self.bb[rook_idx] = clear_bit(self.bb[rook_idx], rook_from)
                self.bb[rook_idx] = set_bit(self.bb[rook_idx], rook_to)
                self.occupancy[us] = clear_bit(self.occupancy[us], rook_from)
                self.occupancy[us] = set_bit(self.occupancy[us], rook_to)
                self.pieces[rook_from] = -1
                self.pieces[rook_to] = rook_idx
        elif pt == PieceType.ROOK:
            if us == Color.WHITE:
                if from_sq == A1: self.castling_rights &= ~2
                elif from_sq == H1: self.castling_rights &= ~1
            else:
                if from_sq == A8: self.castling_rights &= ~8
                elif from_sq == H8: self.castling_rights &= ~4

        # Switch side
        self.side_to_move = them
        if us == Color.BLACK:
            self.full_move_number += 1

    def undo_move(self):
        state = self._history.pop()
        (self.bb, self.occupancy, self.pieces, self.side_to_move,
         self.castling_rights, self.en_passant_sq, self.half_move_clock,
         self.full_move_number) = state

    def is_in_check(self, color: Color) -> bool:
        king_sq = lsb(self.bb[self._piece_index(PieceType.KING, color)])
        return self.is_attacked(king_sq, 1-color)

    def is_attacked(self, sq: int, by_color: Color) -> bool:
        # Pawns
        pawns = self.bb[self._piece_index(PieceType.PAWN, by_color)]
        if by_color == Color.WHITE:
            if ((pawns << 7) & ~FILE_H) & (1 << sq): return True
            if ((pawns << 9) & ~FILE_A) & (1 << sq): return True
        else:
            if ((pawns >> 7) & ~FILE_A) & (1 << sq): return True
            if ((pawns >> 9) & ~FILE_H) & (1 << sq): return True
        # Knights
        if KNIGHT_ATTACKS[sq] & self.bb[self._piece_index(PieceType.KNIGHT, by_color)]:
            return True
        # King
        if KING_ATTACKS[sq] & self.bb[self._piece_index(PieceType.KING, by_color)]:
            return True
        # Sliding pieces
        occ = self.occupancy[0] | self.occupancy[1]
        bishops = self.bb[self._piece_index(PieceType.BISHOP, by_color)]
        rooks = self.bb[self._piece_index(PieceType.ROOK, by_color)]
        queens = self.bb[self._piece_index(PieceType.QUEEN, by_color)]
        if bishop_attacks(sq, occ) & (bishops | queens):
            return True
        if rook_attacks(sq, occ) & (rooks | queens):
            return True
        return False

    def generate_legal_moves(self):
        return [m for m in self._move_gen.generate_moves() if self._is_legal(m)]

    def _is_legal(self, move):
        self.make_move(move)
        in_check = self.is_in_check(1 - self.side_to_move)  # we already flipped side
        self.undo_move()
        return not in_check
