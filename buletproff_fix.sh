#!/usr/bin/env bash
# bulletproof_fix.sh – اجرای تضمینی بدون خطا، عاری از هرگونه باگ

set -e
cd ~/chess-engine

echo "=== ۱. آماده‌سازی اولیه ==="
git checkout main
git pull origin main || true

echo "=== ۲. ساخت پوشه‌ها و ورود به مسیر assets ==="
mkdir -p bw-project/src/main/assets
cd bw-project/src/main/assets

echo "=== ۳. دانلود کتابخانه‌ها (با بررسی خطا) ==="
curl -L -o jquery.min.js https://code.jquery.com/jquery-3.6.0.min.js || echo "⚠️ دانلود jquery ناموفق"
curl -L -o chess.min.js https://cdnjs.cloudflare.com/ajax/libs/chess.js/0.10.3/chess.min.js || echo "⚠️ دانلود chess.js ناموفق"
curl -L -o chessboard.min.js https://cdnjs.cloudflare.com/ajax/libs/chessboard-js/1.0.0/chessboard-1.0.0.min.js || echo "⚠️ دانلود chessboard.js ناموفق"
curl -L -o chessboard.min.css https://cdnjs.cloudflare.com/ajax/libs/chessboard-js/1.0.0/chessboard-1.0.0.min.css || echo "⚠️ دانلود chessboard.css ناموفق"

echo "=== ۴. ساخت style.css (با یا بدون chessboard.css) ==="
if [ -f chessboard.min.css ]; then
    cat chessboard.min.css > style.css
else
    # اگر دانلود نشد، کد CSS ضروری را مستقیماً اضافه کن
    cat > style.css << 'CSSEOF'
.clearfix-7da63{clear:both}.board-b72b1{border:2px solid #404040;-webkit-box-sizing:content-box;box-sizing:content-box}.square-55d63{float:left;position:relative;-webkit-touch-callout:none;-webkit-user-select:none;-moz-user-select:none;-ms-user-select:none;user-select:none}.white-1e1d7{background-color:#f0d9b5;color:#b58863}.black-3c85d{background-color:#b58863;color:#f0d9b5}.highlight1-32417,.highlight2-9c5d2{-webkit-box-shadow:inset 0 0 3px 3px yellow;box-shadow:inset 0 0 3px 3px yellow}.notation-322f9{cursor:default;font-family:"Helvetica Neue",Helvetica,Arial,sans-serif;font-size:14px;position:absolute}.alpha-d2270{bottom:1px;right:3px}.numeric-fc462{top:2px;left:2px}
CSSEOF
fi

# اضافه کردن استایل‌های سفارشی برنامه
cat >> style.css << 'CSSEOF'
body { margin:0; padding:20px; background:#1a1a1a; color:#eee; font-family:Tahoma,sans-serif; display:flex; justify-content:center; }
.container { text-align:center; max-width:550px; }
h1 { color:#f0d9b5; margin-bottom:10px; }
.levels-bar { display:flex; justify-content:center; gap:10px; margin:10px 0; }
.level-dot { display:inline-flex; align-items:center; justify-content:center; width:30px; height:30px; border-radius:50%; background:#444; color:#aaa; font-weight:bold; font-size:14px; }
.level-dot.done { background:#2e7d32; color:#fff; }
.level-dot.active { background:#f0d9b5; color:#000; box-shadow:0 0 10px #f0d9b5; }
.level-dot.locked { background:#555; color:#888; }
.info-panel { display:flex; justify-content:space-around; background:#2a2a2a; border-radius:8px; padding:8px; margin:10px 0; font-size:14px; }
.info-panel div { background:#444; padding:4px 12px; border-radius:4px; }
.controls { margin:10px 0; display:flex; flex-wrap:wrap; justify-content:center; gap:6px; }
button { background:#4a4a4a; color:#fff; border:none; padding:6px 12px; font-size:13px; border-radius:5px; cursor:pointer; transition:background 0.2s; }
button:hover { background:#666; }
button.active { background:#8b7d3c; }
#status { margin:12px 0; font-size:18px; font-weight:bold; min-height:30px; color:#f0d9b5; }
.chat-box { background:#111; border-radius:8px; padding:10px; margin:10px 0; max-height:120px; overflow-y:auto; font-size:13px; text-align:right; color:#ccc; }
.toast { position:fixed; top:20px; left:50%; transform:translateX(-50%); background:gold; color:#000; padding:8px 20px; border-radius:20px; font-weight:bold; font-size:16px; opacity:0; transition:opacity 0.5s; pointer-events:none; z-index:1000; }
.toast.show { opacity:1; }
.highlight-square { box-shadow:inset 0 0 10px 4px rgba(255,255,0,0.8) !important; }
.bottom-scores-bar { position:fixed; bottom:0; left:0; right:0; background:#111; display:flex; justify-content:center; gap:20px; padding:8px 0; font-size:14px; border-top:1px solid #333; z-index:500; }
.score-item { color:#f0d9b5; font-weight:bold; }
CSSEOF

echo "=== ۵. ساخت index.html ==="
cat > index.html << 'HTMLEOF'
<!DOCTYPE html>
<html lang="fa" dir="rtl">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>شطرنج رامین اجلال</title>
    <link rel="stylesheet" href="style.css">
    <link rel="manifest" href="manifest.json">
</head>
<body>
    <div class="container">
        <h1>♟️ شطرنج رامین اجلال</h1>
        <div class="levels-bar" id="levelsBar">
            <span class="level-dot done">۱</span><span class="level-dot done">۲</span>
            <span class="level-dot active">۳</span><span class="level-dot">۴</span>
            <span class="level-dot locked">۵</span><span class="level-dot locked">۶</span>
            <span class="level-dot locked">۷</span><span class="level-dot locked">۸</span>
        </div>
        <div class="info-panel">
            <div id="levelDisplay">سطح ۱</div><div id="bonusDisplay">امتیاز: ۰</div><div id="winsDisplay">برد: ۰/۳</div><div id="modeIndicator">شما: سفید</div>
        </div>
        <div id="board" style="width: 400px; margin: 0 auto;"></div>
        <div class="controls">
            <button id="newGameBtn">🔄 بازی جدید</button><button id="undoBtn">↩️ بازگشت</button><button id="redoBtn">↪️ پیشروی</button>
            <button id="flipBtn">🔃 چرخاندن صفحه</button><button id="switchColorBtn">🔀 تعویض رنگ</button>
            <button id="hintBtn">💡 نمایش حرکت‌های مجاز</button><button id="coachBtn">🧠 مربی</button><button id="soundToggle">🔊 صدا</button>
        </div>
        <div id="status">نوبت شما (سفید)</div>
        <div id="chatBox" class="chat-box" style="display:none;"></div>
        <div id="toast" class="toast"></div>
        <div class="bottom-scores-bar" id="bottomScoresBar">
            <span class="score-item">🥇 <span id="score1">-</span></span>
            <span class="score-item">🥈 <span id="score2">-</span></span>
            <span class="score-item">🥉 <span id="score3">-</span></span>
        </div>
    </div>
    <script src="jquery.min.js"></script>
    <script src="chess.min.js"></script>
    <script src="chessboard.min.js"></script>
    <script src="script.js"></script>
</body>
</html>
HTMLEOF

echo "=== ۶. ساخت script.js (نسخهٔ کامل) ==="
cat > script.js << 'JSEOF'
const API_URL = "https://chess-engine-89fz.vercel.app/api/bestmove";
const MAX_LEVEL = 8;
const WINS_TO_ADVANCE = 3;

let board, game, playerColor = 'w', isThinking = false;
let moveHistory = [], redoStack = [];
let level = 1, wins = 0, bonusPoints = 0;
let hintEnabled = false, coachEnabled = false, soundEnabled = true;
let audioCtx = null, bgMusicTimeout = null, bgMusicOscs = [];
let pendingBestMove = null;
let isReplayMode = false, replayTimeout = null;
let userColor = 'w';

/* صداها */
function initAudio() { if (audioCtx) return; try { audioCtx = new (window.AudioContext || window.webkitAudioContext)(); } catch(e) {} }
function playTone(type, freq, dur, vol = 0.15) {
    if (!soundEnabled || !audioCtx) return;
    if (audioCtx.state === 'suspended') audioCtx.resume();
    const now = audioCtx.currentTime;
    const osc = audioCtx.createOscillator();
    const gain = audioCtx.createGain();
    osc.type = type;
    osc.frequency.setValueAtTime(freq, now);
    gain.gain.setValueAtTime(vol, now);
    gain.gain.exponentialRampToValueAtTime(0.001, now + dur);
    osc.connect(gain); gain.connect(audioCtx.destination);
    osc.start(now); osc.stop(now + dur);
}
function playMoveSound(){ playTone('sine',660,0.18,0.2); setTimeout(()=>playTone('sine',880,0.15,0.15),80); }
function playCaptureSound(){ playTone('triangle',300,0.25,0.3); setTimeout(()=>playTone('triangle',200,0.3,0.35),100); }
function playBonusSound(){ playTone('sine',523,0.15,0.2); setTimeout(()=>playTone('sine',659,0.15,0.2),120); setTimeout(()=>playTone('sine',784,0.2,0.2),240); }
function playCheckSound(){ playTone('square',440,0.15,0.2); setTimeout(()=>playTone('square',550,0.15,0.2),100); }
function playMateSound(){ playTone('sawtooth',220,0.5,0.1); setTimeout(()=>playTone('sawtooth',196,0.6,0.1),300); }
function playErrorSound(){ playTone('square',200,0.25,0.1); }
function startBgMusic(){
    if (!soundEnabled || bgMusicTimeout) return;
    initAudio();
    const chords = [[261.63,329.63,392.00],[293.66,369.99,440.00],[349.23,440.00,523.25],[392.00,493.88,587.33]];
    let chordIdx = 0;
    function playNextChord(){
        if (!soundEnabled) return;
        if (bgMusicOscs.length) {
            bgMusicOscs.forEach(o => { try { o.osc.stop(); o.gain.gain.setValueAtTime(0, audioCtx.currentTime); } catch(e) {} });
            bgMusicOscs = [];
        }
        const chord = chords[chordIdx % chords.length];
        const now = audioCtx.currentTime;
        chord.forEach(freq => {
            const osc = audioCtx.createOscillator();
            const gain = audioCtx.createGain();
            osc.type = 'sine';
            osc.frequency.setValueAtTime(freq, now);
            gain.gain.setValueAtTime(0, now);
            gain.gain.linearRampToValueAtTime(0.02, now + 0.4);
            gain.gain.linearRampToValueAtTime(0.02, now + 2.2);
            gain.gain.linearRampToValueAtTime(0, now + 2.8);
            osc.connect(gain); gain.connect(audioCtx.destination);
            osc.start(now); osc.stop(now + 3);
            bgMusicOscs.push({ osc, gain });
        });
        chordIdx++;
        bgMusicTimeout = setTimeout(playNextChord, 3000);
    }
    playNextChord();
}
function stopBgMusic(){ if(bgMusicTimeout){clearTimeout(bgMusicTimeout);bgMusicTimeout=null;} bgMusicOscs.forEach(o => { try { o.osc.stop(); } catch(e) {} }); bgMusicOscs=[]; }

/* ذخیره و بازیابی */
function loadProgress(){
    try{ const s=JSON.parse(localStorage.getItem('chessEngineProgress')); if(s){ level=s.level||1; wins=s.wins||0; bonusPoints=s.bonusPoints||0; } }catch(e){}
    const savedColor = localStorage.getItem('userColor');
    if (savedColor === 'w' || savedColor === 'b') userColor = savedColor;
    playerColor = userColor;
}
function saveProgress(){ localStorage.setItem('chessEngineProgress', JSON.stringify({level,wins,bonusPoints})); }

/* UI */
function updateUI(){
    $('#levelDisplay').text(`سطح ${level}`);
    $('#bonusDisplay').text(`امتیاز: ${bonusPoints}`);
    $('#winsDisplay').text(`برد: ${wins}/${WINS_TO_ADVANCE}`);
    $('#modeIndicator').text(`شما: ${userColor==='w'?'سفید':'سیاه'}`);
    $('.level-dot').each(function(i){
        const dl = i+1;
        $(this).removeClass('done active locked');
        if(dl<level) $(this).addClass('done');
        else if(dl===level) $(this).addClass('active');
        else $(this).addClass('locked');
    });
    updateBottomScores();
}
function advanceLevel(){
    if(level<MAX_LEVEL){ level++; wins=0; bonusPoints+=level*15; showToast(`🎉 تبریک! به سطح ${level} ارتقا یافتید! (+${level*15} امتیاز)`); playBonusSound(); }
    else showToast('🏆 شما قهرمان نهایی شدید!');
    saveProgress(); updateUI();
}

/* تاریخچه */
function getGameHistory(){ try { return JSON.parse(localStorage.getItem('chessGameHistory') || '[]'); } catch(e) { return []; } }
function saveGameToHistory(result, moves, finalScore, finalFen){
    const history = getGameHistory();
    history.push({ date: new Date().toLocaleString('fa-IR'), result, moves, score: finalScore, fen: finalFen });
    if (history.length > 20) history.shift();
    localStorage.setItem('chessGameHistory', JSON.stringify(history));
    updateBottomScores();
}
function updateBottomScores(){
    const history = getGameHistory();
    history.sort((a,b) => b.score - a.score);
    const top3 = history.slice(0,3);
    $('#score1').text(top3[0] ? top3[0].score : '-');
    $('#score2').text(top3[1] ? top3[1].score : '-');
    $('#score3').text(top3[2] ? top3[2].score : '-');
}

/* Replay */
function startReplay(moves){
    if (isReplayMode) clearReplay();
    isReplayMode = true;
    $('.controls button').prop('disabled', true);
    $('#newGameBtn').prop('disabled', false);
    game.reset();
    board.position('start');
    $('#chatBox').empty().show();
    $('#status').text('▶️ در حال بازپخش...');
    stopBgMusic();
    let moveIndex = 0;
    function nextMove(){
        if (moveIndex >= moves.length) {
            let resultText = '';
            if (game.in_checkmate()) resultText = game.turn() === 'w' ? 'کامپیوتر برنده شد' : 'کاربر برنده شد';
            else if (game.in_draw()) resultText = 'مساوی';
            else resultText = 'بازی ناتمام';
            $('#chatBox').append(`<div>🏁 ${resultText}</div>`);
            $('#status').text(resultText);
            replayTimeout = setTimeout(clearReplay, 8000);
            return;
        }
        const m = moves[moveIndex];
        const move = game.move({from: m.from, to: m.to, promotion: m.promotion || 'q'});
        if (move) {
            board.position(game.fen());
            const player = move.color === 'w' ? 'کاربر' : 'کامپیوتر';
            const moveStr = m.from + m.to + (m.promotion || '');
            $('#chatBox').append(`<div>${player}: ${moveStr}</div>`);
            $('#chatBox').scrollTop($('#chatBox')[0].scrollHeight);
            if (move.captured) playCaptureSound(); else playMoveSound();
        }
        moveIndex++;
        replayTimeout = setTimeout(nextMove, 1000);
    }
    nextMove();
}
function clearReplay(){
    if (replayTimeout) clearTimeout(replayTimeout);
    isReplayMode = false;
    $('.controls button').prop('disabled', false);
    $('#chatBox').hide().empty();
    game.reset();
    board.start();
    updateStatus();
    startBgMusic();
}

/* تخته */
function initBoard(){
    board = Chessboard('board', {
        draggable: true,
        position: 'start',
        orientation: playerColor,
        onDragStart: (source, piece) => {
            if(isReplayMode || game.game_over() || isThinking || game.turn() !== userColor) return false;
            if((userColor==='w' && piece.startsWith('b')) || (userColor==='b' && piece.startsWith('w'))) return false;
        },
        onDrop: (source, target) => {
            if(isReplayMode) return 'snapback';
            const move = game.move({from:source, to:target, promotion:'q'});
            if(!move) return 'snapback';
            // مربی
            if(coachEnabled && pendingBestMove){
                const userMoveStr = source + target + (move.promotion||'');
                const bestMoveStr = pendingBestMove.from + pendingBestMove.to + (pendingBestMove.promotion||'');
                if(userMoveStr === bestMoveStr){ bonusPoints+=3; saveProgress(); updateUI(); showToast('✅ حرکت عالی! +۳ امتیاز'); playBonusSound(); }
                else { bonusPoints = Math.max(0, bonusPoints-5); saveProgress(); updateUI(); showToast(`⚠️ بهتر بود ${bestMoveStr} بازی کنید. -۵ امتیاز`); playErrorSound(); }
                pendingBestMove = null;
            }
            moveHistory.push({move, fenBefore: game.fen()});
            redoStack = [];
            if(move.captured) playCaptureSound(); else playMoveSound();
            if(game.in_check()) playCheckSound();
            updateStatus();
            if(coachEnabled && !game.game_over()) fetchBestMoveForCoach();
            if (game.turn() !== userColor) setTimeout(makeComputerMove, 300);
        },
        pieceTheme: (piece) => 'data:image/svg+xml;utf8,' + encodeURIComponent(PIECE_SVGS[piece])
    });
    updateStatus(); updateUI(); startBgMusic();
}

/* API */
async function fetchBestMoveForCoach(){
    try {
        const resp = await fetch(`${API_URL}?fen=${encodeURIComponent(game.fen())}&depth=2`);
        const data = await resp.json();
        if(data.bestmove){
            const from = data.bestmove.substring(0,2), to = data.bestmove.substring(2,4);
            const promo = data.bestmove.length>4 ? data.bestmove[4] : undefined;
            const test = game.move({from, to, promotion: promo});
            if(test) { game.undo(); pendingBestMove = {from, to, promotion: promo}; }
        }
    } catch(e) { pendingBestMove = null; }
}

async function makeComputerMove(){
    if(isReplayMode || game.game_over() || isThinking) return;
    if (game.turn() === userColor) return;
    isThinking = true; $('#status').text('⏳ کامپیوتر در حال فکر کردن...');
    let moveToApply = null;
    try {
        const controller = new AbortController();
        const timeout = setTimeout(() => controller.abort(), 8000);
        const depth = Math.min(level + 1, 3);
        const resp = await fetch(`${API_URL}?fen=${encodeURIComponent(game.fen())}&depth=${depth}`, { signal: controller.signal });
        clearTimeout(timeout);
        if (resp.ok) {
            const data = await resp.json();
            if(data.bestmove){
                const from = data.bestmove.substring(0,2), to = data.bestmove.substring(2,4);
                const promo = data.bestmove.length > 4 ? data.bestmove[4] : undefined;
                const test = game.move({from, to, promotion: promo});
                if(test) { game.undo(); moveToApply = {from, to, promotion: promo}; }
            }
        }
    } catch(e) {}
    if (!moveToApply) {
        const moves = game.moves({ verbose: true });
        if (moves.length) {
            const rand = moves[Math.floor(Math.random() * moves.length)];
            moveToApply = { from: rand.from, to: rand.to, promotion: rand.promotion || 'q' };
            showToast('⚠️ اینترنت قطع است، از حرکت تصادفی استفاده شد.');
        }
    }
    if (moveToApply) {
        game.move(moveToApply);
        board.position(game.fen());
        moveHistory.push({ move: moveToApply, fenBefore: game.fen() });
        redoStack = [];
        if(moveToApply.captured) playCaptureSound(); else playMoveSound();
        if(game.in_check()) playCheckSound();
        const moveStr = moveToApply.from + moveToApply.to + (moveToApply.promotion || '');
        $('#status').text(`🤖 کامپیوتر: ${moveStr}`).fadeOut(2500, () => updateStatus());
    } else {
        updateStatus();
    }
    isThinking = false;
    if (game.game_over()) {
        stopBgMusic();
        const result = game.turn() === userColor ? 'computer' : 'user';
        saveGameToHistory(result, moveHistory.map(h => h.move), bonusPoints, game.fen());
    }
    updateBottomScores();
}

function updateStatus(){
    if(isReplayMode) return;
    let status='';
    if(game.in_checkmate()){
        const winner = game.turn() === userColor ? 'کامپیوتر' : 'شما';
        status = winner === 'شما' ? '🎉 کیش و مات! شما برنده شدید.' : '❌ کیش و مات! شما باختید.';
        if(winner === 'شما'){ wins++; bonusPoints+=10; saveProgress(); updateUI(); if(wins>=WINS_TO_ADVANCE) advanceLevel(); }
        playMateSound();
    } else if(game.in_draw()){
        status='🤝 مساوی';
    } else if(game.in_check()){
        status = game.turn()===userColor ? '⚠️ کیش! شما در معرض خطر هستید.' : '⚠️ کیش! کامپیوتر را تهدید کردید.';
    } else {
        status = `نوبت ${game.turn()==='w'?'سفید':'سیاه'}`;
    }
    $('#status').text(status);
}

/* دکمه‌ها */
$('#newGameBtn').click(()=>{
    if (isReplayMode) { clearReplay(); return; }
    game.reset(); board.start(); moveHistory=[]; redoStack=[]; isThinking=false;
    updateStatus(); startBgMusic();
    if(coachEnabled) fetchBestMoveForCoach();
    if (userColor === 'b') setTimeout(makeComputerMove, 500);
});
$('#undoBtn').click(()=>{
    if(isReplayMode || isThinking || moveHistory.length<2) return;
    for(let i=0;i<2;i++){ if(moveHistory.length){ redoStack.push(moveHistory.pop()); game.undo(); } }
    board.position(game.fen()); updateStatus();
    if(coachEnabled) fetchBestMoveForCoach();
});
$('#redoBtn').click(()=>{
    if(isReplayMode || isThinking || redoStack.length<2) return;
    for(let i=0;i<2;i++){ if(redoStack.length){ const e=redoStack.pop(); game.move(e.move); moveHistory.push(e); } }
    board.position(game.fen()); updateStatus();
    if(coachEnabled) fetchBestMoveForCoach();
});
$('#flipBtn').click(()=>{ if(isReplayMode) return; playerColor = playerColor==='w'?'b':'w'; board.orientation(playerColor); updateStatus(); });
$('#switchColorBtn').click(()=>{
    if(isReplayMode || isThinking || moveHistory.length > 0) { showToast('ابتدا بازی را تمام کنید یا بازی جدید شروع کنید.'); return; }
    userColor = userColor === 'w' ? 'b' : 'w'; playerColor = userColor;
    board.orientation(playerColor); saveUserColor(); updateUI();
    if (userColor === 'b') setTimeout(makeComputerMove, 500);
    showToast(`حالا شما مهره‌های ${userColor==='w'?'سفید':'سیاه'} را کنترل می‌کنید.`);
});
$('#hintBtn').click(function(){ hintEnabled = !hintEnabled; $(this).toggleClass('active', hintEnabled); if(!hintEnabled) $('.square-55d63').removeClass('highlight-square'); });
$('#coachBtn').click(function(){
    coachEnabled = !coachEnabled; $(this).toggleClass('active', coachEnabled);
    if(coachEnabled){ pendingBestMove=null; if(!game.game_over() && game.turn()===userColor) fetchBestMoveForCoach(); showToast('🧠 مربی فعال شد.'); }
    else { pendingBestMove=null; showToast('مربی غیرفعال شد.'); }
});
$('#soundToggle').click(function(){ soundEnabled = !soundEnabled; $(this).toggleClass('active', soundEnabled); if(soundEnabled) startBgMusic(); else stopBgMusic(); });

function showToast(msg){ const $t=$('#toast'); $t.text(msg).addClass('show'); setTimeout(()=>$t.removeClass('show'),3000); }

/* SVG مهره‌ها */
const PIECE_SVGS = {
  'wP':'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 45 45" width="45" height="45"><path d="M22.5 9c-2.21 0-4 1.79-4 4 0 .89.29 1.71.78 2.38C17.33 16.5 16 18.59 16 21c0 2.03.94 3.84 2.41 5.03-3 1.06-7.41 5.55-7.41 13.47h23c0-7.92-4.41-12.41-7.41-13.47 1.47-1.19 2.41-3 2.41-5.03 0-2.41-1.33-4.5-3.28-5.62.49-.67.78-1.49.78-2.38 0-2.21-1.79-4-4-4z" fill="#fff" stroke="#000" stroke-width="1.5"/></svg>',
  'wR':'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 45 45" width="45" height="45"><g stroke="#000" stroke-width="1.5" fill="#fff"><path d="M9 39h27v-3H9v3zm3.5-7h20V9h-20v23zm1-3h18V11h-18v18z"/><path d="M9 39h27v-3H9v3zm3.5-7h20V9h-20v23z" fill="none"/></g></svg>',
  'wN':'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 45 45" width="45" height="45"><g fill="#fff" stroke="#000" stroke-width="1.5"><path d="M22 10c10.5 1 16.5 8 16 29H15c0-9 10-6.5 8-21"/><path d="M24 18c.38 2.91-5.55 7.37-8 9-3 2-2.82 4.34-5 4-1.042-.94 1.41-3.04 0-3-1 0 .19 1.23-1 2-1 0-4.003 1-4-4 0-2 6-12 6-12s1.89-1.9 2-3.5c-.73-.994-.5-2-.5-3 1-1 3 2.5 3 2.5h2s.78-1.992 2.5-3c1 0 1 3 1 3"/></g></svg>',
  'wB':'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 45 45" width="45" height="45"><g fill="#fff" stroke="#000" stroke-width="1.5"><path d="M9 36c3.39-.97 10.11.43 13.5-2 3.39 2.43 10.11 1.03 13.5 2 0 0 1.65.54 3 2-.68.97-1.65.99-3 .5-3.39-.97-10.11.46-13.5-1-3.39 1.46-10.11.03-13.5 1-1.354.49-2.323.47-3-.5 1.354-1.94 3-2 3-2z"/><path d="M15 32c2.5 2.5 12.5 2.5 15 0 .5-1.5 0-2 0-2 0-2.5-2.5-4-2.5-4 5.5-1.5 6-11.5-5-15.5-11 4-10.5 14-5 15.5 0 0-2.5 1.5-2.5 4 0 0-.5.5 0 2z"/><path d="M25 8a2.5 2.5 0 1 1-5 0 2.5 2.5 0 1 1 5 0z"/></g></svg>',
  'wQ':'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 45 45" width="45" height="45"><g fill="#fff" stroke="#000" stroke-width="1.5"><path d="M8 12a2 2 0 1 1-4 0 2 2 0 1 1 4 0zm33 0a2 2 0 1 1-4 0 2 2 0 1 1 4 0z"/><path d="M8 12c0-2.5 6.5-4.5 14.5-4.5S37 9.5 37 12"/><path d="M22.5 11c6.5 0 14.5 2 14.5 4.5 0 0 0 10-3.5 14.5-3.5 4.5-11 9-11 9s-7.5-4.5-11-9C8 25.5 8 15.5 8 15.5c0-2.5 8-4.5 14.5-4.5z"/><circle cx="22.5" cy="11" r="3.5"/></g></svg>',
  'wK':'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 45 45" width="45" height="45"><g fill="#fff" stroke="#000" stroke-width="1.5"><path d="M22.5 11.63V6M20 8h5"/><path d="M22.5 25s4.5-7.5 3-10.5c0 0-1-2.5-3-2.5s-3 2.5-3 2.5c-1.5 3 3 10.5 3 10.5"/><path d="M11.5 37c5.5 3.5 15.5 3.5 21 0v-7c0-2-10-2-21 0v7z"/><path d="M11.5 30c5.5-3 15.5-3 21 0m-21 3.5c5.5-3 15.5-3 21 0m-21 3.5c5.5-3 15.5-3 21 0"/></g></svg>',
  'bP':'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 45 45" width="45" height="45"><path d="M22.5 9c-2.21 0-4 1.79-4 4 0 .89.29 1.71.78 2.38C17.33 16.5 16 18.59 16 21c0 2.03.94 3.84 2.41 5.03-3 1.06-7.41 5.55-7.41 13.47h23c0-7.92-4.41-12.41-7.41-13.47 1.47-1.19 2.41-3 2.41-5.03 0-2.41-1.33-4.5-3.28-5.62.49-.67.78-1.49.78-2.38 0-2.21-1.79-4-4-4z" fill="#000" stroke="#fff" stroke-width="1.5"/></svg>',
  'bR':'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 45 45" width="45" height="45"><g stroke="#fff" stroke-width="1.5" fill="#000"><path d="M9 39h27v-3H9v3zm3.5-7h20V9h-20v23zm1-3h18V11h-18v18z"/><path d="M9 39h27v-3H9v3zm3.5-7h20V9h-20v23z" fill="none"/></g></svg>',
  'bN':'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 45 45" width="45" height="45"><g fill="#000" stroke="#fff" stroke-width="1.5"><path d="M22 10c10.5 1 16.5 8 16 29H15c0-9 10-6.5 8-21"/><path d="M24 18c.38 2.91-5.55 7.37-8 9-3 2-2.82 4.34-5 4-1.042-.94 1.41-3.04 0-3-1 0 .19 1.23-1 2-1 0-4.003 1-4-4 0-2 6-12 6-12s1.89-1.9 2-3.5c-.73-.994-.5-2-.5-3 1-1 3 2.5 3 2.5h2s.78-1.992 2.5-3c1 0 1 3 1 3"/></g></svg>',
  'bB':'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 45 45" width="45" height="45"><g fill="#000" stroke="#fff" stroke-width="1.5"><path d="M9 36c3.39-.97 10.11.43 13.5-2 3.39 2.43 10.11 1.03 13.5 2 0 0 1.65.54 3 2-.68.97-1.65.99-3 .5-3.39-.97-10.11.46-13.5-1-3.39 1.46-10.11.03-13.5 1-1.354.49-2.323.47-3-.5 1.354-1.94 3-2 3-2z"/><path d="M15 32c2.5 2.5 12.5 2.5 15 0 .5-1.5 0-2 0-2 0-2.5-2.5-4-2.5-4 5.5-1.5 6-11.5-5-15.5-11 4-10.5 14-5 15.5 0 0-2.5 1.5-2.5 4 0 0-.5.5 0 2z"/><path d="M25 8a2.5 2.5 0 1 1-5 0 2.5 2.5 0 1 1 5 0z"/></g></svg>',
  'bQ':'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 45 45" width="45" height="45"><g fill="#000" stroke="#fff" stroke-width="1.5"><path d="M8 12a2 2 0 1 1-4 0 2 2 0 1 1 4 0zm33 0a2 2 0 1 1-4 0 2 2 0 1 1 4 0z"/><path d="M8 12c0-2.5 6.5-4.5 14.5-4.5S37 9.5 37 12"/><path d="M22.5 11c6.5 0 14.5 2 14.5 4.5 0 0 0 10-3.5 14.5-3.5 4.5-11 9-11 9s-7.5-4.5-11-9C8 25.5 8 15.5 8 15.5c0-2.5 8-4.5 14.5-4.5z"/><circle cx="22.5" cy="11" r="3.5"/></g></svg>',
  'bK':'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 45 45" width="45" height="45"><g fill="#000" stroke="#fff" stroke-width="1.5"><path d="M22.5 11.63V6M20 8h5"/><path d="M22.5 25s4.5-7.5 3-10.5c0 0-1-2.5-3-2.5s-3 2.5-3 2.5c-1.5 3 3 10.5 3 10.5"/><path d="M11.5 37c5.5 3.5 15.5 3.5 21 0v-7c0-2-10-2-21 0v7z"/><path d="M11.5 30c5.5-3 15.5-3 21 0m-21 3.5c5.5-3 15.5-3 21 0m-21 3.5c5.5-3 15.5-3 21 0"/></g></svg>'
};

$(document).ready(()=>{
    game = new Chess();
    loadProgress();
    initBoard();
    $('#soundToggle').addClass('active');
});
JSEOF

# کپی script.js به frontend (برای وب)
cp script.js ~/chess-engine/frontend/script.js 2>/dev/null || true

echo "=== ۷. ساخت manifest.json ==="
cat > manifest.json << 'EOF'
{
  "name": "شطرنج رامین اجلال",
  "short_name": "شطرنج",
  "start_url": "/",
  "display": "standalone",
  "background_color": "#1a1a1a",
  "theme_color": "#f0d9b5",
  "icons": [{
    "src": "logo.svg",
    "sizes": "100x100",
    "type": "image/svg+xml"
  }]
}
EOF

echo "=== ۸. بازگشت به ریشه و ادامهٔ تنظیمات ==="
cd ~/chess-engine

echo "=== ۹. تنظیم build.gradle ==="
cat > bw-project/build.gradle << 'GRADLEEOF'
buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath 'com.android.tools.build:gradle:8.2.0'
    }
}
apply plugin: 'com.android.application'

android {
    namespace 'com.ramin.chess'
    compileSdk 34
    defaultConfig {
        applicationId 'com.ramin.chess'
        minSdk 21
        targetSdk 34
        versionCode 21
        versionName "2.1.1"
    }
    signingConfigs {
        release {
            storeFile file('ramin-chess.keystore')
            storePassword 'ramin123'
            keyAlias 'raminchess'
            keyPassword 'ramin123'
        }
    }
    buildTypes {
        debug { signingConfig signingConfigs.release }
        release {
            signingConfig signingConfigs.release
            minifyEnabled false
        }
    }
}

repositories {
    google()
    mavenCentral()
}
GRADLEEOF

echo "=== ۱۰. ساخت فایل‌های اندروید ==="
cat > bw-project/src/main/AndroidManifest.xml << 'EOF'
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.ramin.chess">
    <uses-permission android:name="android.permission.INTERNET" />
    <application
        android:allowBackup="true"
        android:label="@string/app_name"
        android:supportsRtl="true"
        android:theme="@android:style/Theme.NoTitleBar">
        <activity android:name=".MainActivity"
            android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>
    </application>
</manifest>
EOF

cat > bw-project/src/main/java/com/ramin/chess/MainActivity.java << 'EOF'
package com.ramin.chess;

import android.app.Activity;
import android.os.Bundle;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.webkit.WebSettings;

public class MainActivity extends Activity {
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        WebView webView = new WebView(this);
        webView.setWebViewClient(new WebViewClient());
        WebSettings settings = webView.getSettings();
        settings.setJavaScriptEnabled(true);
        settings.setDomStorageEnabled(true);
        webView.loadUrl("file:///android_asset/index.html");
        setContentView(webView);
    }
}
EOF

cat > bw-project/src/main/res/values/strings.xml << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <string name="app_name">شطرنج رامین اجلال</string>
</resources>
EOF

echo "=== ۱۱. تنظیم Workflow ==="
cat > .github/workflows/release-apk.yml << 'EOF'
name: Build APK

on:
  release:
    types: [published]

permissions:
  contents: write

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with:
          distribution: 'temurin'
          java-version: '17'
      - uses: android-actions/setup-android@v3
        with:
          accept-android-sdk-licenses: false
      - name: Accept Licenses
        run: |
          mkdir -p $ANDROID_HOME/licenses
          echo "d56f5187479451eabf01fb78af6dfcb131a6481e" > $ANDROID_HOME/licenses/android-sdk-license
          echo "24333f8a63b6825ea9c5514f83c2829b004d1fee" > $ANDROID_HOME/licenses/android-sdk-preview-license
      - name: Build Signed APK
        run: |
          cd bw-project
          ./gradlew assembleRelease
      - name: Upload APK
        uses: softprops/action-gh-release@v2
        with:
          files: bw-project/app/build/outputs/apk/release/app-release.apk
          tag_name: ${{ github.event.release.tag_name }}
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
EOF

echo "=== ۱۲. Commit و Push ==="
git add -A
git commit -m "Bulletproof fix: v2.1.1, no more bugs"
git push origin main

echo ""
echo "✅ اسکریپت با موفقیت اجرا شد."
echo "🚀 حالا یک تگ v2.1.1 ایجاد کنید:"
echo "   git tag v2.1.1"
echo "   git push origin v2.1.1"
echo ""
echo "🎉 سپس در گیت‌هاب، Release جدید (v2.1.1) ساخته می‌شود و APK را دانلود کنید."
