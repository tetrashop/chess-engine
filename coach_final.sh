#!/usr/bin/env bash
# coach_final.sh – مربی هوشمند، پیشنهاد بهترین حرکت، کسر امتیاز عادلانه

cd ~/chess-engine
mkdir -p frontend

echo "=== افزودن مربی هوشمند به فرانت‌اند ==="

# ────────────── 1. index.html (دکمه مربی اضافه شد) ──────────────
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
        <div class="levels-bar" id="levelsBar">
            <span class="level-dot done">۱</span><span class="level-dot done">۲</span>
            <span class="level-dot active">۳</span><span class="level-dot">۴</span>
            <span class="level-dot locked">۵</span><span class="level-dot locked">۶</span>
            <span class="level-dot locked">۷</span><span class="level-dot locked">۸</span>
        </div>
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
            <button id="coachBtn">🧠 مربی</button>
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

# ────────────── 2. style.css (بدون تغییر مهم) ──────────────
cat > frontend/style.css << 'CSSEOF'
body { margin:0; padding:20px; background:#1a1a1a; color:#eee; font-family:Tahoma,sans-serif; display:flex; justify-content:center; }
.container { text-align:center; max-width:500px; }
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
.toast { position:fixed; top:20px; left:50%; transform:translateX(-50%); background:gold; color:#000; padding:8px 20px; border-radius:20px; font-weight:bold; font-size:16px; opacity:0; transition:opacity 0.5s; pointer-events:none; z-index:1000; }
.toast.show { opacity:1; }
.highlight-square { box-shadow:inset 0 0 10px 4px rgba(255,255,0,0.8) !important; }
CSSEOF

# ────────────── 3. script.js (نسخه با مربی هوشمند) ──────────────
cat > frontend/script.js << 'JSEOF'
const API_URL = "/api/bestmove";
const MAX_LEVEL = 8;
const WINS_TO_ADVANCE = 3;

let board, game, playerColor = 'w', isThinking = false;
let moveHistory = [], redoStack = [];
let level = 1, wins = 0, bonusPoints = 0;
let hintEnabled = false, coachEnabled = false, soundEnabled = true;
let audioCtx = null, bgMusicInterval = null;
let pendingBestMove = null;   // ذخیره بهترین حرکت برای مربی

// ---------- صداها ----------
function initAudio() { if (audioCtx) return; try { audioCtx = new (window.AudioContext || window.webkitAudioContext)(); } catch(e) {} }
function playTone(freq, dur, type='square', vol=0.08) {
    if (!soundEnabled || !audioCtx) return;
    if (audioCtx.state === 'suspended') audioCtx.resume();
    const osc = audioCtx.createOscillator(), gain = audioCtx.createGain();
    osc.type = type; osc.frequency.setValueAtTime(freq, audioCtx.currentTime);
    gain.gain.setValueAtTime(vol, audioCtx.currentTime);
    gain.gain.exponentialRampToValueAtTime(0.001, audioCtx.currentTime + dur);
    osc.connect(gain); gain.connect(audioCtx.destination);
    osc.start(); osc.stop(audioCtx.currentTime + dur);
}
function playMoveSound(){ playTone(520,0.12); }
function playCaptureSound(){ playTone(220,0.18,'sawtooth'); playTone(160,0.2,'triangle'); }
function playBonusSound(){ playTone(800,0.1); setTimeout(()=>playTone(1000,0.1),80); }
function playCheckSound(){ playTone(400,0.12); setTimeout(()=>playTone(500,0.12),120); }
function playMateSound(){ playTone(300,0.25); setTimeout(()=>playTone(200,0.3),200); }
function playErrorSound(){ playTone(200,0.2,'square'); }
function startBgMusic(){
    if (!soundEnabled || bgMusicInterval) return;
    initAudio();
    const notes = [262,294,330,349,392,440,494,523];
    let i=0;
    bgMusicInterval = setInterval(()=>{ playTone(notes[i%notes.length],0.4,'sine',0.015); i++; },700);
}
function stopBgMusic(){ if(bgMusicInterval){clearInterval(bgMusicInterval);bgMusicInterval=null;} }

// ---------- ذخیره و بازیابی ----------
function loadProgress(){
    try{ const s=JSON.parse(localStorage.getItem('chessEngineProgress')); if(s){ level=s.level||1; wins=s.wins||0; bonusPoints=s.bonusPoints||0; } }catch(e){}
}
function saveProgress(){ localStorage.setItem('chessEngineProgress', JSON.stringify({level,wins,bonusPoints})); }
function updateUI(){
    $('#levelDisplay').text(`سطح ${level}`);
    $('#bonusDisplay').text(`امتیاز: ${bonusPoints}`);
    $('#winsDisplay').text(`برد: ${wins}/${WINS_TO_ADVANCE}`);
    $('.level-dot').each(function(i){
        const dl = i+1;
        $(this).removeClass('done active locked');
        if(dl<level) $(this).addClass('done');
        else if(dl===level) $(this).addClass('active');
        else $(this).addClass('locked');
    });
}
function advanceLevel(){
    if(level<MAX_LEVEL){ level++; wins=0; bonusPoints+=level*15; showToast(`🎉 تبریک! به سطح ${level} ارتقا یافتید! (+${level*15} امتیاز)`); playBonusSound(); }
    else showToast('🏆 شما قهرمان نهایی شدید!');
    saveProgress(); updateUI();
}

// ---------- راه‌اندازی تخته ----------
function initBoard(){
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
    updateStatus(); updateUI(); startBgMusic();
}
function onDragStart(source, piece){
    if(game.game_over() || isThinking || game.turn()!==playerColor) return false;
    if((playerColor==='w' && piece.startsWith('b')) || (playerColor==='b' && piece.startsWith('w'))) return false;
}
function onDrop(source, target){
    const move = game.move({from:source, to:target, promotion:'q'});
    if(!move) return 'snapback';

    // مربی: بررسی حرکت کاربر
    if(coachEnabled && pendingBestMove){
        const userMoveStr = source + target + (move.promotion||'');
        const bestMoveStr = pendingBestMove.from + pendingBestMove.to + (pendingBestMove.promotion||'');
        if(userMoveStr === bestMoveStr){
            bonusPoints += 3; saveProgress(); updateUI();
            showToast('✅ حرکت عالی! +۳ امتیاز');
            playBonusSound();
        } else {
            bonusPoints = Math.max(0, bonusPoints - 5); saveProgress(); updateUI();
            showToast(`⚠️ بهتر بود ${bestMoveStr} بازی کنید. -۵ امتیاز`);
            playErrorSound();
        }
        pendingBestMove = null; // مربی فقط حرکت فعلی را بررسی کرد
    }

    moveHistory.push({move, fenBefore: game.fen()});
    redoStack = [];
    if(move.captured) playCaptureSound(); else playMoveSound();
    if(game.in_check()) playCheckSound();
    updateStatus();

    // اگر مربی فعال باشد، بهترین حرکت بعدی را از API بگیر (برای نوبت کاربر بعدی)
    if(coachEnabled && !game.game_over()){
        fetchBestMoveForCoach();
    }

    setTimeout(makeComputerMove, 300);
}
function onSnapEnd(){ board.position(game.fen()); }
function onMouseoverSquare(square, piece){
    if(!hintEnabled || isThinking || game.game_over() || game.turn()!==playerColor) return;
    if(piece && ((playerColor==='w' && piece.startsWith('w')) || (playerColor==='b' && piece.startsWith('b')))){
        const moves = game.moves({square, verbose:true});
        $('.square-55d63').removeClass('highlight-square');
        moves.forEach(m=>$('#board .square-'+m.to).addClass('highlight-square'));
        $('#'+square).addClass('highlight-square');
    }
}
function onMouseoutSquare(){ if(hintEnabled) $('.square-55d63').removeClass('highlight-square'); }

// ---------- دریافت بهترین حرکت برای مربی ----------
async function fetchBestMoveForCoach(){
    try {
        const resp = await fetch(`${API_URL}?fen=${encodeURIComponent(game.fen())}&depth=2`);
        const data = await resp.json();
        if(data.bestmove){
            const from = data.bestmove.substring(0,2);
            const to = data.bestmove.substring(2,4);
            const promo = data.bestmove.length>4 ? data.bestmove[4] : undefined;
            // فقط اگر حرکت معتبر باشد
            const test = game.move({from, to, promotion: promo});
            if(test) { game.undo(); pendingBestMove = {from, to, promotion: promo}; }
        }
    } catch(e) { pendingBestMove = null; }
}

// ---------- حرکت کامپیوتر ----------
async function makeComputerMove(){
    if(game.game_over() || isThinking) return;
    isThinking = true; $('#status').text('⏳ کامپیوتر در حال فکر کردن...');
    let moveToApply = null;
    try {
        const controller = new AbortController();
        const timeout = setTimeout(()=>controller.abort(), 8000);
        const depth = Math.min(level+1, 4);
        const resp = await fetch(`${API_URL}?fen=${encodeURIComponent(game.fen())}&depth=${depth}`, {signal: controller.signal});
        clearTimeout(timeout);
        const data = await resp.json();
        if(data.bestmove){
            const from=data.bestmove.substring(0,2), to=data.bestmove.substring(2,4);
            const promo = data.bestmove.length>4 ? data.bestmove[4] : undefined;
            const test = game.move({from, to, promotion: promo});
            if(test){ game.undo(); moveToApply = {from, to, promotion: promo}; }
        }
    } catch(e) { console.warn('API fallback', e); }
    if(!moveToApply){
        const moves = game.moves({verbose:true});
        if(moves.length){ const rand=moves[Math.floor(Math.random()*moves.length)]; moveToApply=rand; }
    }
    if(moveToApply){
        const finalMove = game.move(moveToApply);
        if(!finalMove){ const moves=game.moves({verbose:true}); if(moves.length){ const rand=moves[Math.floor(Math.random()*moves.length)]; game.move(rand); } }
        board.position(game.fen());
        moveHistory.push({move:finalMove, fenBefore: game.fen()}); redoStack=[];
        if(finalMove && finalMove.captured) playCaptureSound(); else playMoveSound();
        if(game.in_check()) playCheckSound();
        const moveStr = moveToApply.from + moveToApply.to + (moveToApply.promotion||'');
        $('#status').text(`🤖 کامپیوتر: ${moveStr}`).fadeOut(2500, ()=>updateStatus());
    } else { updateStatus(); }
    isThinking = false;
    checkGameEnd();
}

// ---------- وضعیت ----------
function updateStatus(){
    let status='';
    if(game.in_checkmate()){
        status = game.turn()===playerColor ? '❌ کیش و مات! شما باختید.' : '🎉 کیش و مات! شما برنده شدید.';
        if(game.turn()!==playerColor){ wins++; bonusPoints+=10; saveProgress(); updateUI(); if(wins>=WINS_TO_ADVANCE) advanceLevel(); }
        playMateSound();
    } else if(game.in_draw()){ status='🤝 مساوی'; }
    else if(game.in_check()){ status = game.turn()===playerColor ? '⚠️ کیش! شما در معرض خطر هستید.' : '⚠️ کیش! کامپیوتر را تهدید کردید.'; }
    else { status = `نوبت ${game.turn()==='w'?'سفید':'سیاه'}`; }
    $('#status').text(status);
}
function checkGameEnd(){ if(game.game_over()) stopBgMusic(); }

// ---------- undo/redo ----------
$('#undoBtn').click(()=>{
    if(isThinking || moveHistory.length<2) return;
    for(let i=0;i<2;i++){ if(moveHistory.length){ redoStack.push(moveHistory.pop()); game.undo(); } }
    board.position(game.fen()); updateStatus();
    if(coachEnabled) fetchBestMoveForCoach();
});
$('#redoBtn').click(()=>{
    if(isThinking || redoStack.length<2) return;
    for(let i=0;i<2;i++){ if(redoStack.length){ const e=redoStack.pop(); game.move(e.move); moveHistory.push(e); } }
    board.position(game.fen()); updateStatus();
    if(coachEnabled) fetchBestMoveForCoach();
});

// ---------- دکمه‌ها ----------
$('#newGameBtn').click(()=>{
    game.reset(); board.start(); moveHistory=[]; redoStack=[]; isThinking=false;
    updateStatus(); startBgMusic();
    if(coachEnabled) fetchBestMoveForCoach();
});
$('#flipBtn').click(()=>{ playerColor = playerColor==='w'?'b':'w'; board.orientation(playerColor); updateStatus(); });
$('#hintBtn').click(function(){ hintEnabled=!hintEnabled; $(this).toggleClass('active'); if(!hintEnabled) $('.square-55d63').removeClass('highlight-square'); });
$('#coachBtn').click(function(){
    coachEnabled=!coachEnabled; $(this).toggleClass('active', coachEnabled);
    if(coachEnabled){
        pendingBestMove=null;
        if(!game.game_over() && game.turn()===playerColor) fetchBestMoveForCoach();
        showToast('🧠 مربی فعال شد. بهترین حرکت بررسی می‌شود.');
    } else {
        pendingBestMove=null;
        showToast('مربی غیرفعال شد.');
    }
});
$('#soundToggle').click(function(){ soundEnabled=!soundEnabled; $(this).toggleClass('active', soundEnabled); soundEnabled?startBgMusic():stopBgMusic(); });

function showToast(msg){ const $t=$('#toast'); $t.text(msg).addClass('show'); setTimeout(()=>$t.removeClass('show'),3000); }

$(document).ready(()=>{
    game = new Chess();
    loadProgress();
    initBoard();
    $('#soundToggle').addClass('active');
});
JSEOF

echo ""
echo "✅ مربی هوشمند با موفقیت اضافه شد."
echo "   - دکمه 'مربی' را روشن کنید."
echo "   - پس از هر حرکت شما، حرکت بهینه بررسی و امتیاز کسر/اضافه می‌شود."
echo "   - در صورت حرکت اشتباه، مربی پیام 'بهتر بود ...' نمایش می‌دهد."
echo ""
echo "🚀 تست محلی: python backend/app.py"
echo "☁️ انتشار: git add -A && git commit -m 'Add intelligent coach with fair scoring' && git push"
