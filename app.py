from src.chess_engine import ChessEngine
from src.move_system import MoveSystem

def main():
    engine = ChessEngine()
    move_system = MoveSystem(engine)
    
    print("🎯 موتور شطرنج - نسخه توسعه")
    print("دستورات: display, move, quit")
    
    while True:
        command = input("\nدستور: ").strip().lower()
        
        if command == 'quit':
            break
        elif command == 'display':
            engine.display_board()
        elif command.startswith('move'):
            try:
                # فرمت: move a2 a4
                parts = command.split()
                from_square = parts[1]
                to_square = parts[2]
                
                # تبدیل به مختصات
                from_pos = (8 - int(from_square[1]), ord(from_square[0]) - ord('a'))
                to_pos = (8 - int(to_square[1]), ord(to_square[0]) - ord('a'))
                
                valid, message = move_system.make_move(from_pos, to_pos)
                print(f"نتیجه: {message}")
                if valid:
                    engine.display_board()
                    
            except Exception as e:
                print(f"خطا در حرکت: {e}")
        else:
            print("دستور نامعتبر")

if __name__ == "__main__":
    main()
