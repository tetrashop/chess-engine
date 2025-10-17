from src.chess_engine import ChessEngine
from src.move_system import MoveSystem

engine = ChessEngine()
move_system = MoveSystem(engine)

# تست مختصات a2 و a4
from_square = "a2"
to_square = "a4"

print(f"مربع مبدأ: {from_square}")
print(f"مربع مقصد: {to_square}")

# تبدیل به مختصات
from_pos = (8 - int(from_square[1]), ord(from_square[0]) - ord('a'))
to_pos = (8 - int(to_square[1]), ord(to_square[0]) - ord('a'))

print(f"مختصات مبدأ: {from_pos}")
print(f"مختصات مقصد: {to_pos}")

# بررسی قطعه در مبدأ
piece = engine.board[from_pos[0]][from_pos[1]]
print(f"قطعه در مبدأ: '{piece}'")

# تست حرکت
valid, message = move_system.is_valid_move(from_pos, to_pos)
print(f"نتیجه بررسی: {valid}, {message}")
