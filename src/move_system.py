class MoveSystem:
    def __init__(self, chess_engine):
        self.engine = chess_engine
    
    def is_valid_move(self, from_pos, to_pos):
        """بررسی معتبر بودن حرکت"""
        row_from, col_from = from_pos
        row_to, col_to = to_pos
        
        # بررسی وجود قطعه در مبدأ
        if self.engine.board[row_from][col_from] == ' ':
            return False, "مبدأ خالی است"
        
        piece = self.engine.board[row_from][col_from]
        
        # حرکت سرباز سفید
        if piece == 'P':
            # حرکت مستقیم یک خانه
            if row_to == row_from - 1 and col_to == col_from and self.engine.board[row_to][col_to] == ' ':
                return True, "حرکت سرباز یک خانه معتبر"
            # حرکت اول دو خانه (فقط از ردیف دوم)
            if row_from == 6 and row_to == 4 and col_to == col_from and self.engine.board[row_to][col_to] == ' ':
                return True, "حرکت سرباز دو خانه معتبر"
        
        # حرکت سرباز سیاه
        if piece == 'p':
            # حرکت مستقیم یک خانه
            if row_to == row_from + 1 and col_to == col_from and self.engine.board[row_to][col_to] == ' ':
                return True, "حرکت سرباز یک خانه معتبر"
            # حرکت اول دو خانه (فقط از ردیف هفتم)
            if row_from == 1 and row_to == 3 and col_to == col_from and self.engine.board[row_to][col_to] == ' ':
                return True, "حرکت سرباز دو خانه معتبر"
        
        return False, "حرکت نامعتبر"

    def make_move(self, from_pos, to_pos):
        """انجام حرکت"""
        valid, message = self.is_valid_move(from_pos, to_pos)
        if valid:
            piece = self.engine.board[from_pos[0]][from_pos[1]]
            self.engine.board[to_pos[0]][to_pos[1]] = piece
            self.engine.board[from_pos[0]][from_pos[1]] = ' '
            self.engine.move_history.append((from_pos, to_pos))
            self.engine.current_player = 'black' if self.engine.current_player == 'white' else 'white'
        return valid, message
