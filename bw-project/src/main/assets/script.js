const API_URL = "https://chess-engine.vercel.app/api/bestmove";
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

// ... (تمامی توابع صدا، ذخیره، replay و ... مانند قبل)
// برای جلوگیری از طولانی شدن، فقط توابع جدید و تغییرات نشان داده می‌شود.

// بارگذاری پیشرفت
function loadProgress(){
    try{ const s=JSON.parse(localStorage.getItem('chessEngineProgress')); if(s){ level=s.level||1; wins=s.wins||0; bonusPoints=s.bonusPoints||0; } }catch(e){}
    const savedColor = localStorage.getItem('userColor');
    if (savedColor === 'w' || savedColor === 'b') userColor = savedColor;
    playerColor = userColor;
}
function saveProgress(){ localStorage.setItem('chessEngineProgress', JSON.stringify({level,wins,bonusPoints})); }

// به‌روزرسانی UI (حالا نوار پایینی را هم پر می‌کند)
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

// به‌روزرسانی نوار پایینی با ۳ امتیاز برتر
function updateBottomScores(){
    const history = getGameHistory();
    history.sort((a,b) => b.score - a.score);
    const top3 = history.slice(0,3);
    $('#score1').text(top3[0] ? top3[0].score : '-');
    $('#score2').text(top3[1] ? top3[1].score : '-');
    $('#score3').text(top3[2] ? top3[2].score : '-');
}

// ذخیره و بازیابی تاریخچه (با فراخوانی updateBottomScores)
function getGameHistory(){ try { return JSON.parse(localStorage.getItem('chessGameHistory') || '[]'); } catch(e) { return []; } }
function saveGameToHistory(result, moves, finalScore, finalFen){
    const history = getGameHistory();
    history.push({ date: new Date().toLocaleString('fa-IR'), result, moves, score: finalScore, fen: finalFen });
    if (history.length > 20) history.shift();
    localStorage.setItem('chessGameHistory', JSON.stringify(history));
    updateBottomScores(); // بلافاصله نوار را به‌روز کن
}

// تابع initBoard و سایر توابع بدون تغییر از نسخهٔ کامل قبلی...
// (کل فایل script.js باید شامل همهٔ توابع باشد – اینجا به‌دلیل فضا خلاصه شده)

// برای سادگی، فایل کامل script.js را از frontend/script.js (اگر موجود باشد) کپی می‌کنیم
// در غیر این صورت یک نسخهٔ حداقلی هشدار می‌دهیم
if [ -f ~/chess-engine/frontend/script.js ]; then
    cp ~/chess-engine/frontend/script.js ~/chess-engine/bw-project/src/main/assets/script.js
    # اصلاح API_URL
    sed -i 's|const API_URL = .*|const API_URL = "https://chess-engine.vercel.app/api/bestmove";|' ~/chess-engine/bw-project/src/main/assets/script.js
else
    echo "⚠️  فایل frontend/script.js یافت نشد. لطفاً نسخهٔ کامل را در assets قرار دهید."
fi
