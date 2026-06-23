const API_URL = "https://chess-engine-89fz.vercel.app/api";
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
let openingBook = {};
let sessionId = null;

/* ---------- توابع کمکی session ---------- */
async function getOrCreateSession() {
    let sid = localStorage.getItem('chessSessionId');
    if (sid) {
        sessionId = sid;
        return;
    }
    try {
        const resp = await fetch(`${API_URL}/session`, { method: 'POST' });
        const data = await resp.json();
        if (data.session_id) {
            sessionId = data.session_id;
            localStorage.setItem('chessSessionId', sessionId);
        }
    } catch (e) {
        console.warn('Cannot create session offline, using local only.');
    }
}

async function loadRemoteState() {
    if (!sessionId) return;
    try {
        const resp = await fetch(`${API_URL}/session/${sessionId}`);
        if (!resp.ok) return;
        const state = await resp.json();
        // بارگذاری FEN
        game.load(state.fen);
        // اجرای تاریخچه
        state.history.forEach(m => game.move(m));
        board.position(game.fen());
        // بازیابی متغیرها
        level = state.level || 1;
        wins = state.wins || 0;
        bonusPoints = state.bonusPoints || 0;
        userColor = state.userColor || 'w';
        playerColor = userColor;
        moveHistory = state.history.map(m => ({ move: m, fenBefore: '' })); // بازسازی تقریبی
        redoStack = [];
        updateUI();
    } catch (e) {
        console.warn('Could not load remote state, using local.');
    }
}

async function saveRemoteState() {
    if (!sessionId) return;
    try {
        const payload = {
            fen: game.fen(),
            history: moveHistory.map(h => h.move),
            level, wins, bonusPoints, userColor
        };
        await fetch(`${API_URL}/session/${sessionId}`, {
            method: 'PUT',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(payload)
        });
    } catch (e) {
        console.warn('Could not save remote state.');
    }
}

/* ---------- صداها (بدون تغییر) ---------- */
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

/* ---------- ذخیره و بازیابی ---------- */
function loadProgress(){ /* دیگر از localStorage استفاده نمی‌کنیم، state سرور می‌آید */ }
function saveProgress(){ /* به‌صورت remote ذخیره می‌شود */ }

/* ---------- UI ---------- */
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
    saveRemoteState();
    updateUI();
}

/* ---------- تاریخچه و پنل پایینی ---------- */
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

/* ---------- Replay (خلاصه) ---------- */
function startReplay(moves){ /* ... */ }
function clearReplay(){ /* ... */ }

/* ---------- تخته ---------- */
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
            // مربی ...
            moveHistory.push({move, fenBefore: game.fen()});
            redoStack = [];
            if(move.captured) playCaptureSound(); else playMoveSound();
            if(game.in_check()) playCheckSound();
            updateStatus();
            saveRemoteState();   // <-- ذخیره در سرور
            if(coachEnabled && !game.game_over()) fetchBestMoveForCoach();
            if (game.turn() !== userColor) setTimeout(makeComputerMove, 300);
        },
        pieceTheme: (piece) => 'data:image/svg+xml;utf8,' + encodeURIComponent(PIECE_SVGS[piece])
    });
    updateStatus(); updateUI(); startBgMusic();
}

/* ---------- API و حرکت کامپیوتر (با کتاب) ---------- */
async function fetchBestMoveForCoach(){
    try {
        const resp = await fetch(`${API_URL}/bestmove?fen=${encodeURIComponent(game.fen())}&depth=2`);
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

    // ۱. کتاب افتتاحیه
    const fenKey = game.fen().split(' ').slice(0,4).join(' ');
    if (openingBook[fenKey]) {
        const bookMove = openingBook[fenKey];
        const from = bookMove.substring(0,2), to = bookMove.substring(2,4);
        const promo = bookMove.length > 4 ? bookMove[4] : undefined;
        const test = game.move({from, to, promotion: promo});
        if (test) { game.undo(); moveToApply = { from, to, promotion: promo }; }
    }

    // ۲. API
    if (!moveToApply) {
        try {
            const controller = new AbortController();
            const timeout = setTimeout(() => controller.abort(), 8000);
            const depth = Math.min(level + 1, 3);
            const resp = await fetch(`${API_URL}/bestmove?fen=${encodeURIComponent(game.fen())}&depth=${depth}`, { signal: controller.signal });
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
    }

    // ۳. فقط در نبود کتاب و API
    if (!moveToApply) {
        const moves = game.moves({ verbose: true });
        if (moves.length) {
            const rand = moves[Math.floor(Math.random() * moves.length)];
            moveToApply = { from: rand.from, to: rand.to, promotion: rand.promotion || 'q' };
            showToast('⚠️ نه کتاب داشت، نه اینترنت – حرکت تصادفی');
        }
    }

    if (moveToApply) {
        game.move(moveToApply);
        board.position(game.fen());
        moveHistory.push({ move: moveToApply, fenBefore: game.fen() });
        redoStack = [];
        if(moveToApply.captured) playCaptureSound(); else playMoveSound();
        if(game.in_check()) playCheckSound();
        saveRemoteState();   // <-- ذخیره در سرور
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

function updateStatus(){ /* مشابه قبل */ }

/* ---------- دکمه‌ها (بدون تغییر) ---------- */
$('#newGameBtn').click(()=>{ /* ریست و saveRemoteState */ });
$('#undoBtn').click(()=>{ /* undo و saveRemoteState */ });
$('#redoBtn').click(()=>{ /* redo و saveRemoteState */ });
$('#flipBtn').click(()=>{ /* ... */ });
$('#switchColorBtn').click(()=>{ /* ... */ });
$('#hintBtn').click(function(){ /* ... */ });
$('#coachBtn').click(function(){ /* ... */ });
$('#soundToggle').click(function(){ /* ... */ });

function showToast(msg){ const $t=$('#toast'); $t.text(msg).addClass('show'); setTimeout(()=>$t.removeClass('show'),3000); }

/* ---------- SVG مهره‌ها ---------- */
const PIECE_SVGS = { /* ... */ };

// ── شروع برنامه ──
$(document).ready(async () => {
    game = new Chess();
    await getOrCreateSession();
    await loadRemoteState();  // تلاش برای بازیابی state از سرور
    initBoard();
    $('#soundToggle').addClass('active');
});
