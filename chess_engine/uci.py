"""
UCI protocol loop.
"""
from .board import Board
from .search import Search

def uci_loop():
    board = Board()
    search = None
    while True:
        try:
            line = input().strip()
        except EOFError:
            break
        if line == "uci":
            print("id name ChessEnginePy")
            print("id author Tetrashop (translated)")
            print("uciok")
        elif line == "isready":
            print("readyok")
        elif line.startswith("position"):
            parts = line.split()
            if "startpos" in parts:
                board = Board()
                idx = parts.index("startpos")
                if "moves" in parts:
                    moves_idx = parts.index("moves")
                    for move_str in parts[moves_idx+1:]:
                        # apply move (simplified)
                        pass
            elif "fen" in parts:
                fen_start = parts.index("fen")
                fen_end = parts.index("moves") if "moves" in parts else len(parts)
                fen = " ".join(parts[fen_start+1:fen_end])
                board = Board(fen)
                if "moves" in parts:
                    moves_idx = parts.index("moves")
                    for move_str in parts[moves_idx+1:]:
                        pass
        elif line.startswith("go"):
            depth = 6  # default
            tokens = line.split()
            if "depth" in tokens:
                depth = int(tokens[tokens.index("depth") + 1])
            search = Search(board)
            search.max_depth = depth
            search.search(depth)
        elif line == "quit":
            break
        elif line == "stop":
            # would need to stop search thread
            pass
