from flask import Flask, request, jsonify, send_from_directory
from pyswip import Prolog
import os

os.chdir(os.path.dirname(os.path.abspath(__file__)))

app = Flask(__name__, static_folder='web')

prolog = Prolog()
prolog.consult("game.pl")

current_game = {
    'board': None,
    'player': 1,
    'gameOver': False,
    'winner': 0,
    'params': None,
    'mode': 'human-human',
    'depth': 3
}

@app.route('/')
def index():
    return send_from_directory('web', 'index.html')

@app.route('/<path:path>')
def static_files(path):
    return send_from_directory('web', path)

@app.route('/api/new_game', methods=['POST'])
def new_game():
    global current_game
    data = request.get_json()
    
    n = int(data['n'])
    m = int(data['m'])
    k = int(data['k'])
    depth = int(data['depth'])
    mode = data['mode']
    
    if n < 5 or m < 6 or k < 3 or k > 5:
        return jsonify({'status': 'error', 'message': 'Parameters out of range: n>=5, m>=6, k∈[3,5]'}), 400

    if 'forbidden_list' in data:
        forbidden_list = data['forbidden_list'] 
        # Перетворюємо у список пар (кортежів) для коректного розуміння в Prolog
        forbidden_prolog = "[" + ",".join([f"({r},{c})" for r, c in forbidden_list]) + "]"
        query = f"new_game_with_forbidden({n}, {m}, {k}, {forbidden_prolog}, Board, Player, Params)"
    else:
        forbidden_count = int(data['forbidden_count'])
        query = f"new_game({n}, {m}, {k}, {forbidden_count}, Board, Player, Params)"
    
    try:
        result = list(prolog.query(query))
    except Exception as e:
        print(f"Prolog error: {e}")
        return jsonify({'status': 'error', 'message': 'Prolog execution failed'}), 500

    if not result:
        return jsonify({'status': 'error', 'message': 'Failed to create game (Prolog)'}), 400

    board = result[0]['Board']
    board_py = [list(row) for row in board]
    player = result[0]['Player']

    current_game = {
        'board': board_py,
        'player': player,
        'gameOver': False,
        'winner': 0,
        'params': f"params({n},{m},{k})",
        'mode': mode,
        'depth': depth
    }

    return jsonify({
        'status': 'ok',
        'board': board_py,
        'player': player,
        'gameOver': False,
        'winner': 0
    })

@app.route('/api/state', methods=['GET'])
def get_state():
    return jsonify({
        'board': current_game['board'],
        'player': current_game['player'],
        'gameOver': current_game['gameOver'],
        'winner': current_game['winner']
    })

@app.route('/api/move', methods=['POST'])
def make_move():
    global current_game
    data = request.get_json()
    col = int(data['col'])

    if current_game['gameOver']:
        return jsonify({'status': 'error', 'message': 'Game already over'}), 400

    board = current_game['board']
    player = current_game['player']
    params = current_game['params']

    query = f"valid_move({board}, {col}, {player}, {params}, NewBoard, Row)"
    result = list(prolog.query(query))
    if not result:
        return jsonify({'status': 'error', 'message': 'Invalid move'}), 400

    new_board = result[0]['NewBoard']
    new_board_py = [list(row) for row in new_board]
    row = result[0]['Row']

    win_query = f"check_win({new_board_py}, {row}, {col}, {player}, {params})"
    win = len(list(prolog.query(win_query))) > 0

    draw_query = f"check_draw({new_board_py}, {params})"
    draw = len(list(prolog.query(draw_query))) > 0

    if win:
        winner = player
        game_over = True
        next_player = player
    elif draw:
        winner = 0
        game_over = True
        next_player = player
    else:
        winner = 0
        game_over = False
        next_player = 3 - player

    current_game['board'] = new_board_py
    current_game['player'] = next_player
    current_game['gameOver'] = game_over
    current_game['winner'] = winner

    return jsonify({
        'status': 'ok',
        'board': new_board_py,
        'player': next_player,
        'gameOver': game_over,
        'winner': winner
    })

@app.route('/api/ai_move', methods=['POST'])
def ai_move():
    global current_game
    if current_game['gameOver']:
        return jsonify({'status': 'error', 'message': 'Game already over'}), 400

    board = current_game['board']
    player = current_game['player']
    params = current_game['params']
    depth = current_game['depth']

    query = f"alpha_beta({board}, {player}, {params}, {depth}, BestCol, _Score)"
    result = list(prolog.query(query))
    
    if not result or str(result[0]['BestCol']) == 'none':
        return jsonify({'status': 'error', 'message': 'No valid moves'}), 400

    best_col = result[0]['BestCol']

    move_query = f"valid_move({board}, {best_col}, {player}, {params}, NewBoard, Row)"
    move_result = list(prolog.query(move_query))
    if not move_result:
        return jsonify({'status': 'error', 'message': 'AI chose invalid move'}), 500

    new_board = move_result[0]['NewBoard']
    new_board_py = [list(row) for row in new_board]
    row = move_result[0]['Row']

    win_query = f"check_win({new_board_py}, {row}, {best_col}, {player}, {params})"
    win = len(list(prolog.query(win_query))) > 0

    draw_query = f"check_draw({new_board_py}, {params})"
    draw = len(list(prolog.query(draw_query))) > 0

    if win:
        winner = player
        game_over = True
        next_player = player
    elif draw:
        winner = 0
        game_over = True
        next_player = player
    else:
        winner = 0
        game_over = False
        next_player = 3 - player

    current_game['board'] = new_board_py
    current_game['player'] = next_player
    current_game['gameOver'] = game_over
    current_game['winner'] = winner

    return jsonify({
        'status': 'ok',
        'board': new_board_py,
        'player': next_player,
        'gameOver': game_over,
        'winner': winner,
        'move': best_col
    })

@app.route('/api/resign', methods=['POST'])
def resign():
    global current_game
    if current_game['gameOver']:
        return jsonify({'status': 'error', 'message': 'Game already over'}), 400

    current_game['gameOver'] = True
    current_game['winner'] = 3 - current_game['player']
    return jsonify({'status': 'ok', 'gameOver': True, 'winner': current_game['winner']})

@app.route('/api/quit', methods=['POST'])
def quit_game():
    global current_game
    current_game = {
        'board': None,
        'player': 1,
        'gameOver': False,
        'winner': 0,
        'params': None,
        'mode': 'human-human',
        'depth': 3
    }
    return jsonify({'status': 'ok'})

if __name__ == '__main__':
    app.run(debug=True, port=8001, threaded=False)