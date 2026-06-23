from .bitboard import PieceType,Color,popcount,pop_lsb
PIECE_VALUES={PieceType.PAWN:100,PieceType.KNIGHT:320,PieceType.BISHOP:330,PieceType.ROOK:500,PieceType.QUEEN:900,PieceType.KING:20000}
PAWN_TABLE=[0,0,0,0,0,0,0,0,50,50,50,50,50,50,50,50,10,10,20,30,30,20,10,10,5,5,10,25,25,10,5,5,0,0,0,20,20,0,0,0,5,-5,-10,0,0,-10,-5,5,5,10,10,-20,-20,10,10,5,0,0,0,0,0,0,0,0]
KNIGHT_TABLE=[-50,-40,-30,-30,-30,-30,-40,-50,-40,-20,0,0,0,0,-20,-40,-30,0,10,15,15,10,0,-30,-30,5,15,20,20,15,5,-30,-30,0,15,20,20,15,0,-30,-30,5,10,15,15,10,5,-30,-40,-20,0,5,5,0,-20,-40,-50,-40,-30,-30,-30,-30,-40,-50]
BISHOP_TABLE=[-20,-10,-10,-10,-10,-10,-10,-20,-10,0,0,0,0,0,0,-10,-10,0,5,10,10,5,0,-10,-10,5,5,10,10,5,5,-10,-10,0,10,10,10,10,0,-10,-10,10,10,10,10,10,10,-10,-10,5,0,0,0,0,5,-10,-20,-10,-10,-10,-10,-10,-10,-20]
ROOK_TABLE=[0,0,0,0,0,0,0,0,5,10,10,10,10,10,10,5,-5,0,0,0,0,0,0,-5,-5,0,0,0,0,0,0,-5,-5,0,0,0,0,0,0,-5,-5,0,0,0,0,0,0,-5,-5,0,0,0,0,0,0,-5,0,0,0,5,5,0,0,0]
QUEEN_TABLE=[-20,-10,-10,-5,-5,-10,-10,-20,-10,0,0,0,0,0,0,-10,-10,0,5,5,5,5,0,-10,-5,0,5,5,5,5,0,-5,0,0,5,5,5,5,0,-5,-10,5,5,5,5,5,0,-10,-10,0,5,0,0,0,0,-10,-20,-10,-10,-5,-5,-10,-10,-20]
KING_TABLE_MID=[-30,-40,-40,-50,-50,-40,-40,-30,-30,-40,-40,-50,-50,-40,-40,-30,-30,-40,-40,-50,-50,-40,-40,-30,-30,-40,-40,-50,-50,-40,-40,-30,-20,-30,-30,-40,-40,-30,-30,-20,-10,-20,-20,-20,-20,-20,-20,-10,20,20,0,0,0,0,20,20,20,30,10,0,0,10,30,20]
PST={PieceType.PAWN:PAWN_TABLE,PieceType.KNIGHT:KNIGHT_TABLE,PieceType.BISHOP:BISHOP_TABLE,PieceType.ROOK:ROOK_TABLE,PieceType.QUEEN:QUEEN_TABLE,PieceType.KING:KING_TABLE_MID}
def evaluate(board):
    score=0
    for pt in PieceType:
        if pt==PieceType.NO_PIECE: continue
        w_idx=board._piece_index(pt,Color.WHITE); b_idx=board._piece_index(pt,Color.BLACK)
        w_bb=board.bb[w_idx]; b_bb=board.bb[b_idx]
        score+=PIECE_VALUES[pt]*(popcount(w_bb)-popcount(b_bb))
        pst=PST[pt]
        while w_bb:
            sq,w_bb=pop_lsb(w_bb); score+=pst[sq^56]
        while b_bb:
            sq,b_bb=pop_lsb(b_bb); score-=pst[sq]
    return score if board.side_to_move==Color.WHITE else -score
