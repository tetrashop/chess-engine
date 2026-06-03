// آدرس API خود را در Vercel جایگزین کنید (یا تست محلی)
const API_URL = "/api/bestmove"; 

let board = null;
let game = new Chess();
let playerColor = 'w'; // سفید بازیکن
let computerColor = 'b';
let isThinking = false;

// مقداردهی اولیه تخته
function initBoard() {
    board = Chessboard('board', {
        draggable: true,
        position: 'start',
        orientation: playerColor,
        onDragStart: onDragStart,
        onDrop: onDrop,
        onSnapEnd: onSnapEnd
    });
    updateStatus();
}

// جلوگیری از حرکت در نوبت کامپیوتر یا پایان بازی
function onDragStart(source, piece, position, orientation) {
    if (game.game_over() || isThinking || game.turn() !== playerColor) {
        return false;
    }
}

// دریافت حرکت بازیکن
function onDrop(source, target) {
    const move = game.move({
        from: source,
        to: target,
        promotion: 'q' // همیشه وزیر (برای سادگی)
    });

    if (move === null) return 'snapback';

    updateStatus();
    // بعد از یک مکث کوتاه، نوبت کامپیوتر
    setTimeout(makeComputerMove, 300);
}

function onSnapEnd() {
    board.position(game.fen());
}

// درخواست بهترین حرکت از API
async function makeComputerMove() {
    if (game.game_over() || isThinking) return;

    isThinking = true;
    $('#status').text('در حال فکر کردن...');

    try {
        const fen = game.fen();
        const response = await fetch(`${API_URL}?fen=${encodeURIComponent(fen)}&depth=3`);
        const data = await response.json();

        if (data.bestmove) {
            const from = data.bestmove.substring(0, 2);
            const to = data.bestmove.substring(2, 4);
            const promotion = data.bestmove.length > 4 ? data.bestmove[4] : undefined;

            const move = game.move({ from, to, promotion });
            if (move) {
                board.position(game.fen());
            }
        }
    } catch (err) {
        console.error('خطا در دریافت حرکت:', err);
        $('#status').text('خطا در ارتباط با سرور');
    } finally {
        isThinking = false;
        updateStatus();
    }
}

// به‌روزرسانی متن وضعیت
function updateStatus() {
    let status = '';
    if (game.in_checkmate()) {
        status = game.turn() === playerColor ? 'کیش و مات! شما باختید.' : 'کیش و مات! شما برنده شدید.';
    } else if (game.in_draw()) {
        status = 'مساوی';
    } else {
        let turn = game.turn() === 'w' ? 'سفید' : 'سیاه';
        status = `نوبت ${turn}`;
    }
    $('#status').text(status);
}

// دکمهٔ بازی جدید
$('#newGameBtn').click(function() {
    game.reset();
    board.start();
    isThinking = false;
    updateStatus();
});

// دکمهٔ چرخاندن تخته
$('#flipBtn').click(function() {
    playerColor = playerColor === 'w' ? 'b' : 'w';
    board.orientation(playerColor);
    updateStatus();
});

// شروع برنامه
$(document).ready(function() {
    initBoard();
});
