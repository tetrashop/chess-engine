from .board import Board
from .search import Search
from .bitboard import square_to_str
import sys
import threading

class UCIHandler:
    def __init__(self):
        self.board = Board()
        self.search_thread = None
        self.stop_search = False

    def loop(self):
        while True:
            try:
                line = sys.stdin.readline().strip()
            except EOFError:
                break
            if not line:
                continue
            tokens = line.split()
            if tokens[0] == "uci":
                print("id name ChessEnginePy")
                print("id author Tetrashop (Python port)")
                print("uciok")
            elif tokens[0] == "isready":
                print("readyok")
            elif tokens[0] == "position":
                if "startpos" in tokens:
                    self.board = Board()
                    moves_idx = tokens.index("moves") if "moves" in tokens else len(tokens)
                    if moves_idx < len(tokens):
                        self._apply_moves(tokens[moves_idx+1:])
                elif "fen" in tokens:
                    fen_start = tokens.index("fen") + 1
                    fen_end = tokens.index("moves") if "moves" in tokens else len(tokens)
                    fen = " ".join(tokens[fen_start:fen_end])
                    self.board = Board(fen)
                    if "moves" in tokens:
                        self._apply_moves(tokens[tokens.index("moves")+1:])
            elif tokens[0] == "go":
                depth = None
                if "depth" in tokens:
                    depth = int(tokens[tokens.index("depth")+1])
                else:
                    depth = 6  # default
                self.stop_search = False
                self.search_thread = threading.Thread(target=self._search, args=(depth,))
                self.search_thread.start()
            elif tokens[0] == "stop":
                self.stop_search = True
                if self.search_thread:
                    self.search_thread.join()
            elif tokens[0] == "quit":
                self.stop_search = True
                break

    def _apply_moves(self, move_list):
        for move_str in move_list:
            from_sq = (ord(move_str[0]) - ord('a')) + (int(move_str[1]) - 1) * 8
            to_sq   = (ord(move_str[2]) - ord('a')) + (int(move_str[3]) - 1) * 8
            promo = None
            if len(move_str) == 5:
                promo = {'n':2,'b':3,'r':4,'q':5}[move_str[4].lower()]
            legal_moves = self.board.generate_legal_moves()
            for m in legal_moves:
                if m[0] == from_sq and m[1] == to_sq and m[2] == promo:
                    self.board.make_move(m)
                    break

    def _search(self, depth):
        search = Search(self.board)
        search.max_depth = depth
        search.search(depth)
        self.search_thread = None

def uci_loop():
    UCIHandler().loop()
