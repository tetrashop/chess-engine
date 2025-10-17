class ChessEngine:
    def __init__(self):
        self.board = self.initialize_board()
        self.current_player = 'white'
        self.move_history = []
    
    def initialize_board(self):
        """ایجاد صفحه شطرنج اولیه"""
        return [
            ['r', 'n', 'b', 'q', 'k', 'b', 'n', 'r'],  # سطر 8 (سیاه)
            ['p', 'p', 'p', 'p', 'p', 'p', 'p', 'p'],  # سطر 7 (سیاه)
            [' ', ' ', ' ', ' ', ' ', ' ', ' ', ' '],  # سطر 6
            [' ', ' ', ' ', ' ', ' ', ' ', ' ', ' '],  # سطر 5
            [' ', ' ', ' ', ' ', ' ', ' ', ' ', ' '],  # سطر 4
            [' ', ' ', ' ', ' ', ' ', ' ', ' ', ' '],  # سطر 3
            ['P', 'P', 'P', 'P', 'P', 'P', 'P', 'P'],  # سطر 2 (سفید)
            ['R', 'N', 'B', 'Q', 'K', 'B', 'N', 'R']   # سطر 1 (سفید)
        ]
    
    def display_board(self):
        """نمایش صفحه شطرنج"""
        print("\n  a b c d e f g h")
        print("  ----------------")
        for i, row in enumerate(self.board):
            print(f"{8-i}|{' '.join(row)}|{8-i}")
        print("  ----------------")
        print("  a b c d e f g h")
    
    def get_piece_name(self, piece):
        """نام قطعه به فارسی"""
        names = {
            'p': 'سرباز', 'P': 'سرباز',
            'r': 'رخ', 'R': 'رخ',
            'n': 'اسب', 'N': 'اسب',
            'b': 'فیل', 'B': 'فیل',
            'q': 'وزیر', 'Q': 'وزیر',
            'k': 'شاه', 'K': 'شاه'
        }
        return names.get(piece, 'خالی')

if __name__ == "__main__":
    engine = ChessEngine()
    print("🚀 موتور شطرنج راه‌اندازی شد!")
    engine.display_board()
    print(f"\n📊 اطلاعات سیستم:")
    print(f"- بازیکن فعلی: {'سفید' if engine.current_player == 'white' else 'سیاه'}")
    print(f"- تعداد حرکات: {len(engine.move_history)}")
