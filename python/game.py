import copy

class ConnectK:
    def __init__(self, n, m, k, forbidden=None):
        self.n = n
        self.m = m
        self.k = k
        # 0: порожньо, 1: гравець 1, 2: гравець 2, -1: заборонено
        self.board = [[0 for _ in range(m)] for _ in range(n)]
        if forbidden:
            for r, c in forbidden:
                if 0 <= r < n and 0 <= c < m:
                    self.board[r][c] = -1

    def get_valid_moves(self):
        """Повертає список стовпців, де верхня клітинка вільна."""
        return [c for c in range(self.m) if self.board[0][c] == 0]

    def get_drop_row(self, col):
        """Ефект падіння: знаходимо найнижчий вільний рядок."""
        for r in range(self.n - 1, -1, -1):
            if self.board[r][col] == 0:
                return r
        return None

    def make_move(self, col, player):
        row = self.get_drop_row(col)
        if row is not None:
            self.board[row][col] = player
            return row
        return None

    def check_win(self, r, c, p):
        """Повна перевірка перемоги у 4-х напрямках."""
        directions = [(0, 1), (1, 0), (1, 1), (1, -1)]
        for dr, dc in directions:
            count = 1
            for direction in [1, -1]:
                nr, nc = r + dr * direction, c + dc * direction
                while 0 <= nr < self.n and 0 <= nc < self.m and self.board[nr][nc] == p:
                    count += 1
                    nr += dr * direction
                    nc += dc * direction
            if count >= self.k: return True
        return False

    def evaluate(self):
        """Просунута евристика: оцінка всіх ліній довжиною K."""
        score = 0
        for r in range(self.n):
            for c in range(self.m):
                score += self._count_window_score(r, c)
        return score

    def _count_window_score(self, r, c):
        total = 0
        for dr, dc in [(0, 1), (1, 0), (1, 1), (1, -1)]:
            window = []
            for i in range(self.k):
                nr, nc = r + dr * i, c + dc * i
                if 0 <= nr < self.n and 0 <= nc < self.m:
                    window.append(self.board[nr][nc])
                else:
                    break
            if len(window) == self.k:
                total += self._calculate_heuristic(window)
        return total

    def _calculate_heuristic(self, window):
        p1 = window.count(1)
        p2 = window.count(2)
        if p1 > 0 and p2 > 0: return 0 
        if p1 > 0: return 10 ** (p1 - 1)
        if p2 > 0: return -(10 ** (p2 - 1))
        return 0

def alpha_beta(game, depth, alpha, beta, player):
    valid_moves = game.get_valid_moves()
    if depth == 0 or not valid_moves:
        return game.evaluate(), None

    best_move = valid_moves[0]
    if player == 1: 
        max_eval = -float('inf')
        for move in valid_moves:
            temp_game = copy.deepcopy(game)
            r = temp_game.make_move(move, 1)
            if temp_game.check_win(r, move, 1):
                eval = 1000000 + depth
            else:
                eval, _ = alpha_beta(temp_game, depth - 1, alpha, beta, 2)
            if eval > max_eval:
                max_eval, best_move = eval, move
            alpha = max(alpha, eval)
            if beta <= alpha: break
        return max_eval, best_move
    else: 
        min_eval = float('inf')
        for move in valid_moves:
            temp_game = copy.deepcopy(game)
            r = temp_game.make_move(move, 2)
            if temp_game.check_win(r, move, 2):
                eval = -1000000 - depth
            else:
                eval, _ = alpha_beta(temp_game, depth - 1, alpha, beta, 1)
            if eval < min_eval:
                min_eval, best_move = eval, move
            beta = min(beta, eval)
            if beta <= alpha: break
        return min_eval, best_move