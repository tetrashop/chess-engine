from .bitboard import *

MASK64 = 0xFFFFFFFFFFFFFFFF

class MoveGenerator:
    def __init__(self, board: 'Board'):
        self.board = board

    def generate_moves(self):
        moves = []
        us = self.board.side_to_move
        them = 1 - us
        moves += self._gen_pawn_moves(us, them)
        moves += self._gen_piece_moves(PieceType.KNIGHT, us, KNIGHT_ATTACKS)
        moves += self._gen_slider_moves(PieceType.BISHOP, us, BISHOP_DIRS)
        moves += self._gen_slider_moves(PieceType.ROOK, us, ROOK_DIRS)
        moves += self._gen_slider_moves(PieceType.QUEEN, us, ROOK_DIRS + BISHOP_DIRS)
        moves += self._gen_piece_moves(PieceType.KING, us, KING_ATTACKS)
        moves += self._gen_castling_moves(us)
        # Safety filter: remove moves with out-of-bound squares
        return [(f,t,p) for (f,t,p) in moves if 0 <= f <= 63 and 0 <= t <= 63]

    def _gen_pawn_moves(self, us, them):
        moves = []
        pawns = self.board.bb[self.board._piece_index(PieceType.PAWN, us)]
        empty = ~(self.board.occupancy[0] | self.board.occupancy[1]) & MASK64
        occ_them = self.board.occupancy[them]
        promo_rank = RANK_8 if us == Color.WHITE else RANK_1

        if us == Color.WHITE:
            forward = 8
            left_cap_dir = 7
            right_cap_dir = 9
            double_start = RANK_2
            double_shift = 16
            single = (pawns << 8) & empty
            double = ((single & double_start) << 8) & empty
            left_cap = (pawns << 7) & ~FILE_H & occ_them & MASK64
            right_cap = (pawns << 9) & ~FILE_A & occ_them & MASK64
            # En passant
            ep = 0
            if self.board.en_passant_sq != -1:
                ep_bb = 1 << self.board.en_passant_sq
                ep_left = (pawns << 7) & ~FILE_H & ep_bb
                ep_right = (pawns << 9) & ~FILE_A & ep_bb
                ep = ep_left | ep_right
        else:
            forward = -8
            left_cap_dir = -9
            right_cap_dir = -7
            double_start = RANK_7
            double_shift = -16
            single = (pawns >> 8) & empty
            double = ((single & double_start) >> 8) & empty
            left_cap = (pawns >> 9) & ~FILE_H & occ_them & MASK64
            right_cap = (pawns >> 7) & ~FILE_A & occ_them & MASK64
            ep = 0
            if self.board.en_passant_sq != -1:
                ep_bb = 1 << self.board.en_passant_sq
                ep_left = (pawns >> 9) & ~FILE_H & ep_bb
                ep_right = (pawns >> 7) & ~FILE_A & ep_bb
                ep = ep_left | ep_right

        def add_pawn_moves(bb, dx, is_promo):
            while bb:
                to_sq, bb = pop_lsb(bb)
                from_sq = to_sq - dx
                if not (0 <= from_sq <= 63 and 0 <= to_sq <= 63):
                    continue
                if is_promo and (1 << to_sq) & promo_rank:
                    for promo_pt in [PieceType.QUEEN, PieceType.ROOK, PieceType.BISHOP, PieceType.KNIGHT]:
                        moves.append((from_sq, to_sq, promo_pt))
                else:
                    moves.append((from_sq, to_sq, None))

        if us == Color.WHITE:
            add_pawn_moves(single, 8, (single & promo_rank) != 0)
            add_pawn_moves(double, 16, False)
            add_pawn_moves(left_cap, 7, (left_cap & promo_rank) != 0)
            add_pawn_moves(right_cap, 9, (right_cap & promo_rank) != 0)
            # En passant moves
            while ep:
                to_sq, ep = pop_lsb(ep)
                if test_bit(pawns << 7, to_sq):
                    from_sq = to_sq - 7
                else:
                    from_sq = to_sq - 9
                if 0 <= from_sq <= 63:
                    moves.append((from_sq, to_sq, None))
        else:
            add_pawn_moves(single, -8, (single & promo_rank) != 0)
            add_pawn_moves(double, -16, False)
            add_pawn_moves(left_cap, -9, (left_cap & promo_rank) != 0)
            add_pawn_moves(right_cap, -7, (right_cap & promo_rank) != 0)
            while ep:
                to_sq, ep = pop_lsb(ep)
                if test_bit(pawns >> 9, to_sq):
                    from_sq = to_sq + 9
                else:
                    from_sq = to_sq + 7
                if 0 <= from_sq <= 63:
                    moves.append((from_sq, to_sq, None))
        return moves

    def _gen_piece_moves(self, pt, us, attack_table):
        moves = []
        pieces = self.board.bb[self.board._piece_index(pt, us)]
        occ_us = self.board.occupancy[us]
        while pieces:
            from_sq, pieces = pop_lsb(pieces)
            attacks = attack_table[from_sq] & ~occ_us & MASK64
            while attacks:
                to_sq, attacks = pop_lsb(attacks)
                if 0 <= to_sq <= 63:
                    moves.append((from_sq, to_sq, None))
        return moves

    def _gen_slider_moves(self, pt, us, dirs):
        moves = []
        pieces = self.board.bb[self.board._piece_index(pt, us)]
        occ_all = (self.board.occupancy[0] | self.board.occupancy[1]) & MASK64
        occ_us = self.board.occupancy[us]
        while pieces:
            from_sq, pieces = pop_lsb(pieces)
            attacks = sliding_attacks(from_sq, occ_all, dirs) & ~occ_us & MASK64
            while attacks:
                to_sq, attacks = pop_lsb(attacks)
                if 0 <= to_sq <= 63:
                    moves.append((from_sq, to_sq, None))
        return moves

    def _gen_castling_moves(self, us):
        moves = []
        occ_all = self.board.occupancy[0] | self.board.occupancy[1]
        if us == Color.WHITE:
            if (self.board.castling_rights & 1) and not (occ_all & 0x60) \
               and not self.board.is_attacked(E1, Color.BLACK) \
               and not self.board.is_attacked(F1, Color.BLACK):
                moves.append((E1, G1, None))
            if (self.board.castling_rights & 2) and not (occ_all & 0x0E) \
               and not self.board.is_attacked(E1, Color.BLACK) \
               and not self.board.is_attacked(D1, Color.BLACK):
                moves.append((E1, C1, None))
        else:
            if (self.board.castling_rights & 4) and not (occ_all & 0x6000000000000000) \
               and not self.board.is_attacked(E8, Color.WHITE) \
               and not self.board.is_attacked(F8, Color.WHITE):
                moves.append((E8, G8, None))
            if (self.board.castling_rights & 8) and not (occ_all & 0x0E00000000000000) \
               and not self.board.is_attacked(E8, Color.WHITE) \
               and not self.board.is_attacked(D8, Color.WHITE):
                moves.append((E8, C8, None))
        return moves
