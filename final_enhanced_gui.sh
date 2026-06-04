#!/usr/bin/env bash
# final_enhanced_gui.sh – سیستم ۸ سطحی، صدا، انیمیشن، حرکت مجاز، undo/redo، فارسی

cd ~/chess-engine
mkdir -p frontend

echo "=== نصب فرانت‌اند پیشرفته با تمام امکانات ==="

# ────────────── 1. index.html ──────────────
cat > frontend/index.html << 'HTMLEOF'
<!DOCTYPE html>
<html lang="fa" dir="rtl">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>ChessEnginePy – بازی شطرنج با هوش مصنوعی</title>
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/chessboard-js/1.0.0/chessboard-1.0.0.min.css">
    <link rel="stylesheet" href="style.css">
</head>
<body>
    <div class="container">
        <h1>♟️ ChessEnginePy</h1>
        <div class="info-panel">
            <div id="levelDisplay">سطح ۱</div>
            <div id="bonusDisplay">امتیاز: ۰</div>
            <div id="winsDisplay">برد: ۰/۳</div>
        </div>
        <div id="board" style="width: 400px; margin: 0 auto;"></div>
        <div class="controls">
            <button id="newGameBtn">🔄 بازی جدید</button>
            <button id="undoBtn">↩️ بازگشت</button>
            <button id="redoBtn">↪️ پیشروی</button>
            <button id="flipBtn">🔃 چرخاندن صفحه</button>
            <button id="hintBtn">💡 نمایش حرکت‌های مجاز</button>
            <button id="soundToggle">🔊 صدا</button>
        </div>
        <div id="status">نوبت شما (سفید)</div>
        <div id="toast" class="toast"></div>
    </div>

    <script src="https://code.jquery.com/jquery-3.6.0.min.js"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/chess.js/0.10.3/chess.min.js"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/chessboard-js/1.0.0/chessboard-1.0.0.min.js"></script>
    <script src="script.js"></script>
</body>
</html>
HTMLEOF

# ────────────── 2. style.css ──────────────
cat > frontend/style.css << 'CSSEOF'
body {
    margin: 0; padding: 20px;
    background-color: #1a1a1a; color: #eee;
    font-family: Tahoma, sans-serif;
    display: flex; justify-content: center;
}
.container {
    text-align: center;
    max-width: 500px;
}
h1 {
    color: #f0d9b5;
    margin-bottom: 10px;
}
.info-panel {
    display: flex;
    justify-content: space-around;
    background: #2a2a2a;
    border-radius: 8px;
    padding: 8px;
    margin: 10px 0;
    font-size: 14px;
}
.info-panel div {
    background: #444;
    padding: 4px 12px;
    border-radius: 4px;
}
.controls {
    margin: 10px 0;
    display: flex;
    flex-wrap: wrap;
    justify-content: center;
    gap: 6px;
}
button {
    background: #4a4a4a;
    color: #fff;
    border: none;
    padding: 6px 12px;
    font-size: 13px;
    border-radius: 5px;
    cursor: pointer;
    transition: background 0.2s;
}
button:hover { background: #666; }
button.active { background: #8b7d3c; }
#status {
    margin: 12px 0;
    font-size: 18px;
    font-weight: bold;
    min-height: 30px;
    color: #f0d9b5;
}
.toast {
    position: fixed;
    top: 20px;
    left: 50%;
    transform: translateX(-50%);
    background: gold;
    color: #000;
    padding: 8px 20px;
    border-radius: 20px;
    font-weight: bold;
    font-size: 16px;
    opacity: 0;
    transition: opacity 0.5s;
    pointer-events: none;
    z-index: 1000;
}
.toast.show { opacity: 1; }
.highlight-square {
    box-shadow: inset 0 0 10px 4px rgba(255,255,0,0.8) !important;
}
CSSEOF

# ────────────── 3. script.js (نسخهٔ کامل) ──────────────
cat > frontend/script.js << 'JSEOF'
// ---------- تنظیمات ----------
const API_URL = "/api/bestmove";
const MAX_LEVEL = 8;
const WINS_TO_ADVANCE = 3;

// ---------- حالت بازی ----------
let board = null;
let game = new Chess();
let playerColor = 'w';
let isThinking = false;
let soundEnabled = true;
let moveHistory = [];      // undo stack
let redoStack = [];
let level = 1;
let wins = 0;
let bonusPoints = 0;
let hintEnabled = false;

// ---------- صداها (Web Audio API) ----------
let audioCtx = null;
function initAudio() {
    if (!audioCtx) audioCtx = new (window.AudioContext || window.webkitAudioContext)();
}
function playTone(freq, duration, type='square', vol=0.1) {
    if (!soundEnabled || !audioCtx) return;
    const osc = audioCtx.createOscillator();
    const gain = audioCtx.createGain();
    osc.type = type;
    osc.frequency.setValueAtTime(freq, audioCtx.currentTime);
    gain.gain.setValueAtTime(vol, audioCtx.currentTime);
    gain.gain.exponentialRampToValueAtTime(0.001, audioCtx.currentTime + duration);
    osc.connect(gain);
    gain.connect(audioCtx.destination);
    osc.start();
    osc.stop(audioCtx.currentTime + duration);
}
function playMoveSound() { initAudio(); playTone(520, 0.15); }
function playCaptureSound() { initAudio(); playTone(220, 0.2, 'sawtooth'); playTone(160, 0.25, 'triangle'); }
function playBonusSound() { initAudio(); playTone(800, 0.1); setTimeout(()=>playTone(1000,0.1), 100); }
function playCheckSound() { initAudio(); playTone(400,0.15); setTimeout(()=>playTone(500,0.15),150); }
function playMateSound() { initAudio(); playTone(300,0.3); setTimeout(()=>playTone(200,0.4),200); }
// موسیقی پس‌زمینه ساده (اختیاری)
let bgMusicInterval = null;
function startBgMusic() {
    if (!soundEnabled || bgMusicInterval) return;
    initAudio();
    const notes = [262,294,330,349,392,440,494,523]; // دو ر می فا سل لا سی دو
    let i = 0;
    bgMusicInterval = setInterval(() => {
        playTone(notes[i%notes.length], 0.3, 'sine', 0.03);
        i++;
    }, 600);
}
function stopBgMusic() {
    if (bgMusicInterval) { clearInterval(bgMusicInterval); bgMusicInterval = null; }
}

// ---------- ذخیره و بازیابی سطح ----------
function loadProgress() {
    try {
        const saved = JSON.parse(localStorage.getItem('chessEngineProgress'));
        if (saved) {
            level = saved.level || 1;
            wins = saved.wins || 0;
            bonusPoints = saved.bonusPoints || 0;
        }
    } catch(e) {}
}
function saveProgress() {
    try {
        localStorage.setItem('chessEngineProgress', JSON.stringify({level, wins, bonusPoints}));
    } catch(e) {}
}
function updateUI() {
    $('#levelDisplay').text(`سطح ${level}`);
    $('#bonusDisplay').text(`امتیاز: ${bonusPoints}`);
    $('#winsDisplay').text(`برد: ${wins}/${WINS_TO_ADVANCE}`);
}
function advanceLevel() {
    if (level < MAX_LEVEL) {
        level++;
        wins = 0;
        bonusPoints += level * 15;
        showToast(`🎉 تبریک! به سطح ${level} ارتقا یافتید! (+${level*15} امتیاز)`);
        playBonusSound();
    } else {
        showToast('🏆 شما به بالاترین سطح رسیده‌اید!');
    }
    saveProgress();
    updateUI();
}

// ---------- راه‌اندازی تخته ----------
function initBoard() {
    board = Chessboard('board', {
        draggable: true,
        position: 'start',
        orientation: playerColor,
        onDragStart: onDragStart,
        onDrop: onDrop,
        onSnapEnd: onSnapEnd,
        onMouseoverSquare: onMouseoverSquare,
        onMouseoutSquare: onMouseoutSquare,
        pieceTheme: 'https://chessboardjs.com/img/chesspieces/wikipedia/{piece}.png'
    });
    updateStatus();
    updateUI();
    startBgMusic();
}

// ---------- رویدادهای تخته ----------
function onDragStart(source, piece, position, orientation) {
    if (game.game_over() || isThinking || game.turn() !== playerColor) return false;
    // فقط مهره‌های خودی قابل حرکتند
    if ((playerColor === 'w' && piece.search(/^b/) !== -1) ||
        (playerColor === 'b' && piece.search(/^w/) !== -1)) return false;
}
function onDrop(source, target) {
    const move = game.move({ from: source, to: target, promotion: 'q' });
    if (move === null) return 'snapback';
    // ذخیره برای undo
    moveHistory.push({ move, fenBefore: game.fen() }); // fen before the move (after opponent's last)
    redoStack = [];
    // افکت صوتی
    if (move.captured) playCaptureSound(); else playMoveSound();
    if (game.in_check()) playCheckSound();
    updateStatus();
    setTimeout(makeComputerMove, 300);
}
function onSnapEnd() {
    board.position(game.fen());
}
function onMouseoverSquare(square, piece) {
    if (isThinking || game.game_over() || game.turn() !== playerColor) return;
    if (piece && ((playerColor==='w' && piece.startsWith('w')) || (playerColor==='b' && piece.startsWith('b')))) {
        const moves = game.moves({ square: square, verbose: true });
        const highlightSquares = moves.map(m => m.to);
        highlightSquares.push(square); // خود خانه هم هایلایت
        $('.square-55d63').removeClass('highlight-square');
        highlightSquares.forEach(sq => {
            $('#board .square-' + sq).addClass('highlight-square');
        });
    }
}
function onMouseoutSquare(square, piece) {
    $('.square-55d63').removeClass('highlight-square');
}

// ---------- حرکت کامپیوتر ----------
async function makeComputerMove() {
    if (game.game_over() || isThinking) return;
    isThinking = true;
    $('#status').text('⏳ کامپیوتر در حال فکر کردن...');
    let moveToApply = null;
    try {
        const controller = new AbortController();
        const timeout = setTimeout(() => controller.abort(), 8000);
        const depth = Math.min(level + 1, 4); // سطح بالاتر = عمق بیشتر
        const resp = await fetch(`${API_URL}?fen=${encodeURIComponent(game.fen())}&depth=${depth}`, { signal: controller.signal });
        clearTimeout(timeout);
        const data = await resp.json();
        if (data.bestmove) {
            const from = data.bestmove.substring(0,2);
            const to = data.bestmove.substring(2,4);
            const promo = data.bestmove.length > 4 ? data.bestmove[4] : undefined;
            const testMove = game.move({ from, to, promotion: promo });
            if (testMove !== null) {
                game.undo();
                moveToApply = { from, to, promotion: promo };
            }
        }
    } catch (e) {
        console.warn('API failed, fallback random move');
    }
    if (!moveToApply) {
        const moves = game.moves({ verbose: true });
        if (moves.length > 0) {
            const rand = moves[Math.floor(Math.random() * moves.length)];
            moveToApply = { from: rand.from, to: rand.to, promotion: rand.promotion || 'q' };
        }
    }
    if (moveToApply) {
        const finalMove = game.move(moveToApply);
        if (finalMove === null) {
            // fallback random again
            const moves = game.moves({ verbose: true });
            if (moves.length > 0) {
                const rand = moves[Math.floor(Math.random() * moves.length)];
                game.move({ from: rand.from, to: rand.to, promotion: rand.promotion || 'q' });
            }
        }
        board.position(game.fen());
        moveHistory.push({ move: finalMove, fenBefore: game.fen() }); // note: after computer move, we need correct fen before
        redoStack = [];
        if (finalMove && finalMove.captured) playCaptureSound(); else playMoveSound();
        if (game.in_check()) playCheckSound();
        const moveStr = moveToApply.from + moveToApply.to + (moveToApply.promotion ? moveToApply.promotion : '');
        $('#status').text(`🤖 کامپیوتر: ${moveStr}`).fadeOut(2500, function(){ updateStatus(); });
    } else {
        // game over
        updateStatus();
    }
    isThinking = false;
    checkGameEnd();
}

// ---------- وضعیت بازی ----------
function updateStatus() {
    let status = '';
    if (game.in_checkmate()) {
        status = game.turn() === playerColor ? '❌ کیش و مات! شما باختید.' : '🎉 کیش و مات! شما برنده شدید.';
        if (game.turn() !== playerColor) {
            wins++;
            if (wins >= WINS_TO_ADVANCE) {
                advanceLevel();
            }
            saveProgress();
            updateUI();
        }
        playMateSound();
    } else if (game.in_draw()) {
        status = '🤝 مساوی';
    } else if (game.in_check()) {
        status = game.turn() === playerColor ? '⚠️ کیش! شما در معرض خطر هستید.' : '⚠️ کیش! کامپیوتر را تهدید کردید.';
    } else {
        let turn = game.turn() === 'w' ? 'سفید' : 'سیاه';
        status = `نوبت ${turn}`;
    }
    $('#status').text(status);
}

function checkGameEnd() {
    if (game.game_over()) {
        stopBgMusic();
    }
}

// ---------- Undo / Redo ----------
$('#undoBtn').click(() => {
    if (isThinking || moveHistory.length === 0) return;
    // دو حرکت به عقب: آخرین حرکت کامپیوتر و حرکت قبلی کاربر
    // ساختار moveHistory: ورودی‌ها شامل fenBefore (موقعیت قبل از آن حرکت) و move
    // ما دو مرحله undo می‌کنیم
    for (let i = 0; i < 2; i++) {
        if (moveHistory.length > 0) {
            const last = moveHistory.pop();
            redoStack.push(last);
            game.undo();
        } else break;
    }
    board.position(game.fen());
    updateStatus();
    redoStack = [];
});
$('#redoBtn').click(() => {
    if (isThinking || redoStack.length === 0) return;
    for (let i = 0; i < 2; i++) {
        if (redoStack.length > 0) {
            const entry = redoStack.pop();
            game.move(entry.move);
            moveHistory.push(entry);
        } else break;
    }
    board.position(game.fen());
    updateStatus();
});

// ---------- سایر دکمه‌ها ----------
$('#newGameBtn').click(() => {
    game.reset();
    board.start();
    moveHistory = [];
    redoStack = [];
    isThinking = false;
    updateStatus();
    startBgMusic();
});
$('#flipBtn').click(() => {
    playerColor = playerColor === 'w' ? 'b' : 'w';
    board.orientation(playerColor);
    updateStatus();
});
$('#hintBtn').click(() => {
    hintEnabled = !hintEnabled;
    $(this).toggleClass('active');
    if (!hintEnabled) $('.square-55d63').removeClass('highlight-square');
});
$('#soundToggle').click(() => {
    soundEnabled = !soundEnabled;
    $(this).toggleClass('active', soundEnabled);
    if (!soundEnabled) stopBgMusic(); else startBgMusic();
});

// ---------- پیام Toast ----------
function showToast(msg) {
    const $toast = $('#toast');
    $toast.text(msg).addClass('show');
    setTimeout(() => $toast.removeClass('show'), 3000);
}

// ---------- شروع ----------
$(document).ready(() => {
    loadProgress();
    initBoard();
    updateUI();
    // تنظیم toggle اولیه صدا
    $('#soundToggle').addClass('active');
});
JSEOF

echo ""
echo "✅ فرانت‌اند پیشرفته با موفقیت ایجاد شد."
echo "🚀 برای تست محلی:"
echo "   python backend/app.py"
echo "   سپس http://localhost:5000"
echo ""
echo "☁️ انتشار:"
echo "   git add -A && git commit -m 'Enhanced GUI: 8 levels, sounds, undo/redo, hints, Persian' && git push"
