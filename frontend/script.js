const API_URL = "/api/bestmove";
const MAX_LEVEL = 8;
const WINS_TO_ADVANCE = 3;

let board, game, playerColor = 'w', isThinking = false;
let moveHistory = [], redoStack = [];
let level = 1, wins = 0, bonusPoints = 0;
let hintEnabled = false, coachEnabled = false, soundEnabled = true;
let audioCtx = null, bgMusicInterval = null;
let pendingBestMove = null;
let isReplayMode = false;   // آیا در حال replay هستیم؟
let replayTimeout = null;

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
    renderTopGames();
}
function advanceLevel(){
    if(level<MAX_LEVEL){ level++; wins=0; bonusPoints+=level*15; showToast(`🎉 تبریک! به سطح ${level} ارتقا یافتید! (+${level*15} امتیاز)`); playBonusSound(); }
    else showToast('🏆 شما قهرمان نهایی شدید!');
    saveProgress(); updateUI();
}

// ---------- تاریخچه بازی‌ها ----------
function getGameHistory(){
    try { return JSON.parse(localStorage.getItem('chessGameHistory') || '[]'); } catch(e) { return []; }
}
function saveGameToHistory(result, moves, finalScore){
    const history = getGameHistory();
    history.push({
        date: new Date().toLocaleString('fa-IR'),
        result: result, // 'user', 'computer', 'draw'
        moves: moves,   // آرایه‌ای از move objects {from, to, promotion}
        score: finalScore
    });
    // فقط ۲۰ بازی آخر نگه دار
    if (history.length > 20) history.shift();
    localStorage.setItem('chessGameHistory', JSON.stringify(history));
}
function renderTopGames(){
    const history = getGameHistory();
    // سه بازی با بالاترین امتیاز (score)
    history.sort((a,b) => b.score - a.score);
    const top3 = history.slice(0,3);
    const $list = $('#topGamesList').empty();
    if (top3.length === 0) {
        $list.append('<div class="game-entry">هنوز بازی‌ای ثبت نشده</div>');
        return;
    }
    top3.forEach((g, idx) => {
        const resultText = g.result === 'user' ? 'برد کاربر' : (g.result === 'computer' ? 'برد کامپیوتر' : 'مساوی');
        const entry = $(`<div class="game-entry">
            <span>${g.date} - ${resultText} (${g.score} امتیاز)</span>
            <button class="replay-btn">▶️ replay</button>
        </div>`);
        entry.find('.replay-btn').click((e) => {
            e.stopPropagation();
            startReplay(g.moves);
        });
        $list.append(entry);
    });
}

// ---------- Replay ----------
function startReplay(moves){
    if (isReplayMode) {
        clearReplay();
    }
    isReplayMode = true;
    // غیرفعال کردن کنترل‌ها
    $('.controls button').prop('disabled', true);
    $('#newGameBtn').prop('disabled', false); // فقط بازی جدید فعال باشد برای خروج
    // ریست تخته
    game.reset();
    board.position('start');
    $('#chatBox').empty().show();
    $('#status').text('▶️ در حال بازپخش...');
    stopBgMusic();
    // اجرای حرکت‌ها با تاخیر
    let moveIndex = 0;
    function nextMove(){
        if (moveIndex >= moves.length) {
            // پایان replay
            let resultText = '';
            if (game.in_checkmate()) {
                resultText = game.turn() === 'w' ? 'کامپیوتر برنده شد' : 'کاربر برنده شد';
            } else if (game.in_draw()) {
                resultText = 'مساوی';
            } else {
                resultText = 'بازی ناتمام';
            }
            $('#chatBox').append(`<div>🏁 ${resultText}</div>`);
            $('#status').text(resultText);
            // بعد از ۸ ثانیه بستن replay
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
        replayTimeout = setTimeout(nextMove, 1000); // هر حرکت ۱ ثانیه
    }
    nextMove();
}
function clearReplay(){
    if (replayTimeout) clearTimeout(replayTimeout);
    isReplayMode = false;
    $('.controls button').prop('disabled', false);
    $('#chatBox').hide().empty();
    // برگرداندن تخته به وضعیت فعلی بازی (اگر game در حال replay نبوده)
    // اما چون game در replay تغییر کرده، بهتر است بازی جدید شروع کنیم یا وضعیت قبلی برگردد؟
    // در اینجا ما game را به حالت initial برمی‌گردانیم تا کاربر بتواند بازی جدید کند.
    game.reset();
    board.start();
    updateStatus();
    startBgMusic();
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
    if(isReplayMode || game.game_over() || isThinking || game.turn()!==playerColor) return false;
    if((playerColor==='w' && piece.startsWith('b')) || (playerColor==='b' && piece.startsWith('w'))) return false;
}
function onDrop(source, target){
    if(isReplayMode) return 'snapback';
    const move = game.move({from:source, to:target, promotion:'q'});
    if(!move) return 'snapback';

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
        pendingBestMove = null;
    }

    moveHistory.push({move, fenBefore: game.fen()});
    redoStack = [];
    if(move.captured) playCaptureSound(); else playMoveSound();
    if(game.in_check()) playCheckSound();
    updateStatus();

    if(coachEnabled && !game.game_over()){
        fetchBestMoveForCoach();
    }

    setTimeout(makeComputerMove, 300);
}
function onSnapEnd(){ board.position(game.fen()); }
function onMouseoverSquare(square, piece){
    if(isReplayMode || !hintEnabled || isThinking || game.game_over() || game.turn()!==playerColor) return;
    if(piece && ((playerColor==='w' && piece.startsWith('w')) || (playerColor==='b' && piece.startsWith('b')))){
        const moves = game.moves({square, verbose:true});
        $('.square-55d63').removeClass('highlight-square');
        moves.forEach(m=>$('#board .square-'+m.to).addClass('highlight-square'));
        $('#'+square).addClass('highlight-square');
    }
}
function onMouseoutSquare(){ if(hintEnabled) $('.square-55d63').removeClass('highlight-square'); }

async function fetchBestMoveForCoach(){
    try {
        const resp = await fetch(`${API_URL}?fen=${encodeURIComponent(game.fen())}&depth=2`);
        const data = await resp.json();
        if(data.bestmove){
            const from = data.bestmove.substring(0,2);
            const to = data.bestmove.substring(2,4);
            const promo = data.bestmove.length>4 ? data.bestmove[4] : undefined;
            const test = game.move({from, to, promotion: promo});
            if(test) { game.undo(); pendingBestMove = {from, to, promotion: promo}; }
        }
    } catch(e) { pendingBestMove = null; }
}

async function makeComputerMove(){
    if(isReplayMode || game.game_over() || isThinking) return;
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

function updateStatus(){
    if(isReplayMode) return;
    let status='';
    if(game.in_checkmate()){
        status = game.turn()===playerColor ? '❌ کیش و مات! شما باختید.' : '🎉 کیش و مات! شما برنده شدید.';
        if(game.turn()!==playerColor){ wins++; bonusPoints+=10; saveProgress(); updateUI(); if(wins>=WINS_TO_ADVANCE) advanceLevel(); }
        playMateSound();
        // ذخیره بازی در تاریخچه
        const result = game.turn()===playerColor ? 'computer' : 'user';
        const allMoves = moveHistory.map(h => h.move);
        saveGameToHistory(result, allMoves, bonusPoints);
        renderTopGames();
    } else if(game.in_draw()){
        status='🤝 مساوی';
        saveGameToHistory('draw', moveHistory.map(h=>h.move), bonusPoints);
        renderTopGames();
    } else if(game.in_check()){
        status = game.turn()===playerColor ? '⚠️ کیش! شما در معرض خطر هستید.' : '⚠️ کیش! کامپیوتر را تهدید کردید.';
    } else {
        status = `نوبت ${game.turn()==='w'?'سفید':'سیاه'}`;
    }
    $('#status').text(status);
}
function checkGameEnd(){ if(game.game_over()) stopBgMusic(); }

// ---------- undo/redo ----------
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

// ---------- دکمه‌ها ----------
$('#newGameBtn').click(()=>{
    if (isReplayMode) { clearReplay(); return; }
    game.reset(); board.start(); moveHistory=[]; redoStack=[]; isThinking=false;
    updateStatus(); startBgMusic();
    if(coachEnabled) fetchBestMoveForCoach();
});
$('#flipBtn').click(()=>{ if(isReplayMode) return; playerColor = playerColor==='w'?'b':'w'; board.orientation(playerColor); updateStatus(); });
$('#hintBtn').click(function(){ hintEnabled=!hintEnabled; $(this).toggleClass('active'); if(!hintEnabled) $('.square-55d63').removeClass('highlight-square'); });
$('#coachBtn').click(function(){
    coachEnabled=!coachEnabled; $(this).toggleClass('active', coachEnabled);
    if(coachEnabled){
        pendingBestMove=null;
        if(!game.game_over() && game.turn()===playerColor) fetchBestMoveForCoach();
        showToast('🧠 مربی فعال شد.');
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
    renderTopGames();
    $('#soundToggle').addClass('active');
});
