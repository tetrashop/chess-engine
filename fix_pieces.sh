#!/usr/bin/env bash
# fix_pieces.sh – رفع بارگذاری تصاویر مهره‌ها

cd ~/chess-engine

echo "=== اصلاح آدرس تصاویر مهره‌ها ==="

sed -i "s|pieceTheme: 'https://chessboardjs.com/img/chesspieces/wikipedia/{piece}.png'|pieceTheme: 'https://cdnjs.cloudflare.com/ajax/libs/chessboard-js/1.0.0/img/chesspieces/wikipedia/{piece}.png'|" frontend/script.js

cat >> frontend/script.js << 'EOF'

// Fallback بارگذاری تصاویر
$(document).ready(function() {
  $('img').on('error', function() {
    const piece = $(this).attr('src').match(/([wb][KQRBNP])/);
    if (piece) {
      $(this).attr('src', 'data:image/svg+xml;utf8,<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 45 45" width="45" height="45"><circle cx="22.5" cy="22.5" r="20" fill="%23' + (piece[1][0] === 'w' ? 'fff' : '000') + '" stroke="%23000" stroke-width="2"/><text x="22.5" y="30" font-size="28" text-anchor="middle" fill="' + (piece[1][0] === 'w' ? '#000' : '#fff') + '">' + piece[1][1] + '</text></svg>');
    }
  });
});
EOF

echo "✅ تصاویر مهره‌ها اصلاح شد."
echo "🚀 انتشار: git add -A && git commit -m 'Fix chess piece images CDN and add fallback' && git push"
