#!/usr/bin/env bash
# fix_turn_bug.sh – رفع مشکل نوبت سفید دوباره و تضمین بازی روان

cd ~/chess-engine

echo "=== رفع مشکل نوبت و افزودن حرکت تصادفی در صورت خطای API ==="

cat > frontend/script.js << 'EOF'
const API_URL = "/api/bestmove";
let board = null;
let game = new Chess();
let playerColor = 'w';
let isThinking = false;

function initBoard() {
    board = Chessboard('board', {
        draggable: true,
        position: 'start',
        orientation: playerColor,
        onDragStart: onDragStart,
        onDrop: onDrop,
        onSnapEnd: onSnapEnd,
        pieceTheme: 'https://chessboardjs.com/img/chesspieces/wikipedia/{piece}.png'
    });
    updateStatus();
}

function onDragStart(source, piece, position, orientation) {
    if (game.game_over() || isThinking || game.turn() !== playerColor) return false;
}

function onDrop(source, target) {
    const move = game.move({ from: source, to: target, promotion: 'q' });
    if (move === null) return 'snapback';
    updateStatus();
    setTimeout(makeComputerMove, 300);
}

function onSnapEnd() {
    board.position(game.fen());
}

// تابع کمکی برای انتخاب یک حرکت تصادفی قانونی با chess.js
function randomLegalMove() {
    const moves = game.moves({ verbose: true });
    if (moves.length === 0) return null;
    const randomMove = moves[Math.floor(Math.random() * moves.length)];
    return randomMove;
}

async function makeComputerMove() {
    if (game.game_over() || isThinking) return;
    isThinking = true;
    $('#status').text('⏳ کامپیوتر در حال فکر کردن...');

    let moveToApply = null;

    // ابتدا سعی کن از API حرکت بگیری
    try {
        const controller = new AbortController();
        const timeout = setTimeout(() => controller.abort(), 8000);
        const resp = await fetch(`${API_URL}?fen=${encodeURIComponent(game.fen())}&depth=3`, {
            signal: controller.signal
        });
        clearTimeout(timeout);

        if (resp.ok) {
            const data = await resp.json();
            if (data.bestmove) {
                const from = data.bestmove.substring(0,2);
                const to = data.bestmove.substring(2,4);
                const promo = data.bestmove.length > 4 ? data.bestmove[4] : undefined;
                // بررسی کن که حرکت معتبر باشد
                const testMove = game.move({ from, to, promotion: promo });
                if (testMove !== null) {
                    game.undo(); // حرکت آزمایشی را برگردان
                    moveToApply = { from, to, promotion: promo }; // حرکت معتبر ذخیره شود
                }
            }
        }
    } catch (e) {
        console.warn('API failed, using random move:', e);
    }

    // اگر حرکت معتبر از API به دست نیامد، از حرکت تصادفی استفاده کن
    if (!moveToApply) {
        const randomMove = randomLegalMove();
        if (randomMove) {
            moveToApply = {
                from: randomMove.from,
                to: randomMove.to,
                promotion: randomMove.promotion || 'q'
            };
            $('#status').text('🎲 کامپیوتر حرکت تصادفی انجام داد.');
        } else {
            // هیچ حرکت قانونی وجود ندارد → بازی تمام شده (کیش و مات / پات)
            // game.game_over() باید true باشد
            isThinking = false;
            updateStatus();
            return;
        }
    }

    // حالا حرکت نهایی را روی بازی اصلی اعمال کن
    const finalMove = game.move(moveToApply);
    if (finalMove === null) {
        console.error('Final move failed, fallback random');
        const randomMove = randomLegalMove();
        if (randomMove) {
            game.move({ from: randomMove.from, to: randomMove.to, promotion: randomMove.promotion || 'q' });
        }
    }
    board.position(game.fen());
    if (moveToApply && !moveToApply.from.startsWith('random')) {
        const moveStr = moveToApply.from + moveToApply.to + (moveToApply.promotion ? moveToApply.promotion : '');
        $('#status').text(`🤖 کامپیوتر: ${moveStr}`).fadeOut(2500, function(){ updateStatus(); });
    } else {
        updateStatus();
    }

    isThinking = false;
}

function updateStatus() {
    let status = '';
    if (game.in_checkmate()) {
        status = game.turn() === playerColor ? '❌ کیش و مات! شما باختید.' : '🎉 کیش و مات! شما برنده شدید.';
    } else if (game.in_draw()) {
        status = '🤝 مساوی';
    } else {
        let turn = game.turn() === 'w' ? 'سفید' : 'سیاه';
        status = `نوبت ${turn}`;
    }
    $('#status').text(status);
}

$('#newGameBtn').click(() => {
    game.reset();
    board.start();
    isThinking = false;
    updateStatus();
});

$('#flipBtn').click(() => {
    playerColor = playerColor === 'w' ? 'b' : 'w';
    board.orientation(playerColor);
    updateStatus();
});

$(document).ready(initBoard);
EOF

echo "✅ اصلاحات انجام شد. تغییرات کلیدی:"
echo "   - حذف undo حرکت کاربر در صورت خطا"
echo "   - در صورت خطای API، حرکت تصادفی قانونی برای کامپیوتر اجرا می‌شود"
echo "   - جلوگیری از قفل شدن بازی و حفظ توالی نوبت‌ها"
echo "   - نمایش پیام مناسب برای کاربر"
echo ""
echo "🚀 تست محلی: python backend/app.py"
echo "☁️ انتشار: git add -A && git commit -m 'Fix turn bug: fallback random move' && git push"
