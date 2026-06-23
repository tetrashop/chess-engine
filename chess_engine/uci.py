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
