const API_URL = "/api/bestmove";  // relative path works locally & on Vercel

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
        pieceTheme: 'https://chessboardjs.com/img/chesspieces/wikipedia/{piece}.png' // تصاویر استاندارد ویکی‌پدیا
    });
    updateStatus();
}

function onDragStart(source, piece, position, orientation) {
    if (game.game_over() || isThinking || game.turn() !== playerColor) return false;
}

function onDrop(source, target) {
    const move = game.move({
        from: source,
        to: target,
        promotion: 'q'
    });
    if (move === null) return 'snapback';
    updateStatus();
    setTimeout(makeAIMove, 300);
}

function onSnapEnd() { board.position(game.fen()); }

async function makeAIMove() {
    if (game.game_over() || isThinking) return;
    isThinking = true;
    $('#status').text('در حال فکر کردن...');
    try {
        const resp = await fetch(`${API_URL}?fen=${encodeURIComponent(game.fen())}&depth=3`);
        const data = await resp.json();
        if (data.bestmove) {
            const from = data.bestmove.substring(0,2);
            const to = data.bestmove.substring(2,4);
            const promo = data.bestmove.length > 4 ? data.bestmove[4] : undefined;
            game.move({ from, to, promotion: promo });
            board.position(game.fen());
        }
    } catch (e) {
        console.error(e);
        $('#status').text('خطا در ارتباط با موتور');
    }
    isThinking = false;
    updateStatus();
}

function updateStatus() {
    let status = '';
    if (game.in_checkmate()) {
        status = game.turn() === playerColor ? 'کیش و مات! شما باختید.' : 'کیش و مات! شما برنده شدید.';
    } else if (game.in_draw()) {
        status = 'مساوی';
    } else {
        status = 'نوبت ' + (game.turn() === 'w' ? 'سفید' : 'سیاه');
    }
    $('#status').text(status);
}

$('#newGameBtn').click(() => { game.reset(); board.start(); isThinking = false; updateStatus(); });
$('#flipBtn').click(() => {
    playerColor = playerColor === 'w' ? 'b' : 'w';
    board.orientation(playerColor);
    updateStatus();
});

$(document).ready(initBoard);
