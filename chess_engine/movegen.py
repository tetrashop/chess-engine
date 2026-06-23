from .bitboard import *
class MoveGenerator:
    def __init__(self,board): self.board=board
    def generate_moves(self):
        moves=[]; us=self.board.side_to_move; them=1-us
        moves+=self._pawns(us,them); moves+=self._piece_moves(PieceType.KNIGHT,us,KNIGHT_ATTACKS); moves+=self._slider_moves(PieceType.BISHOP,us,BISHOP_DIRS); moves+=self._slider_moves(PieceType.ROOK,us,ROOK_DIRS); moves+=self._slider_moves(PieceType.QUEEN,us,ROOK_DIRS+BISHOP_DIRS); moves+=self._piece_moves(PieceType.KING,us,KING_ATTACKS); moves+=self._castling(us)
        return [(f,t,p) for f,t,p in moves if 0<=f<=63 and 0<=t<=63]
    def _pawns(self,us,them):
        moves=[]; pawns=self.board.bb[self.board._piece_index(PieceType.PAWN,us)]; empty=~(self.board.occupancy[0]|self.board.occupancy[1])&0xFFFFFFFFFFFFFFFF; occ_them=self.board.occupancy[them]; promo_rank=RANK_8 if us==Color.WHITE else RANK_1
        if us==Color.WHITE:
            single=(pawns<<8)&empty; double=((single&RANK_3)<<8)&empty; left_cap=(pawns<<7)&~FILE_H&occ_them; right_cap=(pawns<<9)&~FILE_A&occ_them
            ep_bb=(1<<self.board.en_passant_sq) if self.board.en_passant_sq!=-1 else 0; ep_left=(pawns<<7)&~FILE_H&ep_bb; ep_right=(pawns<<9)&~FILE_A&ep_bb; ep=ep_left|ep_right
            def add(bb,dx,promo_mask):
                while bb:
                    to,bb=pop_lsb(bb); fr=to-dx
                    if not (0<=fr<=63): continue
                    if (1<<to)&promo_mask:
                        for pp in (PieceType.QUEEN,PieceType.ROOK,PieceType.BISHOP,PieceType.KNIGHT): moves.append((fr,to,pp))
                    else: moves.append((fr,to,None))
            add(single,8,promo_rank); add(double,16,0); add(left_cap,7,promo_rank); add(right_cap,9,promo_rank)
            while ep:
                to,ep=pop_lsb(ep); fr=to-7 if test_bit(pawns<<7,to) else to-9
                if 0<=fr<=63: moves.append((fr,to,None))
        else:
            single=(pawns>>8)&empty; double=((single&RANK_6)>>8)&empty; left_cap=(pawns>>9)&~FILE_H&occ_them; right_cap=(pawns>>7)&~FILE_A&occ_them
            ep_bb=(1<<self.board.en_passant_sq) if self.board.en_passant_sq!=-1 else 0; ep_left=(pawns>>9)&~FILE_H&ep_bb; ep_right=(pawns>>7)&~FILE_A&ep_bb; ep=ep_left|ep_right
            def add(bb,dx,promo_mask):
                while bb:
                    to,bb=pop_lsb(bb); fr=to-dx
                    if not (0<=fr<=63): continue
                    if (1<<to)&promo_mask:
                        for pp in (PieceType.QUEEN,PieceType.ROOK,PieceType.BISHOP,PieceType.KNIGHT): moves.append((fr,to,pp))
                    else: moves.append((fr,to,None))
            add(single,-8,promo_rank); add(double,-16,0); add(left_cap,-9,promo_rank); add(right_cap,-7,promo_rank)
            while ep:
                to,ep=pop_lsb(ep); fr=to+9 if test_bit(pawns>>9,to) else to+7
                if 0<=fr<=63: moves.append((fr,to,None))
        return moves
    def _piece_moves(self,pt,us,table):
        moves=[]; pieces=self.board.bb[self.board._piece_index(pt,us)]; occ_us=self.board.occupancy[us]
        while pieces:
            fr,pieces=pop_lsb(pieces); attacks=table[fr]&~occ_us
            while attacks: to,attacks=pop_lsb(attacks); moves.append((fr,to,None))
        return moves
    def _slider_moves(self,pt,us,dirs):
        moves=[]; pieces=self.board.bb[self.board._piece_index(pt,us)]; occ_all=self.board.occupancy[0]|self.board.occupancy[1]; occ_us=self.board.occupancy[us]
        while pieces:
            fr,pieces=pop_lsb(pieces); attacks=sliding_attacks(fr,occ_all,dirs)&~occ_us
            while attacks: to,attacks=pop_lsb(attacks); moves.append((fr,to,None))
        return moves
    def _castling(self,us):
        moves=[]; occ_all=self.board.occupancy[0]|self.board.occupancy[1]
        if us==Color.WHITE:
            if (self.board.castling_rights&1) and not (occ_all&0x60) and not self.board.is_attacked(E1,Color.BLACK) and not self.board.is_attacked(F1,Color.BLACK): moves.append((E1,G1,None))
            if (self.board.castling_rights&2) and not (occ_all&0x0E) and not self.board.is_attacked(E1,Color.BLACK) and not self.board.is_attacked(D1,Color.BLACK): moves.append((E1,C1,None))
        else:
            if (self.board.castling_rights&4) and not (occ_all&0x6000000000000000) and not self.board.is_attacked(E8,Color.WHITE) and not self.board.is_attacked(F8,Color.WHITE): moves.append((E8,G8,None))
            if (self.board.castling_rights&8) and not (occ_all&0x0E00000000000000) and not self.board.is_attacked(E8,Color.WHITE) and not self.board.is_attacked(D8,Color.WHITE): moves.append((E8,C8,None))
        return moves
