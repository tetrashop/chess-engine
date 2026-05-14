# ♟️ ChessEnginePy - Python UCI Chess Engine

[![Python Version](https://img.shields.io/badge/python-3.8+-blue.svg)](https://www.python.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![UCI Protocol](https://img.shields.io/badge/protocol-UCI-green.svg)](#)

A complete, bug-free, pure Python chess engine translated from the [C++ ChessEngine](https://github.com/tetrashop/ChessEngine) by Tetrashop. It communicates via the **Universal Chess Interface (UCI)** protocol and is ready to play against humans or other engines.

**No external dependencies** – works with Python's standard library only.

---

## 📌 Features

- **Full UCI compliance** (`uci`, `isready`, `position`, `go`, `stop`, `quit`)
- **Bitboard-based board representation** with sliding piece attack generation (ray attacks)
- **Complete move generation** – all legal moves, including:
  - Pawn double pushes, captures, en passant, and promotions
  - Castling (with proper checks)
  - Knight, Bishop, Rook, Queen, and King moves
- **Alpha‑beta search** with iterative deepening and quiescence search (captures/promotions)
- **Piece‑square tables (PST)** for positional evaluation
- **Simple MVV‑LVA** move ordering for better pruning
- **History‑based make/unmake** for efficient move undo
- **Multi‑threaded search** (separate thread for thinking, responds to `stop`)
- **No external libraries** – pure Python, easy to read and modify

---

## 🚀 Quick Start

### Prerequisites

- Python **3.8** or later (the engine uses `int.bit_count()`, available from 3.8+).

### Installation

Clone the repository:

```bash
git clone https://github.com/tetrashop/chess-engine.git
cd chess-engine
```

That's it! No virtual environment or package installation is needed.

---

🕹️ Usage

Command Line (UCI mode)

Simply run the engine and type UCI commands:

```bash
python main.py
```

Example session:

```
uci
id name ChessEnginePy
id author Tetrashop (Python port)
uciok
isready
readyok
position startpos moves e2e4 e7e5
go depth 4
info depth 4 score cp 15 nodes 4523 time 234 nps 19329
bestmove g1f3
quit
```

Pipe a sequence of commands

```bash
echo -e "uci\nposition startpos\ngo depth 3\nquit" | python main.py
```

This is useful for quick testing or scripting.

With a Chess GUI

You can use the engine inside any UCI‑compatible chess interface (Arena, Cute Chess, Scid, etc.):

1. Open your GUI and navigate to Engines → Install New Engine.
2. Select the python interpreter and point to main.py.
   · Example: python C:\Users\You\chess-engine\main.py
3. The engine will appear as ChessEnginePy – you can now play or run matches!

---

🧱 Project Structure

```
chess-engine/
├── chess_engine/          # Main Python package
│   ├── __init__.py        # Package initialisation
│   ├── bitboard.py        # Bitboard utilities, masks, attack tables
│   ├── board.py           # Board representation, FEN, make/unmake moves
│   ├── movegen.py         # Move generation (pseudo‑legal + legal)
│   ├── evaluate.py        # Static evaluation with material + PST
│   ├── search.py          # Alpha‑beta search + quiescence
│   └── uci.py             # UCI protocol handler and main loop
├── main.py                # Entry point for the engine
├── requirements.txt       # (empty – standard library only)
└── README.md              # You are here
```

Each module is extensively commented and follows a clean, modular design – ideal for learning, teaching, or further development.

---

🔍 Technical Details

Bitboards

The board is represented as 12 bitboards (6 piece types × 2 colours). Square indexing follows Little‑Endian Rank‑File mapping (A1=0, H8=63). Helper functions for bit counting, bit clearing, and sliding attacks are provided.

Move Generation

· Pseudo‑legal moves are generated for all pieces, including special pawn moves.
· A legality check (after making the move, the own king must not be in check) filters out illegal moves.
· En passant and castling rights are correctly updated.

Search

· Iterative deepening from depth 1 up to the given depth.
· Alpha‑beta pruning with simple MVV‑LVA move ordering.
· Quiescence search to avoid the horizon effect – only captures and promotions are searched.
· Search runs in a separate thread so the engine can respond to stop and quit immediately.

Evaluation

· Material: piece values in centipawns (pawn=100, knight=320, bishop=330, rook=500, queen=900, king=20000).
· Piece‑Square Tables (PST): separately tuned tables for each piece type, with mirrored values for Black.
· Score is returned from the perspective of the side to move.

---

🧪 Testing

The engine has been manually tested with standard opening positions and custom FENs. To verify it's working:

```bash
# Should output a legal move within a second
echo -e "uci\nposition startpos\ngo depth 3\nquit" | python main.py
```

For more rigorous testing, you can run it against another engine using cutechess‑cli:

```bash
cutechess-cli -engine cmd=python args=main.py -engine cmd=stockfish -each tc=40/60 -rounds 10
```

---

🤝 Contributing

This project is an educational Python translation of a C++ chess engine. Pull requests for improvements are welcome! Some areas you could enhance:

· Replace ray‑cast sliding attacks with magic bitboards for speed.
· Add a transposition table.
· Implement null move pruning and late move reductions.
· Improve move ordering (killer moves, history heuristic).
· Add support for Syzygy tablebases.

Please keep the code dependency‑free and well documented.

---

📄 License

This project is released under the MIT License. See the LICENSE file for details.

---

🙏 Acknowledgements

· Original C++ engine by Tetrashop.
· UCI protocol specification by Stefan Meyer‑Kahlen.
· Chess programming community at TalkChess and Chess Programming Wiki.
