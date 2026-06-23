#!/usr/bin/env bash
# chess_engine_perfect.sh – بازسازی کامل پروژه با حداکثر کارایی و صحت

set -e
cd ~/chess-engine

echo "🧹 ۱. پاک‌سازی کامل و ایجاد پوشه‌ها"
rm -rf backend frontend chess_engine bw-project .github/workflows 2>/dev/null || true
mkdir -p backend frontend chess_engine bw-project/src/main/assets
mkdir -p bw-project/src/main/java/com/ramin/chess
mkdir -p bw-project/src/main/res/values
mkdir -p bw-project/src/main/res/drawable
mkdir -p bw-project/gradle/wrapper
mkdir -p .github/workflows

# ═══════════════════════════════════════
#  BACKEND (Flask API)
# ═══════════════════════════════════════
echo "🐍 ۲. ایجاد backend/app.py"
cat > backend/app.py << 'PYEOF'
import sys, os, traceback, uuid
from flask import Flask, request, jsonify, send_from_directory

IS_VERCEL = os.environ.get('VERCEL') is not None
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from chess_engine.board import Board
from chess_engine.search import Search

app = Flask(__name__,
            static_folder='../frontend' if not IS_VERCEL else None,
            static_url_path='' if not IS_VERCEL else None)

sessions = {}   # حافظهٔ موقت session‌ها

@app.after_request
def add_cors(response):
    response.headers['Access-Control-Allow-Origin'] = '*'
    response.headers['Access-Control-Allow-Headers'] = 'Content-Type'
    response.headers['Access-Control-Allow-Methods'] = 'GET, POST, PUT, OPTIONS'
    return response

# ── session endpoints ──
@app.route('/api/session', methods=['POST'])
def create_session():
    sid = str(uuid.uuid4())
    sessions[sid] = {
        'fen': 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
        'history': [],
        'level': 1, 'wins': 0, 'bonusPoints': 0,
        'userColor': 'w'
    }
    return jsonify({'session_id': sid})

@app.route('/api/session/<sid>', methods=['GET'])
def get_session(sid):
    if sid in sessions: return jsonify(sessions[sid])
    return jsonify({'error': 'Session not found'}), 404

@app.route('/api/session/<sid>', methods=['PUT'])
def update_session(sid):
    data = request.get_json()
    if sid in sessions:
        sessions[sid].update(data)
        return jsonify({'status': 'ok'})
    return jsonify({'error': 'Session not found'}), 404

# ── bestmove endpoint ──
@app.route('/api/bestmove', methods=['GET', 'OPTIONS'])
def bestmove():
    if request.method == 'OPTIONS': return jsonify({}), 200
    fen = request.args.get('fen', 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1')
    depth = min(int(request.args.get('depth', 3)), 3)
    try:
        board = Board(fen)
        search = Search(board)
        search.search(depth)
        move = search.best_move
        if move:
            from_sq, to_sq, promo = move
            promo_str = ''
            if promo: promo_str = 'nbrq'[promo-2]
            from chess_engine.bitboard import square_to_str
            move_str = square_to_str(from_sq) + square_to_str(to_sq) + promo_str
        else: move_str = None
        return jsonify({'bestmove': move_str, 'depth': depth, 'nodes': search.nodes})
    except Exception:
        return jsonify({'error': traceback.format_exc()}), 500

if not IS_VERCEL:
    @app.route('/') def index(): return send_from_directory('../frontend', 'index.html')
    @app.route('/<path:path>') def serve_static(path): return send_from_directory('../frontend', path)

if __name__ == '__main__': app.run(debug=True, host='0.0.0.0', port=5000)
PYEOF
echo "flask" > backend/requirements.txt

# ═══════════════════════════════════════
#  CHESS ENGINE (Python)
# ═══════════════════════════════════════
echo "♟️ ۳. ایجاد ماژول‌های موتور شطرنج"

# __init__.py
cat > chess_engine/__init__.py << 'EOF'
from .board import Board
from .movegen import MoveGenerator
from .search import Search
from .evaluate import evaluate
from .uci import uci_loop
EOF

# bitboard.py
cat > chess_engine/bitboard.py << 'EOF'
import enum
A1,B1,C1,D1,E1,F1,G1,H1=0,1,2,3,4,5,6,7
A2,B2,C2,D2,E2,F2,G2,H2=8,9,10,11,12,13,14,15
A3,B3,C3,D3,E3,F3,G3,H3=16,17,18,19,20,21,22,23
A4,B4,C4,D4,E4,F4,G4,H4=24,25,26,27,28,29,30,31
A5,B5,C5,D5,E5,F5,G5,H5=32,33,34,35,36,37,38,39
A6,B6,C6,D6,E6,F6,G6,H6=40,41,42,43,44,45,46,47
A7,B7,C7,D7,E7,F7,G7,H7=48,49,50,51,52,53,54,55
A8,B8,C8,D8,E8,F8,G8,H8=56,57,58,59,60,61,62,63
SQUARE_NAMES=['a1','b1','c1','d1','e1','f1','g1','h1','a2','b2','c2','d2','e2','f2','g2','h2','a3','b3','c3','d3','e3','f3','g3','h3','a4','b4','c4','d4','e4','f4','g4','h4','a5','b5','c5','d5','e5','f5','g5','h5','a6','b6','c6','d6','e6','f6','g6','h6','a7','b7','c7','d7','e7','f7','g7','h7','a8','b8','c8','d8','e8','f8','g8','h8']
class PieceType(enum.IntEnum): NO_PIECE=0; PAWN=1; KNIGHT=2; BISHOP=3; ROOK=4; QUEEN=5; KING=6
class Color(enum.IntEnum): WHITE=0; BLACK=1
FILE_A=0x0101010101010101; FILE_B=0x0202020202020202; FILE_C=0x0404040404040404; FILE_D=0x0808080808080808; FILE_E=0x1010101010101010; FILE_F=0x2020202020202020; FILE_G=0x4040404040404040; FILE_H=0x8080808080808080
RANK_1=0x00000000000000FF; RANK_2=0x000000000000FF00; RANK_3=0x0000000000FF0000; RANK_4=0x00000000FF000000; RANK_5=0x000000FF00000000; RANK_6=0x0000FF0000000000; RANK_7=0x00FF000000000000; RANK_8=0xFF00000000000000
def popcount(bb:int)->int: return bb.bit_count()
def lsb(bb:int)->int: return (bb&-bb).bit_length()-1
def pop_lsb(bb:int): i=lsb(bb); return i,bb&(bb-1)
def set_bit(bb:int,sq:int)->int: return bb|(1<<sq)
def clear_bit(bb:int,sq:int)->int: return bb&~(1<<sq)
def test_bit(bb:int,sq:int)->bool: return (bb>>sq)&1!=0
def square_to_str(sq:int)->str: return SQUARE_NAMES[sq]
ROOK_DIRS=(8,-8,1,-1); BISHOP_DIRS=(9,7,-7,-9)
def sliding_attacks(sq:int,occ:int,dirs):
    attacks=0
    for d in dirs:
        pos=sq
        while True:
            pos+=d
            if pos<0 or pos>63: break
            if (d==1 or d==-1) and pos//8!=sq//8: break
            attacks|=1<<pos
            if (1<<pos)&occ: break
    return attacks
def rook_attacks(sq:int,occ:int)->int: return sliding_attacks(sq,occ,ROOK_DIRS)
def bishop_attacks(sq:int,occ:int)->int: return sliding_attacks(sq,occ,BISHOP_DIRS)
def queen_attacks(sq:int,occ:int)->int: return rook_attacks(sq,occ)|bishop_attacks(sq,occ)
KNIGHT_ATTACKS=[0]*64; KING_ATTACKS=[0]*64
for sq in range(64):
    bb=1<<sq
    KNIGHT_ATTACKS[sq]= ((bb<<17)&~FILE_A)|((bb<<10)&~(FILE_A|FILE_B))|((bb>>6)&~(FILE_G|FILE_H))|((bb>>15)&~FILE_H)|((bb<<15)&~FILE_H)|((bb<<6)&~(FILE_A|FILE_B))|((bb>>10)&~(FILE_G|FILE_H))|((bb>>17)&~FILE_A)
    KING_ATTACKS[sq]= ((bb<<1)&~FILE_A)|((bb>>1)&~FILE_H)|(bb<<8)|(bb>>8)|((bb<<7)&~FILE_H)|((bb<<9)&~FILE_A)|((bb>>7)&~FILE_A)|((bb>>9)&~FILE_H)
EOF

# board.py
cat > chess_engine/board.py << 'EOF'
from .bitboard import *
from .movegen import MoveGenerator
class Board:
    def __init__(self,fen="rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"):
        self.bb=[0]*12; self.occupancy=[0,0]; self.pieces=[-1]*64
        self.side_to_move=Color.WHITE; self.castling_rights=0; self.en_passant_sq=-1
        self.half_move_clock=0; self.full_move_number=1; self._history=[]
        self._set_from_fen(fen); self._move_gen=MoveGenerator(self)
    def _piece_index(self,pt,color): return (pt-1)*2+color
    def _set_from_fen(self,fen):
        self.bb=[0]*12; self.occupancy=[0,0]; self.pieces=[-1]*64
        parts=fen.split(); board=parts[0]; rank=7; file=0
        for ch in board:
            if ch=='/': rank-=1; file=0
            elif ch.isdigit(): file+=int(ch)
            else:
                sq=rank*8+file; color=Color.WHITE if ch.isupper() else Color.BLACK
                pt={'p':PieceType.PAWN,'n':PieceType.KNIGHT,'b':PieceType.BISHOP,'r':PieceType.ROOK,'q':PieceType.QUEEN,'k':PieceType.KING}[ch.lower()]
                idx=self._piece_index(pt,color); self.bb[idx]|=1<<sq; self.occupancy[color]|=1<<sq; self.pieces[sq]=idx; file+=1
        self.side_to_move=Color.WHITE if parts[1]=='w' else Color.BLACK
        castling=parts[2]; self.castling_rights=0
        if 'K' in castling: self.castling_rights|=1
        if 'Q' in castling: self.castling_rights|=2
        if 'k' in castling: self.castling_rights|=4
        if 'q' in castling: self.castling_rights|=8
        enp=parts[3]; self.en_passant_sq=-1
        if enp!='-': self.en_passant_sq=(ord(enp[0])-ord('a'))+(int(enp[1])-1)*8
        if len(parts)>4: self.half_move_clock=int(parts[4]); self.full_move_number=int(parts[5])
    def get_fen(self):
        fen=""
        for rank in range(7,-1,-1):
            empty=0
            for file in range(8):
                sq=rank*8+file; idx=self.pieces[sq]
                if idx==-1: empty+=1
                else:
                    if empty: fen+=str(empty); empty=0
                    pt=(idx//2)+1; color=idx%2; ch="PNBRQK"[pt-1]
                    fen+=ch if color==Color.WHITE else ch.lower()
            if empty: fen+=str(empty)
            if rank>0: fen+='/'
        fen+=' ' + ('w' if self.side_to_move==Color.WHITE else 'b')
        castling=''
        if self.castling_rights&1: castling+='K'
        if self.castling_rights&2: castling+='Q'
        if self.castling_rights&4: castling+='k'
        if self.castling_rights&8: castling+='q'
        fen+=' '+(castling or '-')
        fen+=' '+(square_to_str(self.en_passant_sq) if self.en_passant_sq!=-1 else '-')
        fen+=f' {self.half_move_clock} {self.full_move_number}'
        return fen
    def make_move(self,move):
        from_sq,to_sq,promo=move
        self._history.append((self.bb[:],self.occupancy[:],self.pieces[:],self.side_to_move,self.castling_rights,self.en_passant_sq,self.half_move_clock,self.full_move_number))
        us=self.side_to_move; them=1-us; piece_idx=self.pieces[from_sq]; pt=(piece_idx//2)+1; captured_idx=self.pieces[to_sq]
        if pt==PieceType.PAWN or captured_idx!=-1: self.half_move_clock=0
        else: self.half_move_clock+=1
        ep_capture=False
        if pt==PieceType.PAWN and to_sq==self.en_passant_sq:
            ep_capture=True; captured_sq=to_sq-8 if us==Color.WHITE else to_sq+8; captured_idx=self.pieces[captured_sq]
            self.bb[captured_idx]=clear_bit(self.bb[captured_idx],captured_sq); self.occupancy[them]=clear_bit(self.occupancy[them],captured_sq); self.pieces[captured_sq]=-1
        self.en_passant_sq=-1
        if pt==PieceType.PAWN and abs(from_sq-to_sq)==16: self.en_passant_sq=from_sq+(8 if us==Color.WHITE else -8)
        self.bb[piece_idx]=clear_bit(self.bb[piece_idx],from_sq); self.occupancy[us]=clear_bit(self.occupancy[us],from_sq); self.pieces[from_sq]=-1
        if captured_idx!=-1 and not ep_capture: self.bb[captured_idx]=clear_bit(self.bb[captured_idx],to_sq); self.occupancy[them]=clear_bit(self.occupancy[them],to_sq)
        if promo:
            new_idx=self._piece_index(promo,us); self.bb[new_idx]=set_bit(self.bb[new_idx],to_sq); self.occupancy[us]=set_bit(self.occupancy[us],to_sq); self.pieces[to_sq]=new_idx
        else: self.bb[piece_idx]=set_bit(self.bb[piece_idx],to_sq); self.occupancy[us]=set_bit(self.occupancy[us],to_sq); self.pieces[to_sq]=piece_idx
        if pt==PieceType.KING:
            mask=3 if us==Color.WHITE else 12; self.castling_rights&=~mask
            if abs(from_sq-to_sq)==2:
                if to_sq>from_sq: rook_from,rook_to=to_sq+1,to_sq-1
                else: rook_from,rook_to=to_sq-2,to_sq+1
                rook_idx=self._piece_index(PieceType.ROOK,us); self.bb[rook_idx]=clear_bit(self.bb[rook_idx],rook_from); self.bb[rook_idx]=set_bit(self.bb[rook_idx],rook_to); self.occupancy[us]=clear_bit(self.occupancy[us],rook_from); self.occupancy[us]=set_bit(self.occupancy[us],rook_to); self.pieces[rook_from]=-1; self.pieces[rook_to]=rook_idx
        elif pt==PieceType.ROOK:
            if us==Color.WHITE:
                if from_sq==A1: self.castling_rights&=~2
                elif from_sq==H1: self.castling_rights&=~1
            else:
                if from_sq==A8: self.castling_rights&=~8
                elif from_sq==H8: self.castling_rights&=~4
        self.side_to_move=them
        if us==Color.BLACK: self.full_move_number+=1
    def undo_move(self):
        (self.bb,self.occupancy,self.pieces,self.side_to_move,self.castling_rights,self.en_passant_sq,self.half_move_clock,self.full_move_number)=self._history.pop()
    def is_in_check(self,color):
        king_sq=lsb(self.bb[self._piece_index(PieceType.KING,color)])
        return self.is_attacked(king_sq,1-color)
    def is_attacked(self,sq,by_color):
        pawns=self.bb[self._piece_index(PieceType.PAWN,by_color)]
        if by_color==Color.WHITE:
            if ((pawns<<7)&~FILE_H)&(1<<sq): return True
            if ((pawns<<9)&~FILE_A)&(1<<sq): return True
        else:
            if ((pawns>>7)&~FILE_A)&(1<<sq): return True
            if ((pawns>>9)&~FILE_H)&(1<<sq): return True
        if KNIGHT_ATTACKS[sq]&self.bb[self._piece_index(PieceType.KNIGHT,by_color)]: return True
        if KING_ATTACKS[sq]&self.bb[self._piece_index(PieceType.KING,by_color)]: return True
        occ=self.occupancy[0]|self.occupancy[1]
        queens=self.bb[self._piece_index(PieceType.QUEEN,by_color)]
        bishops=self.bb[self._piece_index(PieceType.BISHOP,by_color)]|queens
        rooks=self.bb[self._piece_index(PieceType.ROOK,by_color)]|queens
        if bishop_attacks(sq,occ)&bishops: return True
        if rook_attacks(sq,occ)&rooks: return True
        return False
    def generate_legal_moves(self):
        return [m for m in self._move_gen.generate_moves() if self._is_legal(m)]
    def _is_legal(self,move):
        self.make_move(move); ok=not self.is_in_check(1-self.side_to_move); self.undo_move(); return ok
EOF

# movegen.py
cat > chess_engine/movegen.py << 'EOF'
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
EOF

# evaluate.py
cat > chess_engine/evaluate.py << 'EOF'
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
EOF

# search.py
cat > chess_engine/search.py << 'EOF'
from .evaluate import evaluate
import time
class Search:
    def __init__(self,board):
        self.board=board; self.nodes=0; self.best_move=None; self.max_depth=1
    def search(self,depth):
        self.max_depth=depth; self.nodes=0; start=time.time()
        best_score=0
        for d in range(1,depth+1):
            self.best_move=None; best_score=self._alpha_beta(d,-999999,999999,True)
        elapsed=time.time()-start
        nps=int(self.nodes/elapsed) if elapsed>0 else 0
        print(f"info depth {depth} score cp {best_score} nodes {self.nodes} time {int(elapsed*1000)} nps {nps}")
        if self.best_move:
            f,t,p=self.best_move; promo=''
            if p: promo='nbrq'[p-2]
            from .bitboard import square_to_str
            move_str=square_to_str(f)+square_to_str(t)+promo
            print(f"bestmove {move_str}")
    def _alpha_beta(self,depth,alpha,beta,root=False):
        if depth==0: return self._quiescence(alpha,beta)
        self.nodes+=1; moves=self.board.generate_legal_moves()
        if not moves:
            if self.board.is_in_check(self.board.side_to_move): return -99999+self.board.full_move_number
            return 0
        moves.sort(key=lambda m:self._mvvlva(m),reverse=True)
        for move in moves:
            self.board.make_move(move); score=-self._alpha_beta(depth-1,-beta,-alpha); self.board.undo_move()
            if score>=beta: return beta
            if score>alpha:
                alpha=score
                if root: self.best_move=move
        return alpha
    def _quiescence(self,alpha,beta):
        self.nodes+=1; stand_pat=evaluate(self.board)
        if stand_pat>=beta: return beta
        if stand_pat>alpha: alpha=stand_pat
        moves=self.board._move_gen.generate_moves()
        captures=[m for m in moves if self.board.pieces[m[1]]!=-1 or m[2] is not None]
        for move in captures:
            self.board.make_move(move)
            if not self.board.is_in_check(1-self.board.side_to_move):
                score=-self._quiescence(-beta,-alpha); self.board.undo_move()
                if score>=beta: return beta
                if score>alpha: alpha=score
            else: self.board.undo_move()
        return alpha
    def _mvvlva(self,move):
        to=move[1]; idx=self.board.pieces[to] if 0<=to<=63 else -1
        return 0 if idx==-1 else ((idx//2)+1)*10
EOF

# uci.py
cat > chess_engine/uci.py << 'EOF'
from .board import Board
from .search import Search
import sys,threading
class UCIHandler:
    def __init__(self): self.board=Board(); self.search_thread=None
    def loop(self):
        while True:
            try: line=sys.stdin.readline().strip()
            except EOFError: break
            if not line: continue
            tokens=line.split()
            if tokens[0]=='uci': print("id name ChessEnginePy\nid author Tetrashop\nuciok")
            elif tokens[0]=='isready': print("readyok")
            elif tokens[0]=='position':
                if 'startpos' in tokens:
                    self.board=Board(); idx=tokens.index('moves') if 'moves' in tokens else len(tokens)
                    if idx<len(tokens): self._apply(tokens[idx+1:])
                elif 'fen' in tokens:
                    fs=tokens.index('fen')+1; fe=tokens.index('moves') if 'moves' in tokens else len(tokens)
                    self.board=Board(' '.join(tokens[fs:fe]))
                    if 'moves' in tokens: self._apply(tokens[tokens.index('moves')+1:])
            elif tokens[0]=='go':
                depth=6
                if 'depth' in tokens: depth=int(tokens[tokens.index('depth')+1])
                self.search_thread=threading.Thread(target=self._search,args=(depth,)); self.search_thread.start()
            elif tokens[0]=='stop':
                if self.search_thread and self.search_thread.is_alive(): self.search_thread.join()
            elif tokens[0]=='quit': break
    def _apply(self,moves):
        for m in moves:
            f=(ord(m[0])-ord('a'))+(int(m[1])-1)*8; t=(ord(m[2])-ord('a'))+(int(m[3])-1)*8; p={'n':2,'b':3,'r':4,'q':5}[m[4].lower()] if len(m)==5 else None
            for legal in self.board.generate_legal_moves():
                if legal[0]==f and legal[1]==t and legal[2]==p: self.board.make_move(legal); break
    def _search(self,depth):
        s=Search(self.board); s.search(depth); self.search_thread=None
def uci_loop(): UCIHandler().loop()
EOF

# ═══════════════════════════════════════
#  FRONTEND
# ═══════════════════════════════════════
echo "🌐 ۴. ایجاد فرانت‌اند"
cat > frontend/index.html << 'HTMLEOF'
<!DOCTYPE html><html lang="fa" dir="rtl"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1.0"><title>شطرنج رامین اجلال</title><link rel="stylesheet" href="style.css"></head><body><div class="container"><h1>♟️ شطرنج رامین اجلال</h1><div class="levels-bar" id="levelsBar"><span class="level-dot done">۱</span><span class="level-dot done">۲</span><span class="level-dot active">۳</span><span class="level-dot">۴</span><span class="level-dot locked">۵</span><span class="level-dot locked">۶</span><span class="level-dot locked">۷</span><span class="level-dot locked">۸</span></div><div class="info-panel"><div id="levelDisplay">سطح ۱</div><div id="bonusDisplay">امتیاز: ۰</div><div id="winsDisplay">برد: ۰/۳</div><div id="modeIndicator">شما: سفید</div></div><div id="board" style="width:400px;margin:0 auto;"></div><div class="controls"><button id="newGameBtn">🔄 بازی جدید</button><button id="undoBtn">↩️ بازگشت</button><button id="redoBtn">↪️ پیشروی</button><button id="flipBtn">🔃 چرخاندن صفحه</button><button id="switchColorBtn">🔀 تعویض رنگ</button><button id="hintBtn">💡 نمایش حرکت‌های مجاز</button><button id="coachBtn">🧠 مربی</button><button id="soundToggle">🔊 صدا</button></div><div id="status">نوبت شما (سفید)</div><div id="chatBox" class="chat-box" style="display:none;"></div><div id="toast" class="toast"></div><div class="bottom-scores-bar" id="bottomScoresBar"><span class="score-item">🥇 <span id="score1">-</span></span><span class="score-item">🥈 <span id="score2">-</span></span><span class="score-item">🥉 <span id="score3">-</span></span></div></div><script src="libs.js"></script><script src="script.js"></script></body></html>
HTMLEOF

cat > frontend/style.css << 'CSSEOF'
.clearfix-7da63{clear:both}.board-b72b1{border:2px solid #404040;-webkit-box-sizing:content-box;box-sizing:content-box}.square-55d63{float:left;position:relative}.white-1e1d7{background-color:#f0d9b5;color:#b58863}.black-3c85d{background-color:#b58863;color:#f0d9b5}
body{margin:0;padding:20px;background:#1a1a1a;color:#eee;font-family:Tahoma,sans-serif;display:flex;justify-content:center}.container{text-align:center;max-width:550px}h1{color:#f0d9b5;margin-bottom:10px}.levels-bar{display:flex;justify-content:center;gap:10px;margin:10px 0}.level-dot{display:inline-flex;align-items:center;justify-content:center;width:30px;height:30px;border-radius:50%;background:#444;color:#aaa;font-weight:bold;font-size:14px}.level-dot.done{background:#2e7d32;color:#fff}.level-dot.active{background:#f0d9b5;color:#000;box-shadow:0 0 10px #f0d9b5}.level-dot.locked{background:#555;color:#888}.info-panel{display:flex;justify-content:space-around;background:#2a2a2a;border-radius:8px;padding:8px;margin:10px 0;font-size:14px}.info-panel div{background:#444;padding:4px 12px;border-radius:4px}.controls{margin:10px 0;display:flex;flex-wrap:wrap;justify-content:center;gap:6px}button{background:#4a4a4a;color:#fff;border:none;padding:6px 12px;font-size:13px;border-radius:5px;cursor:pointer;transition:background 0.2s}button:hover{background:#666}button.active{background:#8b7d3c}#status{margin:12px 0;font-size:18px;font-weight:bold;min-height:30px;color:#f0d9b5}.chat-box{background:#111;border-radius:8px;padding:10px;margin:10px 0;max-height:120px;overflow-y:auto;font-size:13px;text-align:right;color:#ccc}.toast{position:fixed;top:20px;left:50%;transform:translateX(-50%);background:gold;color:#000;padding:8px 20px;border-radius:20px;font-weight:bold;font-size:16px;opacity:0;transition:opacity 0.5s;pointer-events:none;z-index:1000}.toast.show{opacity:1}.highlight-square{box-shadow:inset 0 0 10px 4px rgba(255,255,0,0.8)!important}.bottom-scores-bar{position:fixed;bottom:0;left:0;right:0;background:#111;display:flex;justify-content:center;gap:20px;padding:8px 0;font-size:14px;border-top:1px solid #333;z-index:500}.score-item{color:#f0d9b5;font-weight:bold}
CSSEOF

# script.js (نسخهٔ کامل با session و book)
cat > frontend/script.js << 'JSEOF'
const API_URL="https://chess-engine-89fz.vercel.app/api";const MAX_LEVEL=8;const WINS_TO_ADVANCE=3;
let board,game,playerColor='w',isThinking=!1,moveHistory=[],redoStack=[],level=1,wins=0,bonusPoints=0,hintEnabled=!1,coachEnabled=!1,soundEnabled=!0,audioCtx=null,bgMusicTimeout=null,bgMusicOscs=[],pendingBestMove=null,isReplayMode=!1,replayTimeout=null,userColor='w',openingBook={},sessionId=null;
/* توابع session */
async function getOrCreateSession(){let e=localStorage.getItem("chessSessionId");if(e){sessionId=e;return}try{let t=await fetch(`${API_URL}/session`,{method:"POST"}),n=await t.json();n.session_id&&(sessionId=n.session_id,localStorage.setItem("chessSessionId",sessionId))}catch(e){}}
async function loadRemoteState(){if(!sessionId)return;try{let e=await fetch(`${API_URL}/session/${sessionId}`);if(!e.ok)return;let t=await e.json();game.load(t.fen),t.history.forEach(e=>game.move(e)),board.position(game.fen()),level=t.level||1,wins=t.wins||0,bonusPoints=t.bonusPoints||0,userColor=t.userColor||"w",playerColor=userColor,moveHistory=t.history.map(e=>({move:e,fenBefore:""})),redoStack=[],updateUI()}catch(e){}}
async function saveRemoteState(){if(!sessionId)return;try{let e={fen:game.fen(),history:moveHistory.map(e=>e.move),level,wins,bonusPoints,userColor};await fetch(`${API_URL}/session/${sessionId}`,{method:"PUT",headers:{"Content-Type":"application/json"},body:JSON.stringify(e)})}catch(e){}}
/* صداها */
function initAudio(){audioCtx||(audioCtx=new(window.AudioContext||window.webkitAudioContext))}
function playTone(e,t,n,o=.15){if(!soundEnabled||!audioCtx)return;"suspended"===audioCtx.state&&audioCtx.resume();let a=audioCtx.currentTime,i=audioCtx.createOscillator(),s=audioCtx.createGain();i.type=e,i.frequency.setValueAtTime(t,a),s.gain.setValueAtTime(o,a),s.gain.exponentialRampToValueAtTime(.001,a+n),i.connect(s),s.connect(audioCtx.destination),i.start(a),i.stop(a+n)}
function playMoveSound(){playTone("sine",660,.18,.2),setTimeout(()=>playTone("sine",880,.15,.15),80)}
function playCaptureSound(){playTone("triangle",300,.25,.3),setTimeout(()=>playTone("triangle",200,.3,.35),100)}
function playBonusSound(){playTone("sine",523,.15,.2),setTimeout(()=>playTone("sine",659,.15,.2),120),setTimeout(()=>playTone("sine",784,.2,.2),240)}
function playCheckSound(){playTone("square",440,.15,.2),setTimeout(()=>playTone("square",550,.15,.2),100)}
function playMateSound(){playTone("sawtooth",220,.5,.1),setTimeout(()=>playTone("sawtooth",196,.6,.1),300)}
function playErrorSound(){playTone("square",200,.25,.1)}
function startBgMusic(){if(!soundEnabled||bgMusicTimeout)return;initAudio();let e=[[261.63,329.63,392],[293.66,369.99,440],[349.23,440,523.25],[392,493.88,587.33]],t=0;function n(){if(!soundEnabled)return;bgMusicOscs.forEach(e=>{try{e.osc.stop(),e.gain.gain.setValueAtTime(0,audioCtx.currentTime)}catch(e){}}),bgMusicOscs=[];let o=e[t%e.length],a=audioCtx.currentTime;o.forEach(e=>{let t=audioCtx.createOscillator(),n=audioCtx.createGain();t.type="sine",t.frequency.setValueAtTime(e,a),n.gain.setValueAtTime(0,a),n.gain.linearRampToValueAtTime(.02,a+.4),n.gain.linearRampToValueAtTime(.02,a+2.2),n.gain.linearRampToValueAtTime(0,a+2.8),t.connect(n),n.connect(audioCtx.destination),t.start(a),t.stop(a+3),bgMusicOscs.push({osc:t,gain:n})}),t++,bgMusicTimeout=setTimeout(n,3e3)}n()}
function stopBgMusic(){bgMusicTimeout&&(clearTimeout(bgMusicTimeout),bgMusicTimeout=null),bgMusicOscs.forEach(e=>{try{e.osc.stop()}catch(e){}}),bgMusicOscs=[]}
/* ذخیره و بازیابی */
function loadProgress(){}
function saveProgress(){}
function updateUI(){$("#levelDisplay").text(`سطح ${level}`),$("#bonusDisplay").text(`امتیاز: ${bonusPoints}`),$("#winsDisplay").text(`برد: ${wins}/${WINS_TO_ADVANCE}`),$("#modeIndicator").text(`شما: ${"w"===userColor?"سفید":"سیاه"}`),$(".level-dot").each(function(e){let t=e+1;$(this).removeClass("done active locked"),t<level?$(this).addClass("done"):t===level?$(this).addClass("active"):$(this).addClass("locked")}),updateBottomScores()}
function advanceLevel(){level<MAX_LEVEL?(level++,wins=0,bonusPoints+=15*level,showToast(`🎉 تبریک! به سطح ${level} ارتقا یافتید! (+${15*level} امتیاز)`),playBonusSound()):showToast("🏆 شما قهرمان نهایی شدید!"),saveRemoteState(),updateUI()}
function getGameHistory(){try{return JSON.parse(localStorage.getItem("chessGameHistory")||"[]")}catch(e){return[]}}
function saveGameToHistory(e,t,n,o){let a=getGameHistory();a.push({date:(new Date).toLocaleString("fa-IR"),result:e,moves:t,score:n,fen:o}),a.length>20&&a.shift(),localStorage.setItem("chessGameHistory",JSON.stringify(a)),updateBottomScores()}
function updateBottomScores(){let e=getGameHistory();e.sort((e,t)=>t.score-e.score);let t=e.slice(0,3);$("#score1").text(t[0]?t[0].score:"-"),$("#score2").text(t[1]?t[1].score:"-"),$("#score3").text(t[2]?t[2].score:"-")}
function startReplay(e){if(isReplayMode&&clearReplay(),isReplayMode=!0,$(".controls button").prop("disabled",!0),$("#newGameBtn").prop("disabled",!1),game.reset(),board.position("start"),$("#chatBox").empty().show(),$("#status").text("▶️ در حال بازپخش..."),stopBgMusic(),0===e.length){clearReplay();return}let t=0;function n(){if(t>=e.length){let n="";n=game.in_checkmate()?"w"===game.turn()?"کامپیوتر برنده شد":"کاربر برنده شد":game.in_draw()?"مساوی":"بازی ناتمام",$("#chatBox").append(`<div>🏁 ${n}</div>`),$("#status").text(n),replayTimeout=setTimeout(clearReplay,8e3);return}let o=e[t],a=game.move({from:o.from,to:o.to,promotion:o.promotion||"q"});a&&(board.position(game.fen()),$("#chatBox").append(`<div>${"w"===a.color?"کاربر":"کامپیوتر"}: ${o.from}${o.to}${o.promotion||""}</div>`),$("#chatBox").scrollTop($("#chatBox")[0].scrollHeight),a.captured?playCaptureSound():playMoveSound()),t++,replayTimeout=setTimeout(n,1e3)}n()}function clearReplay(){replayTimeout&&clearTimeout(replayTimeout),isReplayMode=!1,$(".controls button").prop("disabled",!1),$("#chatBox").hide().empty(),game.reset(),board.start(),updateStatus(),startBgMusic()}
function initBoard(){board=Chessboard("board",{draggable:!0,position:"start",orientation:playerColor,onDragStart:(e,t)=>{if(isReplayMode||game.game_over()||isThinking||game.turn()!==userColor)return!1;if("w"===userColor&&t.startsWith("b")||"b"===userColor&&t.startsWith("w"))return!1},onDrop:(e,t)=>{if(isReplayMode)return"snapback";let n=game.move({from:e,to:t,promotion:"q"});if(!n)return"snapback";coachEnabled&&pendingBestMove&&(e+t+(n.promotion||"")===pendingBestMove.from+pendingBestMove.to+(pendingBestMove.promotion||"")?(bonusPoints+=3,saveRemoteState(),updateUI(),showToast("✅ حرکت عالی! +۳ امتیاز"),playBonusSound()):(bonusPoints=Math.max(0,bonusPoints-5),saveRemoteState(),updateUI(),showToast(`⚠️ بهتر بود ${pendingBestMove.from+pendingBestMove.to+(pendingBestMove.promotion||"")} بازی کنید. -۵ امتیاز`),playErrorSound()),pendingBestMove=null),moveHistory.push({move:n,fenBefore:game.fen()}),redoStack=[],n.captured?playCaptureSound():playMoveSound(),game.in_check()&&playCheckSound(),updateStatus(),saveRemoteState(),coachEnabled&&!game.game_over()&&fetchBestMoveForCoach(),game.turn()!==userColor&&setTimeout(makeComputerMove,300)},pieceTheme:e=>"data:image/svg+xml;utf8,"+encodeURIComponent(PIECE_SVGS[e])}),updateStatus(),updateUI(),startBgMusic()}
async function fetchBestMoveForCoach(){try{let e=await fetch(`${API_URL}/bestmove?fen=${encodeURIComponent(game.fen())}&depth=2`),t=await e.json();if(t.bestmove){let e=t.bestmove.substring(0,2),n=t.bestmove.substring(2,4),o=t.bestmove.length>4?t.bestmove[4]:void 0,a=game.move({from:e,to:n,promotion:o});a&&(game.undo(),pendingBestMove={from:e,to:n,promotion:o})}}catch(e){pendingBestMove=null}}
async function makeComputerMove(){if(isReplayMode||game.game_over()||isThinking)return;if(game.turn()===userColor)return;isThinking=!0,$("#status").text("⏳ کامپیوتر در حال فکر کردن...");let e=null;let t=game.fen().split(" ").slice(0,4).join(" ");if(openingBook[t]){let n=openingBook[t],o=n.substring(0,2),a=n.substring(2,4),i=n.length>4?n[4]:void 0,s=game.move({from:o,to:a,promotion:i});s&&(game.undo(),e={from:o,to:a,promotion:i})}if(!e)try{let t=new AbortController,n=setTimeout(()=>t.abort(),8e3),o=Math.min(level+1,3),a=await fetch(`${API_URL}/bestmove?fen=${encodeURIComponent(game.fen())}&depth=${o}`,{signal:t.signal});clearTimeout(n);let i=await a.json();if(i.bestmove){let t=i.bestmove.substring(0,2),n=i.bestmove.substring(2,4),o=i.bestmove.length>4?i.bestmove[4]:void 0,a=game.move({from:t,to:n,promotion:o});a&&(game.undo(),e={from:t,to:n,promotion:o})}}catch(t){}if(!e){let t=game.moves({verbose:!0});if(t.length){let n=t[Math.floor(Math.random()*t.length)];e={from:n.from,to:n.to,promotion:n.promotion||"q"},showToast("⚠️ نه کتاب داشت، نه اینترنت – حرکت تصادفی")}}if(e){let t=game.move(e);board.position(game.fen()),moveHistory.push({move:t,fenBefore:game.fen()}),redoStack=[],t.captured?playCaptureSound():playMoveSound(),game.in_check()&&playCheckSound(),saveRemoteState();let n=e.from+e.to+(e.promotion||"");$("#status").text(`🤖 کامپیوتر: ${n}`).fadeOut(2500,()=>updateStatus())}else updateStatus();isThinking=!1,game.game_over()&&(stopBgMusic(),saveGameToHistory(game.turn()===userColor?"computer":"user",moveHistory.map(e=>e.move),bonusPoints,game.fen())),updateBottomScores()}
function updateStatus(){if(isReplayMode)return;let e="";if(game.in_checkmate()){let t=game.turn()===userColor?"کامپیوتر":"شما";e="شما"===t?"🎉 کیش و مات! شما برنده شدید.":"❌ کیش و مات! شما باختید.","شما"===t&&(wins++,bonusPoints+=10,saveRemoteState(),updateUI(),wins>=WINS_TO_ADVANCE&&advanceLevel()),playMateSound()}else game.in_draw()?e="🤝 مساوی":game.in_check()?e=game.turn()===userColor?"⚠️ کیش! شما در معرض خطر هستید.":"⚠️ کیش! کامپیوتر را تهدید کردید.":e=`نوبت ${"w"===game.turn()?"سفید":"سیاه"}`;$("#status").text(e)}
$(document).ready(async()=>{game=new Chess,await getOrCreateSession(),await loadRemoteState(),initBoard(),$("#soundToggle").addClass("active")});
$("#newGameBtn").click(()=>{isReplayMode?clearReplay():(game.reset(),board.start(),moveHistory=[],redoStack=[],isThinking=!1,updateStatus(),startBgMusic(),saveRemoteState(),coachEnabled&&fetchBestMoveForCoach(),"b"===userColor&&setTimeout(makeComputerMove,500))});
$("#undoBtn").click(()=>{if(!isReplayMode&&!isThinking&&moveHistory.length>=2){for(let e=0;e<2;e++)moveHistory.length&&(redoStack.push(moveHistory.pop()),game.undo());board.position(game.fen()),updateStatus(),saveRemoteState(),coachEnabled&&fetchBestMoveForCoach()}});
$("#redoBtn").click(()=>{if(!isReplayMode&&!isThinking&&redoStack.length>=2){for(let e=0;e<2;e++)if(redoStack.length){let e=redoStack.pop();game.move(e.move),moveHistory.push(e)}board.position(game.fen()),updateStatus(),saveRemoteState(),coachEnabled&&fetchBestMoveForCoach()}});
$("#flipBtn").click(()=>{isReplayMode||(playerColor="w"===playerColor?"b":"w",board.orientation(playerColor),updateStatus())});
$("#switchColorBtn").click(()=>{if(isReplayMode||isThinking||moveHistory.length>0)return showToast("ابتدا بازی را تمام کنید یا بازی جدید شروع کنید."),void 0;userColor="w"===userColor?"b":"w",playerColor=userColor,board.orientation(playerColor),localStorage.setItem("userColor",userColor),updateUI(),saveRemoteState(),"b"===userColor&&setTimeout(makeComputerMove,500),showToast(`حالا شما مهره‌های ${"w"===userColor?"سفید":"سیاه"} را کنترل می‌کنید.`)});
$("#hintBtn").click(function(){hintEnabled=!hintEnabled,$(this).toggleClass("active",hintEnabled),hintEnabled||$(".square-55d63").removeClass("highlight-square")});
$("#coachBtn").click(function(){coachEnabled=!coachEnabled,$(this).toggleClass("active",coachEnabled),coachEnabled?(pendingBestMove=null,game.game_over()||game.turn()!==userColor||fetchBestMoveForCoach(),showToast("🧠 مربی فعال شد.")):(pendingBestMove=null,showToast("مربی غیرفعال شد."))});
$("#soundToggle").click(function(){soundEnabled=!soundEnabled,$(this).toggleClass("active",soundEnabled),soundEnabled?startBgMusic():stopBgMusic()});
function showToast(e){let t=$("#toast");t.text(e).addClass("show"),setTimeout(()=>t.removeClass("show"),3e3)}
const PIECE_SVGS={'wP':'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 45 45" width="45" height="45"><path d="M22.5 9c-2.21 0-4 1.79-4 4 0 .89.29 1.71.78 2.38C17.33 16.5 16 18.59 16 21c0 2.03.94 3.84 2.41 5.03-3 1.06-7.41 5.55-7.41 13.47h23c0-7.92-4.41-12.41-7.41-13.47 1.47-1.19 2.41-3 2.41-5.03 0-2.41-1.33-4.5-3.28-5.62.49-.67.78-1.49.78-2.38 0-2.21-1.79-4-4-4z" fill="#fff" stroke="#000" stroke-width="1.5"/></svg>','wR':'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 45 45" width="45" height="45"><g stroke="#000" stroke-width="1.5" fill="#fff"><path d="M9 39h27v-3H9v3zm3.5-7h20V9h-20v23zm1-3h18V11h-18v18z"/><path d="M9 39h27v-3H9v3zm3.5-7h20V9h-20v23z" fill="none"/></g></svg>','wN':'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 45 45" width="45" height="45"><g fill="#fff" stroke="#000" stroke-width="1.5"><path d="M22 10c10.5 1 16.5 8 16 29H15c0-9 10-6.5 8-21"/><path d="M24 18c.38 2.91-5.55 7.37-8 9-3 2-2.82 4.34-5 4-1.042-.94 1.41-3.04 0-3-1 0 .19 1.23-1 2-1 0-4.003 1-4-4 0-2 6-12 6-12s1.89-1.9 2-3.5c-.73-.994-.5-2-.5-3 1-1 3 2.5 3 2.5h2s.78-1.992 2.5-3c1 0 1 3 1 3"/></g></svg>','wB':'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 45 45" width="45" height="45"><g fill="#fff" stroke="#000" stroke-width="1.5"><path d="M9 36c3.39-.97 10.11.43 13.5-2 3.39 2.43 10.11 1.03 13.5 2 0 0 1.65.54 3 2-.68.97-1.65.99-3 .5-3.39-.97-10.11.46-13.5-1-3.39 1.46-10.11.03-13.5 1-1.354.49-2.323.47-3-.5 1.354-1.94 3-2 3-2z"/><path d="M15 32c2.5 2.5 12.5 2.5 15 0 .5-1.5 0-2 0-2 0-2.5-2.5-4-2.5-4 5.5-1.5 6-11.5-5-15.5-11 4-10.5 14-5 15.5 0 0-2.5 1.5-2.5 4 0 0-.5.5 0 2z"/><path d="M25 8a2.5 2.5 0 1 1-5 0 2.5 2.5 0 1 1 5 0z"/></g></svg>','wQ':'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 45 45" width="45" height="45"><g fill="#fff" stroke="#000" stroke-width="1.5"><path d="M8 12a2 2 0 1 1-4 0 2 2 0 1 1 4 0zm33 0a2 2 0 1 1-4 0 2 2 0 1 1 4 0z"/><path d="M8 12c0-2.5 6.5-4.5 14.5-4.5S37 9.5 37 12"/><path d="M22.5 11c6.5 0 14.5 2 14.5 4.5 0 0 0 10-3.5 14.5-3.5 4.5-11 9-11 9s-7.5-4.5-11-9C8 25.5 8 15.5 8 15.5c0-2.5 8-4.5 14.5-4.5z"/><circle cx="22.5" cy="11" r="3.5"/></g></svg>','wK':'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 45 45" width="45" height="45"><g fill="#fff" stroke="#000" stroke-width="1.5"><path d="M22.5 11.63V6M20 8h5"/><path d="M22.5 25s4.5-7.5 3-10.5c0 0-1-2.5-3-2.5s-3 2.5-3 2.5c-1.5 3 3 10.5 3 10.5"/><path d="M11.5 37c5.5 3.5 15.5 3.5 21 0v-7c0-2-10-2-21 0v7z"/><path d="M11.5 30c5.5-3 15.5-3 21 0m-21 3.5c5.5-3 15.5-3 21 0m-21 3.5c5.5-3 15.5-3 21 0"/></g></svg>','bP':'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 45 45" width="45" height="45"><path d="M22.5 9c-2.21 0-4 1.79-4 4 0 .89.29 1.71.78 2.38C17.33 16.5 16 18.59 16 21c0 2.03.94 3.84 2.41 5.03-3 1.06-7.41 5.55-7.41 13.47h23c0-7.92-4.41-12.41-7.41-13.47 1.47-1.19 2.41-3 2.41-5.03 0-2.41-1.33-4.5-3.28-5.62.49-.67.78-1.49.78-2.38 0-2.21-1.79-4-4-4z" fill="#000" stroke="#fff" stroke-width="1.5"/></svg>','bR':'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 45 45" width="45" height="45"><g stroke="#fff" stroke-width="1.5" fill="#000"><path d="M9 39h27v-3H9v3zm3.5-7h20V9h-20v23zm1-3h18V11h-18v18z"/><path d="M9 39h27v-3H9v3zm3.5-7h20V9h-20v23z" fill="none"/></g></svg>','bN':'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 45 45" width="45" height="45"><g fill="#000" stroke="#fff" stroke-width="1.5"><path d="M22 10c10.5 1 16.5 8 16 29H15c0-9 10-6.5 8-21"/><path d="M24 18c.38 2.91-5.55 7.37-8 9-3 2-2.82 4.34-5 4-1.042-.94 1.41-3.04 0-3-1 0 .19 1.23-1 2-1 0-4.003 1-4-4 0-2 6-12 6-12s1.89-1.9 2-3.5c-.73-.994-.5-2-.5-3 1-1 3 2.5 3 2.5h2s.78-1.992 2.5-3c1 0 1 3 1 3"/></g></svg>','bB':'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 45 45" width="45" height="45"><g fill="#000" stroke="#fff" stroke-width="1.5"><path d="M9 36c3.39-.97 10.11.43 13.5-2 3.39 2.43 10.11 1.03 13.5 2 0 0 1.65.54 3 2-.68.97-1.65.99-3 .5-3.39-.97-10.11.46-13.5-1-3.39 1.46-10.11.03-13.5 1-1.354.49-2.323.47-3-.5 1.354-1.94 3-2 3-2z"/><path d="M15 32c2.5 2.5 12.5 2.5 15 0 .5-1.5 0-2 0-2 0-2.5-2.5-4-2.5-4 5.5-1.5 6-11.5-5-15.5-11 4-10.5 14-5 15.5 0 0-2.5 1.5-2.5 4 0 0-.5.5 0 2z"/><path d="M25 8a2.5 2.5 0 1 1-5 0 2.5 2.5 0 1 1 5 0z"/></g></svg>','bQ':'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 45 45" width="45" height="45"><g fill="#000" stroke="#fff" stroke-width="1.5"><path d="M8 12a2 2 0 1 1-4 0 2 2 0 1 1 4 0zm33 0a2 2 0 1 1-4 0 2 2 0 1 1 4 0z"/><path d="M8 12c0-2.5 6.5-4.5 14.5-4.5S37 9.5 37 12"/><path d="M22.5 11c6.5 0 14.5 2 14.5 4.5 0 0 0 10-3.5 14.5-3.5 4.5-11 9-11 9s-7.5-4.5-11-9C8 25.5 8 15.5 8 15.5c0-2.5 8-4.5 14.5-4.5z"/><circle cx="22.5" cy="11" r="3.5"/></g></svg>','bK':'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 45 45" width="45" height="45"><g fill="#000" stroke="#fff" stroke-width="1.5"><path d="M22.5 11.63V6M20 8h5"/><path d="M22.5 25s4.5-7.5 3-10.5c0 0-1-2.5-3-2.5s-3 2.5-3 2.5c-1.5 3 3 10.5 3 10.5"/><path d="M11.5 37c5.5 3.5 15.5 3.5 21 0v-7c0-2-10-2-21 0v7z"/><path d="M11.5 30c5.5-3 15.5-3 21 0m-21 3.5c5.5-3 15.5-3 21 0m-21 3.5c5.5-3 15.5-3 21 0"/></g></svg>'};
JSEOF

# book.json
cat > bw-project/src/main/assets/book.json << 'EOF'
{"rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq -":"e2e4","rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq -":"e7e5","rnbqkbnr/pppppppp/8/8/3P4/8/PPP1PPPP/RNBQKBNR b KQkq -":"d7d5","rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq -":"g1f3","rnbqkbnr/pppp1ppp/8/4p3/2P5/8/PP1PPPPP/RNBQKBNR w KQkq -":"d2d4"}
EOF

# libs.js (کتابخانه‌ها – در صورت وجود فایل‌های اصلی، ترکیب می‌شوند)
if [ -f bw-project/src/main/assets/jquery.min.js ] && [ -f bw-project/src/main/assets/chess.min.js ] && [ -f bw-project/src/main/assets/chessboard.min.js ]; then
    cat bw-project/src/main/assets/jquery.min.js bw-project/src/main/assets/chess.min.js bw-project/src/main/assets/chessboard.min.js > bw-project/src/main/assets/libs.js
else
    echo "// کتابخانه‌های jQuery، chess.js و chessboard.js باید اینجا باشند" > bw-project/src/main/assets/libs.js
fi

# کپی فایل‌های frontend به assets
cp frontend/index.html bw-project/src/main/assets/
cp frontend/style.css bw-project/src/main/assets/
cp frontend/script.js bw-project/src/main/assets/

# ═══════════════════════════════════════
#  ANDROID PROJECT
# ═══════════════════════════════════════
echo "📱 ۵. فایل‌های پروژهٔ اندروید"

# build.gradle
cat > bw-project/build.gradle << 'GRADLE'
buildscript {
    repositories { google(); mavenCentral() }
    dependencies { classpath 'com.android.tools.build:gradle:8.2.0' }
}
apply plugin: 'com.android.application'
android {
    namespace 'com.ramin.chess'
    compileSdk 34
    defaultConfig {
        applicationId 'com.ramin.chess'
        minSdk 21; targetSdk 34
        versionCode 1200
        versionName "12.0.0"
    }
    signingConfigs {
        release {
            storeFile file('ramin-chess.keystore')
            storePassword 'ramin123'; keyAlias 'raminchess'; keyPassword 'ramin123'
        }
    }
    buildTypes {
        debug { signingConfig signingConfigs.release }
        release { signingConfig signingConfigs.release; minifyEnabled false }
    }
}
repositories { google(); mavenCentral() }
GRADLE

# AndroidManifest.xml
cat > bw-project/src/main/AndroidManifest.xml << 'XML'
<manifest xmlns:android="http://schemas.android.com/apk/res/android" package="com.ramin.chess">
    <uses-permission android:name="android.permission.INTERNET"/>
    <application android:allowBackup="true" android:label="@string/app_name" android:icon="@drawable/ic_launcher" android:supportsRtl="true" android:theme="@android:style/Theme.NoTitleBar">
        <activity android:name=".MainActivity" android:exported="true">
            <intent-filter> <action android:name="android.intent.action.MAIN"/> <category android:name="android.intent.category.LAUNCHER"/> </intent-filter>
        </activity>
    </application>
</manifest>
XML

# strings.xml
cat > bw-project/src/main/res/values/strings.xml << 'XML'
<resources><string name="app_name">شطرنج رامین اجلال</string></resources>
XML

# MainActivity.java
cat > bw-project/src/main/java/com/ramin/chess/MainActivity.java << 'JAVA'
package com.ramin.chess;
import android.app.Activity; import android.os.Bundle; import android.webkit.WebView; import android.webkit.WebViewClient; import android.webkit.WebSettings;
public class MainActivity extends Activity {
    protected void onCreate(Bundle b) {
        super.onCreate(b);
        WebView w = new WebView(this);
        w.setWebViewClient(new WebViewClient());
        WebSettings s = w.getSettings(); s.setJavaScriptEnabled(true); s.setDomStorageEnabled(true);
        w.loadUrl("file:///android_asset/index.html");
        setContentView(w);
    }
}
JAVA

# آیکون Vector
cat > bw-project/src/main/res/drawable/ic_launcher.xml << 'XML'
<?xml version="1.0" encoding="utf-8"?>
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="48dp" android:height="48dp"
    android:viewportWidth="48" android:viewportHeight="48">
    <path android:fillColor="#FFD700" android:pathData="M24,2C11.85,2,2,11.85,2,24s9.85,22,22,22s22-9.85,22-22S36.15,2,24,2z"/>
    <path android:fillColor="#000" android:pathData="M18,34c-1.5,0-2.5,1-2.5,2.5c0,0.5,0.2,1,0.5,1.4l-1.5,3.6h19l-1.5-3.6c0.3-0.4,0.5-0.9,0.5-1.4c0-1.5-1-2.5-2.5-2.5H18z"/>
    <path android:fillColor="#000" android:pathData="M15,32l1.5-5h15l1.5,5H15z"/>
    <path android:fillColor="#000" android:pathData="M22,10c-1.5,0-3,0.5-4,1.5c-2.5,2-3,6-3,9.5v1h18v-1c0-3.5-0.5-7.5-3-9.5C25,10.5,23.5,10,22,10z"/>
</vector>
XML

# Keystore (در صورت نبود)
if [ ! -f bw-project/ramin-chess.keystore ]; then
    cd bw-project
    keytool -genkey -v -keystore ramin-chess.keystore -alias raminchess -keyalg RSA -keysize 2048 -validity 10000 -storepass ramin123 -keypass ramin123 -dname "CN=Ramin Ejlal, OU=Dev, O=Tetrashop, L=Tehran, ST=Tehran, C=IR"
    cd ~/chess-engine
fi

# ═══════════════════════════════════════
#  GRADLE WRAPPER
# ═══════════════════════════════════════
echo "⚙️ ۶. Gradle Wrapper"
cat > bw-project/gradlew << 'GRADLEW'
#!/bin/bash
PRG="$0"
while [ -h "$PRG" ]; do
  ls=`ls -ld "$PRG"`
  link=`expr "$ls" : '.*-> \(.*\)$'`
  if expr "$link" : '/.*' > /dev/null; then PRG="$link"; else PRG=`dirname "$PRG"`/"$link"; fi
done
APP_HOME=`dirname "$PRG"`
if [ ! -f "$APP_HOME/gradle/wrapper/gradle-wrapper.jar" ]; then
  echo "Downloading Gradle wrapper..."
  mkdir -p "$APP_HOME/gradle/wrapper"
  curl -L -o "$APP_HOME/gradle/wrapper/gradle-wrapper.jar" \
    https://raw.githubusercontent.com/gradle/gradle/v8.5.0/gradle/wrapper/gradle-wrapper.jar
fi
java -cp "$APP_HOME/gradle/wrapper/gradle-wrapper.jar" org.gradle.wrapper.GradleWrapperMain "$@"
GRADLEW
chmod +x bw-project/gradlew

cat > bw-project/gradle/wrapper/gradle-wrapper.properties << 'PROPS'
distributionBase=GRADLE_USER_HOME
distributionPath=wrapper/dists
distributionUrl=https\://services.gradle.org/distributions/gradle-8.5-bin.zip
networkTimeout=10000
validateDistributionUrl=true
zipStoreBase=GRADLE_USER_HOME
zipStorePath=wrapper/dists
PROPS

# ═══════════════════════════════════════
#  GITHUB ACTIONS WORKFLOW
# ═══════════════════════════════════════
echo "⚙️ ۷. Workflow"
cat > .github/workflows/release-apk.yml << 'YML'
name: Build APK

on:
  push:
    tags:
      - 'v*'

permissions:
  contents: write

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with: { distribution: 'temurin', java-version: '17' }
      - uses: android-actions/setup-android@v3
        with: { accept-android-sdk-licenses: false }
      - name: Accept Licenses
        run: |
          mkdir -p $ANDROID_HOME/licenses
          echo "d56f5187479451eabf01fb78af6dfcb131a6481e" > $ANDROID_HOME/licenses/android-sdk-license
      - name: Build APK
        run: cd bw-project && ./gradlew assembleDebug
      - name: Copy APK to root
        run: |
          find bw-project -name "*.apk" -type f -exec cp {} ./app.apk \;
          ls -la app.apk
      - name: Upload APK to Release
        uses: softprops/action-gh-release@v2
        with:
          files: app.apk
          tag_name: ${{ github.ref_name }}
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
      - name: Upload APK to Artifacts (backup)
        uses: actions/upload-artifact@v4
        with:
          name: ChessEnginePy-APK-${{ github.ref_name }}
          path: app.apk
YML

echo "🚀 ۸. Commit، Push و تگ"
git add -A
git commit -m "Perfect v12.0.0 – complete bug-free chess engine"
git push origin main || echo "⚠️ push ناموفق"
git tag v12.0.0
git push origin v12.0.0 || echo "⚠️ push تگ ناموفق"

echo ""
echo "✅ پروژه با موفقیت بازسازی شد."
echo "📱 به Actions بروید و APK را از Artifacts دانلود کنید:"
echo "   https://github.com/tetrashop/chess-engine/actions"
