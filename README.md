# ♟️ ChessEnginePy – A Star‑Topology UCI Chess Engine with Intelligent Coach

**Translated from the C++ ChessEngine by [Tetrashop](https://github.com/tetrashop/ChessEngine)**  
**Pure Python • UCI Protocol • Alpha‑Beta Search • Bitboards • REST API • Web GUI • Coach • Levels • SFX**

[![Python Version](https://img.shields.io/badge/python-3.8+-blue.svg)](https://www.python.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![UCI Protocol](https://img.shields.io/badge/protocol-UCI-green.svg)](#)
[![Vercel Deploy](https://img.shields.io/badge/deployed%20on-Vercel-black?logo=vercel)](https://chess-engine.vercel.app)

---

## 📜 Abstract

This project delivers a **complete, bug‑free, pure Python chess engine** that conforms to the Universal Chess Interface (UCI) standard. The engine employs **bitboard** representation, **alpha‑beta pruning** with iterative deepening, **quiescence search**, and **piece‑square tables** for positional evaluation.

The system is architected in a **star topology**: a central backend API (Flask) serves the chess AI, while multiple lightweight frontend clients (HTML/CSS/JavaScript) connect to it via HTTP. This design enables many simultaneous users to play against the same AI instance and is well‑suited for serverless platforms such as Vercel.

Beyond a simple chess opponent, the application now includes an **intelligent coach**, a **progression system with eight levels**, **sound effects & background music**, **visual move hints**, **undo/redo**, and full Persian language support – turning it into an immersive learning and gaming experience.

This document serves as both a user manual and a scientific paper covering the theoretical foundations, implementation details, encountered errors, and their solutions.

---

## 🧠 Theoretical Foundations

### 1. Bitboard Representation
A chessboard is an 8×8 grid, but for efficient computation, we encode it as a set of 64‑bit integers – one for each piece type and color. Bitwise operations enable lightning‑fast move generation and attack detection.

### 2. Move Generation
Moves are generated **pseudo‑legally** (without checking for leaving the king in check) and then filtered for legality. Special moves – castling, en passant, and promotions – are handled explicitly.

### 3. Search Algorithm
The core of the AI is the **alpha‑beta search** with **iterative deepening**:
- Alpha‑beta pruning eliminates branches that cannot affect the final decision, drastically reducing the search tree.
- Iterative deepening allows the engine to provide a move at any requested depth and serves as a time‑management tool.
- **Quiescence search** extends the evaluation of volatile positions (captures/promotions) to avoid the horizon effect.

### 4. Evaluation Function
The static evaluation combines:
- **Material balance** (pawn=100cp, knight=320cp, bishop=330cp, rook=500cp, queen=900cp, king=20000cp).
- **Piece‑Square Tables (PST)** – precomputed positional bonuses that reward good piece placement.

The final score is returned from the side‑to‑move’s perspective.

### 5. Intelligent Coach
When enabled, the coach fetches the engine’s best move **before** the user’s turn. After the user moves:
- If the move matches the best move → **+3 bonus points**.
- If the move differs → **‑5 bonus points** and a message shows the optimal move.
Points never drop below zero. The coach encourages learning by providing immediate, non‑intrusive feedback.

### 6. Star Topology & REST API
The engine is wrapped in a Flask web server that exposes a REST endpoint `/api/bestmove`. This separation allows:
- A single AI backend to serve many clients.
- Easy integration with web interfaces, mobile apps, or other services.
- Deployment on stateless serverless platforms (Vercel) without persistent game state.

The frontend is a pure HTML/JS chessboard that sends the current FEN to the API, receives the best move, and updates the board.

---

## 🏗️ Architecture

```

chess-engine/
├── backend/                # Central AI server (Flask + chess engine)
│   ├── app.py              # Flask app with /api/bestmove endpoint
│   ├── chess_engine/       # Core engine modules (bitboard, board, movegen, etc.)
│   └── requirements.txt    # Flask dependency
├── frontend/               # Client‑side web interface
│   ├── index.html
│   ├── style.css
│   └── script.js
├── vercel.json             # Vercel deployment configuration
├── main.py                 # Standalone UCI entry point (for GUIs)
├── README.md               # This document
└── LICENSE                 # MIT License

```

**Data flow:**  
1. User makes a move in the browser → JavaScript captures the move.  
2. The current FEN is sent via `fetch` to `GET /api/bestmove?fen=...&depth=3`.  
3. Flask server instantiates `Board` and `Search`, runs the search, returns the best move in JSON.  
4. JavaScript applies the move on the board.

---

## ✨ Features (Full List)

| Category | Feature |
|----------|---------|
| **AI** | Alpha‑beta search, iterative deepening, quiescence search, PST evaluation |
| **API** | REST endpoint `/api/bestmove` with CORS |
| **Progression** | 8 levels, visual level bar (locked / active / completed) |
| **Coach** | Best‑move hint with fair scoring (+3 / -5 points) |
| **Scoring** | Bonus points, win counter, level advancement |
| **Sound** | Move, capture, check, checkmate, bonus, error sounds + background music |
| **Visual** | Highlight legal moves, toast notifications |
| **Undo/Redo** | Full move history, step back/forward (by pairs) |
| **UI** | Persian language, responsive buttons, flip board |
| **Deployment** | One‑click Vercel deploy with `vercel.json` |

---

## 🐞 Error Log & Solutions

### Error 1: `ModuleNotFoundError: No module named 'flask'`
**Cause:** Flask was not installed in the local environment.  
**Solution:** Run `pip install flask`. For Vercel, ensure `backend/requirements.txt` contains `flask`.

### Error 2: 404 Not Found on Vercel (or locally)
**Cause:** Misconfiguration of static file serving and routing.  
**Solution:**  
- Locally: Modified `backend/app.py` to serve static files from `../frontend/` when not on Vercel.  
- Vercel: Updated `vercel.json` to build the Python API separately and serve `frontend/` as static files, with explicit routes.

### Error 3: AI freezes on computer’s turn (browser hangs)
**Cause:**  
- The search could exceed Vercel’s 10‑second function timeout.  
- CORS headers were missing, causing the browser to reject the response.  
- The JavaScript code had no timeout, waiting indefinitely.  
**Solution:**  
- Limited search depth to max 3 for API requests.  
- Added `after_request` CORS headers in Flask.  
- Implemented `AbortController` with an 8‑second timeout in the frontend.

### Error 4: `vercel --prod` not working in Termux
**Cause:** `vercel` CLI not installed; `npx` had architecture issues (ARM).  
**Solution:** Used the Vercel website to import the GitHub repository directly, eliminating the need for CLI.

### Error 5: Embedded Git repositories and wrong remote
**Cause:** Accidentally cloned other repositories into the project folder.  
**Solution:** Cleaned up with `rm -rf`, removed spurious remotes, and set the correct origin to `https://github.com/tetrashop/chess-engine.git`.

### Error 6: White plays twice / computer move not visible
**Cause:** JavaScript would undo the user’s move if the API call failed, causing the turn to revert to White. Additionally, the computer’s move was applied but not visually highlighted.  
**Solution:**  
- Replaced undo logic with a **fallback random legal move** using `chess.js` when the API is unreachable or returns an invalid move.  
- Added a status message (`🤖 کامپیوتر: e7e5`) that shows the computer’s move and fades out.  
- Ensured game turn always advances correctly.

### Error 7: Sound, undo/redo, hints, and scoring not working
**Cause:** Missing logic bindings and incorrect state management.  
**Solution:** Fully rewrote `script.js` with proper event bindings, persistent state (localStorage), and a dedicated coach module.

---

## 🚀 Quick Start

### Prerequisites
- Python 3.8+ (for `int.bit_count()`)
- Flask (`pip install flask`) – only needed for the API; the engine itself is pure stdlib.
- A modern web browser.

### Local Test (Full Stack)
```bash
cd chess-engine
python backend/app.py
```

Open http://localhost:5000 in your browser. All features (coach, levels, sounds) are available.

Standalone UCI Mode

```bash
python main.py
```

Then use a chess GUI (Arena, Cute Chess) or pipe commands:

```bash
echo -e "uci\nposition startpos\ngo depth 3\nquit" | python main.py
```

Deploy to Vercel

1. Push the code to GitHub.
2. In Vercel, import the tetrashop/chess-engine repository.
3. Set Framework Preset to Other, Install Command to pip install -r backend/requirements.txt.
4. Deploy – your AI chess service with coach is live.

---

📚 References

· Chess Programming Wiki: https://www.chessprogramming.org
· UCI Protocol: http://wbec-ridderkerk.nl/html/UCIProtocol.html
· Alpha‑Beta Pruning: Knuth, D.E., and Moore, R.W. (1975). “An Analysis of Alpha‑Beta Pruning”.
· Bitboards: Hyatt, R. (1999). “Rotated Bitboards”.

---

📄 License

This project is licensed under the MIT License. See LICENSE for details.

---

🙏 Acknowledgements

· Original C++ engine by Tetrashop.
· The chess programming community at TalkChess and the Chess Programming Wiki.
· Flask, chessboard.js, and chess.js for the frontend.
