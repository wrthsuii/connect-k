let currentMode = 'human-human';
let gameOver = false;
let currentPlayer = 1;
let aiTimeout = null;
let winningCells = [];
let isProcessing = false;
let gameSessionId = 0; // <--- ДОДАНО для контролю сесій

// Режим ручного вибору перешкод
let manualModeActive = false;
let selectedForbidden = [];
let requiredForbiddenCount = 0;
let nVal = 6, mVal = 7;

document.addEventListener('DOMContentLoaded', () => {
    document.getElementById('newGame').addEventListener('click', newGame);
    document.getElementById('resign').addEventListener('click', resign);
    document.getElementById('endGame').addEventListener('click', endGame);
    document.getElementById('quitApp').addEventListener('click', quitApp);
    document.getElementById('aiMoveBtn').addEventListener('click', aiMove);
    document.getElementById('applyForbiddenBtn').addEventListener('click', applyForbiddenSelection);

    fetchState();
});

function newGame() {
    gameSessionId++; // <--- ДОДАНО: новий ID для нової гри
    if (aiTimeout) clearTimeout(aiTimeout);
    isProcessing = false;

    nVal = parseInt(document.getElementById('n').value);
    mVal = parseInt(document.getElementById('m').value);
    const k = parseInt(document.getElementById('k').value);
    const depth = parseInt(document.getElementById('depth').value);
    const forbidden = parseInt(document.getElementById('forbidden').value);
    const mode = document.getElementById('mode').value;
    const forbiddenMode = document.querySelector('input[name="forbiddenMode"]:checked').value;

    if (nVal < 5 || mVal < 6 || k < 3 || k > 5) {
        showError('Параметри: n>=5, m>=6, k∈[3,5]');
        return;
    }

    if (forbiddenMode === 'manual' && forbidden > 0) {
        manualModeActive = true;
        requiredForbiddenCount = forbidden;
        selectedForbidden = [];
        currentMode = mode;

        document.getElementById('status').innerHTML = '';
        document.getElementById('aiMoveBtn').style.display = 'none';
        document.getElementById('resign').disabled = true;
        document.getElementById('endGame').disabled = false;

        document.getElementById('setupInstructions').style.display = 'flex';
        updateSetupInstructions();

        let emptyBoard = Array(nVal).fill().map(() => Array(mVal).fill(0));
        renderSetupBoard(emptyBoard);
    } else {
        manualModeActive = false;
        currentMode = mode;
        winningCells = [];
        isProcessing = true;

        document.getElementById('setupInstructions').style.display = 'none';

        fetch('/api/new_game', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ n: nVal, m: mVal, k, mode, depth, forbidden_count: forbidden })
        })
            .then(res => res.json())
            .then(data => {
                isProcessing = false;
                if (data.status === 'ok') {
                    finishStartSetup(data);
                } else {
                    showError(data.message);
                }
            })
            .catch(() => {
                isProcessing = false;
                showError("Помилка з'єднання з сервером");
            });
    }
}

function renderSetupBoard(board) {
    const n = board.length;
    const m = board[0].length;
    let html = '<table class="setup-board">';
    for (let r = 0; r < n; r++) {
        html += '<tr>';
        for (let c = 0; c < m; c++) {
            let isSelected = selectedForbidden.some(cell => cell[0] === r && cell[1] === c);
            let cellClass = isSelected ? 'forbidden clickable' : 'empty clickable';
            html += `<td><div class="${cellClass}" onclick="toggleForbidden(${r}, ${c})"></div></td>`;
        }
        html += '</tr>';
    }
    html += '</table>';
    document.getElementById('board').innerHTML = html;
}

function toggleForbidden(r, c) {
    if (!manualModeActive) return;

    const idx = selectedForbidden.findIndex(cell => cell[0] === r && cell[1] === c);
    if (idx !== -1) {
        selectedForbidden.splice(idx, 1);
    } else {
        if (selectedForbidden.length < requiredForbiddenCount) {
            selectedForbidden.push([r, c]);
        } else {
            showError(`Вже вибрано максимум (${requiredForbiddenCount})`);
            return;
        }
    }

    updateSetupInstructions();
    let emptyBoard = Array(nVal).fill().map(() => Array(mVal).fill(0));
    renderSetupBoard(emptyBoard);
}

function updateSetupInstructions() {
    const rem = requiredForbiddenCount - selectedForbidden.length;
    document.getElementById('remForb').textContent = rem;
    document.getElementById('applyForbiddenBtn').disabled = (rem !== 0);
}

function applyForbiddenSelection() {
    const k = parseInt(document.getElementById('k').value);
    const depth = parseInt(document.getElementById('depth').value);

    isProcessing = true;
    fetch('/api/new_game', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ n: nVal, m: mVal, k, mode: currentMode, depth, forbidden_list: selectedForbidden })
    })
        .then(res => res.json())
        .then(data => {
            isProcessing = false;
            if (data.status === 'ok') {
                manualModeActive = false;
                document.getElementById('setupInstructions').style.display = 'none';
                finishStartSetup(data);
            } else {
                showError(data.message);
            }
        });
}

function finishStartSetup(data) {
    document.getElementById('resign').disabled = false;
    document.getElementById('endGame').disabled = false;
    currentPlayer = data.player;
    gameOver = data.gameOver;
    renderBoard(data.board);
    updateStatus(data.gameOver, data.winner);
    updateAIVisibility();
    if (!gameOver && currentMode === 'ai-ai') {
        aiMove();
    }
}

function renderBoard(board) {
    const n = board.length;
    const m = board[0].length;
    let html = '<table>';
    html += '<tr>';

    let buttonsDisabled = gameOver || currentMode === 'ai-ai' || (currentMode === 'human-ai' && currentPlayer === 2);

    for (let c = 0; c < m; c++) {
        html += `<td><button class="column-btn" onclick="makeMove(${c})" ${buttonsDisabled ? 'disabled' : ''}>${c + 1}</button></td>`;
    }
    html += '</tr>';
    for (let r = 0; r < n; r++) {
        html += '<tr>';
        for (let c = 0; c < m; c++) {
            let cellClass = '';
            const val = board[r][c];
            if (val === 0) cellClass = 'empty';
            else if (val === 1) cellClass = 'player1';
            else if (val === 2) cellClass = 'player2';
            else if (val === -1) cellClass = 'forbidden';

            if (winningCells.some(cell => cell[0] === r && cell[1] === c)) {
                cellClass += ' winner';
            }

            html += `<td><div class="${cellClass}"></div></td>`;
        }
        html += '</tr>';
    }
    html += '</table>';
    document.getElementById('board').innerHTML = html;
}

function makeMove(col) {
    if (gameOver || isProcessing) return;
    if (currentMode === 'human-ai' && currentPlayer === 2) {
        showError('Зараз черга AI');
        return;
    }

    isProcessing = true;
    let currentSession = gameSessionId; // <--- ЗАПАМ'ЯТОВУЄМО

    fetch('/api/move', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ col })
    })
        .then(res => res.json())
        .then(data => {
            if (currentSession !== gameSessionId) return; // <--- ІГНОРУЄМО, ЯКЩО ГРА ВЖЕ ІНША
            handleGameResponse(data);
        })
        .catch(() => {
            if (currentSession !== gameSessionId) return; // <--- ІГНОРУЄМО
            isProcessing = false;
            showError("Помилка з'єднання з сервером");
        });
}

function aiMove() {
    if (gameOver || isProcessing) return;

    isProcessing = true;
    let currentSession = gameSessionId; // <--- ЗАПАМ'ЯТОВУЄМО

    fetch('/api/ai_move', { method: 'POST' })
        .then(res => res.json())
        .then(data => {
            if (currentSession !== gameSessionId) return; // <--- ІГНОРУЄМО
            handleGameResponse(data);
            if (!gameOver && currentMode === 'ai-ai' && data.status === 'ok') {
                if (aiTimeout) clearTimeout(aiTimeout);
                aiTimeout = setTimeout(aiMove, 500);
            }
        })
        .catch(() => {
            if (currentSession !== gameSessionId) return; // <--- ІГНОРУЄМО
            isProcessing = false;
            showError("Помилка з'єднання з сервером");
        });
}

function handleGameResponse(data) {
    isProcessing = false;
    if (data.status === 'ok') {
        currentPlayer = data.player;
        gameOver = data.gameOver;

        if (data.gameOver && data.winner !== 0) {
            highlightWinningCells(data.board, data.winner);
        } else {
            renderBoard(data.board);
        }
        updateStatus(data.gameOver, data.winner);

        if (!gameOver && currentMode === 'human-ai' && currentPlayer === 2) {
            aiMove();
        }
    } else {
        showError(data.message);
    }
}

function highlightWinningCells(board, winner) {
    winningCells = [];
    const n = board.length;
    const m = board[0].length;
    const k = parseInt(document.getElementById('k').value);

    for (let r = 0; r < n; r++) {
        for (let c = 0; c <= m - k; c++) {
            let win = true;
            for (let i = 0; i < k; i++) if (board[r][c + i] !== winner) win = false;
            if (win) for (let i = 0; i < k; i++) winningCells.push([r, c + i]);
        }
    }
    for (let r = 0; r <= n - k; r++) {
        for (let c = 0; c < m; c++) {
            let win = true;
            for (let i = 0; i < k; i++) if (board[r + i][c] !== winner) win = false;
            if (win) for (let i = 0; i < k; i++) winningCells.push([r + i, c]);
        }
    }
    for (let r = 0; r <= n - k; r++) {
        for (let c = 0; c <= m - k; c++) {
            let win = true;
            for (let i = 0; i < k; i++) if (board[r + i][c + i] !== winner) win = false;
            if (win) for (let i = 0; i < k; i++) winningCells.push([r + i, c + i]);
        }
    }
    for (let r = 0; r <= n - k; r++) {
        for (let c = k - 1; c < m; c++) {
            let win = true;
            for (let i = 0; i < k; i++) if (board[r + i][c - i] !== winner) win = false;
            if (win) for (let i = 0; i < k; i++) winningCells.push([r + i, c - i]);
        }
    }
    renderBoard(board);
}

function resign() {
    gameSessionId++; // <--- ДОДАНО: ігноруємо можливі запізнілі відповіді AI
    isProcessing = true;
    fetch('/api/resign', { method: 'POST' })
        .then(res => res.json())
        .then(data => {
            isProcessing = false;
            if (data.status === 'ok') {
                gameOver = true;
                updateStatus(true, data.winner);
                fetchState();
            }
        });
}

function endGame() {
    gameSessionId++; // <--- ДОДАНО
    manualModeActive = false;
    document.getElementById('setupInstructions').style.display = 'none';
    isProcessing = true;

    fetch('/api/quit', { method: 'POST' })
        .then(() => {
            isProcessing = false;
            document.getElementById('board').innerHTML = '';
            document.getElementById('status').innerHTML = '';
            document.getElementById('status').classList.remove('game-over');
            document.getElementById('aiMoveBtn').style.display = 'none';
            document.getElementById('resign').disabled = true;
            document.getElementById('endGame').disabled = true;
            if (aiTimeout) clearTimeout(aiTimeout);
            winningCells = [];
            gameOver = true;
        });
}

function quitApp() {
    gameSessionId++; // <--- ДОДАНО
    fetch('/api/quit', { method: 'POST' });

    document.body.innerHTML = `
        <div class="quit-screen">
            <h1>Додаток закрито</h1>
            <p>Дякуємо за гру!</p>
        </div>
    `;
}

function updateStatus(gameOver, winner) {
    const statusEl = document.getElementById('status');
    if (gameOver) {
        statusEl.classList.add('game-over');
        if (winner === 1) statusEl.innerHTML = '🎉 Переможець: Гравець 🔴 кольору';
        else if (winner === 2) statusEl.innerHTML = '🎉 Переможець: Гравець 🟠 кольору';
        else statusEl.innerHTML = '🤝 Нічия';
    } else {
        statusEl.classList.remove('game-over');
        statusEl.innerHTML = `Хід гравця ${currentPlayer} (${currentPlayer === 1 ? '🔴 колір' : '🟠 колір'})`;
    }
}

function updateAIVisibility() {
    const aiBtn = document.getElementById('aiMoveBtn');
    if (aiBtn) {
        aiBtn.style.display = 'none';
    }
}

function showError(message) {
    const errorDiv = document.createElement('div');
    errorDiv.className = 'error-message';
    errorDiv.textContent = message;

    const boardEl = document.getElementById('board');
    if (boardEl && boardEl.parentNode) {
        boardEl.parentNode.insertBefore(errorDiv, boardEl);
    } else {
        document.body.appendChild(errorDiv);
    }

    setTimeout(() => errorDiv.remove(), 3000);
}

function fetchState() {
    fetch('/api/state')
        .then(res => res.json())
        .then(data => {
            if (data.board) {
                currentPlayer = data.player;
                gameOver = data.gameOver;
                renderBoard(data.board);
                updateStatus(data.gameOver, data.winner);
                updateAIVisibility();

                document.getElementById('resign').disabled = data.gameOver;
                document.getElementById('endGame').disabled = false;
            }
        });
}