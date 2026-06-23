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
