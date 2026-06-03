// تنظیمات
const API_URL = "https://your-vercel-project.vercel.app/bestmove"; // آدرس API خود را جایگزین کنید
let board = null;
let game = new Chess();
let playerColor = 'w'; // بازیکن سفید
let thinking = false;

// راه‌اندازی تخته
board = Chessboard('board', {
    draggable: true,
    position: 'start',
    onDragStart: onDragStart,
    onDrop: onDrop,
    onSnapEnd: onSnapEnd,
    orientation: 'white'
});

// جلوگیری از حرکت در نوبت حریف
function onDragStart(source, piece, position, orientation) {
    if (game.game_over() || thinking || (game.turn() !== playerColor)) {
        return false;
    }
}

// دریافت حرکت کاربر
function onDrop(source, target) {
    const move = game.move({
        from: source,
        to: target,
        promotion: 'q' // همیشه وزیر (ساده‌سازی)
    });

    if (move === null) return 'snapback';

    // به‌روزرسانی وضعیت
    updateStatus();
    // درخواست حرکت از API
    setTimeout(makeAIMove, 250);
}

// به‌روزرسانی موقعیت تخته پس از حرکت
function onSnapEnd() {
    board.position(game.fen());
}

// درخواست بهترین حرکت از API
async function makeAIMove() {
    if (game.game_over() || thinking) return;
    thinking = true;
    $('#status').text('در حال فکر کردن...');
    try {
        const response = await fetch(`${API_URL}?fen=${encodeURIComponent(game.fen())}&depth=3`);
        const data = await response.json();
        if (data.bestmove) {
            const move = game.move({
                from: data.bestmove.slice(0,2),
                to: data.bestmove.slice(2,4),
                promotion: data.bestmove.length > 4 ? data.bestmove[4] : undefined
            });
            if (move) {
                board.position(game.fen());
            }
        }
    } catch (error) {
        console.error('خطا در ارتباط با API:', error);
    }
    thinking = false;
    updateStatus();
}

// به‌روزرسانی متن وضعیت
function updateStatus() {
    if (game.in_checkmate()) {
        $('#status').text('کیش و مات!');
    } else if (game.in_draw()) {
        $('#status').text('مساوی');
    } else {
        let turn = game.turn() === 'w' ? 'سفید' : 'سیاه';
        $('#status').text(`نوبت ${turn}`);
    }
}

// دکمه‌ها
$('#newGame').click(function() {
    game.reset();
    board.start();
    updateStatus();
    thinking = false;
});

$('#flipBoard').click(function() {
    board.flip();
});
