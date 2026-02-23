:- use_module(library(apply)).
:- use_module(library(random)).
:- use_module(library(lists)).

% ==============================================================================
% Предикат: eval_between
% Опис: Обчислює арифметичні вирази для меж і перевіряє/генерує число між ними.
% Використані вбудовані предикати: between/3 (генерація чисел в діапазоні).
%
% Індикатори та мультипризначенність:
% 1. eval_between(++, ++, -)
%    Генерація значень Val у межах обчислених LowExpr та HighExpr.
% 2. eval_between(++, ++, +)
%    Перевірка, чи належить конкретне значення Val обчисленому діапазону.
% Інші комбінації (наприклад, коли межі - або --) неможливі, оскільки
% арифметичні оператори вимагають конкретизованих аргументів.
% ==============================================================================
eval_between(LowExpr, HighExpr, Val) :-
    Low is LowExpr,
    High is HighExpr,
    between(Low, High, Val).

% ==============================================================================
% Предикат: generate_forbidden
% Опис: Генерує випадковий список координат заборонених клітинок на дошці.
% Використані вбудовані предикати: findall/3 (збір усіх рішень у список), 
% random_permutation/2 (випадкове перемішування списку).
%
% Індикатори та мультипризначенність:
% 1. generate_forbidden(++, ++, ++, --)
%    Основне призначення: генерує список заборонених клітинок довжиною Count.
% Інші комбінації (наприклад, перевірка з ++) не мають практичного змісту
% через випадковість результату, а неповна конкретизація N та M призведе 
% до помилки у findall та eval_between.
% ==============================================================================
generate_forbidden(N, M, Count, Forbidden) :-
    TotalCells is N * M,
    Count =< TotalCells,
    findall(
        (R, C), 
        (eval_between(0, N-1, R), eval_between(0, M-1, C)), 
        AllCells
    ),
    random_permutation(AllCells, Shuffled),
    length(Prefix, Count),
    append(Prefix, _, Shuffled),
    Forbidden = Prefix.

% ==============================================================================
% Предикат: new_game_with_forbidden
% Опис: Ініціалізує нову гру із заздалегідь заданим списком заборонених клітинок.
%
% Індикатори та мультипризначенність:
% 1. new_game_with_forbidden(++, ++, ++, ++, --, --, --)
%    Основне: створює початковий стан (Board), гравця (Player) та параметри.
% Інші комбінації не мають змісту, оскільки мета предикату — ініціалізувати 
% нову гру (створити вихідні змінні).
% ==============================================================================
new_game_with_forbidden(N, M, K, Forbidden, Board, Player, Params) :-
    empty_board(N, M, EmptyBoard),
    mark_forbidden(EmptyBoard, Forbidden, Board),
    Player = 1,
    Params = params(N, M, K).

% ==============================================================================
% Предикат: empty_board
% Опис: Створює двовимірний список (дошку) заданого розміру N x M, заповнену 0.
% Використані вбудовані предикати: length/2 (створення списку заданої довжини),
% maplist/2 (застосування умови до всіх елементів списку).
%
% Індикатори та мультипризначенність:
% 1. empty_board(++, ++, --)
%    Генерація порожньої дошки.
% 2. empty_board(++, ++, +)
%    Перевірка, чи є задана дошка порожньою.
% Комбінації з невідомими розмірами (-) призведуть до помилки у length/2.
% ==============================================================================
empty_board(N, M, Board) :-
    length(Row, M),
    maplist(=(0), Row),
    length(Board, N),
    maplist(=(Row), Board).

% ==============================================================================
% Предикат: mark_forbidden
% Опис: Позначає на дошці клітинки зі списку Forbidden значенням -1.
%
% Індикатори та мультипризначенність:
% 1. mark_forbidden(+, ++, --)
%    Модифікація дошки з розставленням заборонених клітинок.
% Інші комбінації не використовуються, оскільки предикат діє як функція
% зміни стану і вимагає вхідної дошки та списку.
% ==============================================================================
mark_forbidden(Board, Forbidden, NewBoard) :-
    replace_elements(Board, Forbidden, -1, NewBoard).

% ==============================================================================
% Предикат: replace_elements
% Опис: Рекурсивно замінює елементи дошки за заданим списком координат.
% Використані вбудовані предикати: nth0/3 (доступ до елемента за індексом).
%
% Індикатори та мультипризначенність:
% 1. replace_elements(+, ++, ++, --)
%    Генерація нової дошки із заміненими елементами.
% Використання для перевірки (+) теоретично можливе, але не має змісту
% в рамках логіки гри.
% ==============================================================================
replace_elements(Board, [], _, Board).
replace_elements(Board, [(R, C) | Rest], Val, NewBoard) :-
    nth0(R, Board, Row),
    replace(Row, C, Val, NewRow),
    replace_row(Board, R, NewRow, TempBoard),
    replace_elements(TempBoard, Rest, Val, NewBoard).

% ==============================================================================
% Предикати: replace_row та replace
% Опис: Замінює рядок у двовимірному списку (або елемент у рядку).
%
% Індикатори та мультипризначенність:
% 1. replace_row(+, ++, +, --) / replace(+, ++, ++, --)
%    Генерація нового списку із заміненим елементом за індексом.
% Всі інші комбінації недоцільні для функціонального стилю заміни.
% ==============================================================================
replace_row([_ | T], 0, NewRow, [NewRow | T]).
replace_row([H | T], R, NewRow, [H | Rest]) :-
    R > 0,
    R1 is R - 1,
    replace_row(T, R1, NewRow, Rest).

replace(List, Index, Value, NewList) :-
    nth0(Index, List, _, Rest),
    nth0(Index, NewList, Value, Rest).

% ==============================================================================
% Предикат: new_game
% Опис: Ініціалізує нову гру, генеруючи випадкові заборонені клітинки.
%
% Індикатори та мультипризначенність:
% 1. new_game(++, ++, ++, ++, --, --, --)
%    Створює початковий ігровий стан.
% Інші комбінації беззмістовні.
% ==============================================================================
new_game(N, M, K, ForbiddenCount, Board, Player, Params) :-
    generate_forbidden(N, M, ForbiddenCount, Forbidden),
    empty_board(N, M, EmptyBoard),
    mark_forbidden(EmptyBoard, Forbidden, Board),
    Player = 1,
    Params = params(N, M, K).

% ==============================================================================
% Предикат: valid_move
% Опис: Перевіряє, чи припустимий хід у стовпець Col, і повертає нову дошку.
%
% Індикатори та мультипризначенність:
% 1. valid_move(+, ++, +, +, --, --)
%    Перевірка ходу та застосування його результатів (Нова дошка і Рядок).
% 2. valid_move(+, -, +, +, --, --)
%    Генерація усіх можливих ходів (повернення стовпця Col і нової дошки).
% Всі інші варіанти не мають змісту.
% ==============================================================================
valid_move(Board, Col, Player, Params, NewBoard, Row) :-
    Params = params(N, M, _),
    integer(Col), Col >= 0, Col < M,
    drop_row(Board, Col, N, Row),
    make_move(Board, Col, Row, Player, NewBoard).

% ==============================================================================
% Предикати: drop_row та drop_row_from
% Опис: Шукає перший вільний рядок (значення 0) у заданому стовпці (падіння).
%
% Індикатори та мультипризначенність:
% 1. drop_row(+, ++, ++, -)
%    Знаходить координату Row, куди впаде фішка.
% Інші комбінації використовувати недоцільно.
% ==============================================================================
drop_row(Board, Col, N, Row) :-
    LastRow is N - 1,
    drop_row_from(Board, LastRow, Col, Row).

drop_row_from(Board, R, Col, R) :-
    R >= 0,
    nth0(R, Board, RowCells),
    nth0(Col, RowCells, Cell),
    Cell == 0,
    !.
drop_row_from(Board, R, Col, Row) :-
    R >= 0,
    R1 is R - 1,
    drop_row_from(Board, R1, Col, Row).

% ==============================================================================
% Предикат: make_move
% Опис: Застосовує хід, розміщуючи фішку гравця на обчисленій позиції.
%
% Індикатори: make_move(+, ++, ++, ++, --)
% ==============================================================================
make_move(Board, Col, Row, Player, NewBoard) :-
    nth0(Row, Board, OldRow),
    replace(OldRow, Col, Player, NewRow),
    replace_row(Board, Row, NewRow, NewBoard).

% ==============================================================================
% Предикат: check_win
% Опис: Перевіряє, чи виграв гравець після останнього ходу у чотирьох напрямках.
%
% Індикатори та мультипризначенність:
% 1. check_win(+, ++, ++, ++, +)
%    Тільки перевірка факту перемоги (працює як логічне "так/ні").
% Не має вихідних параметрів.
% ==============================================================================
check_win(Board, Row, Col, Player, Params) :-
    Params = params(_, _, K),
    (   check_direction(Board, Row, Col, Player, 1, 0, K)
    ;   check_direction(Board, Row, Col, Player, 0, 1, K)
    ;   check_direction(Board, Row, Col, Player, 1, 1, K)
    ;   check_direction(Board, Row, Col, Player, 1, -1, K)
    ).

% ==============================================================================
% Предикати: check_direction та count_consecutive
% Опис: Підраховує кількість фішок гравця поспіль у вказаному напрямку (DRow, DCol).
%
% Індикатори: check_direction(+, ++, ++, ++, ++, ++, ++)
%             count_consecutive(+, ++, ++, ++, ++, ++, -)
% ==============================================================================
check_direction(Board, Row, Col, Player, DRow, DCol, K) :-
    count_consecutive(Board, Row, Col, Player, DRow, DCol, Count1),
    count_consecutive(Board, Row, Col, Player, -DRow, -DCol, Count2),
    Total is Count1 + Count2 - 1,
    Total >= K.

count_consecutive(_, Row, Col, _, _, _, 0) :-
    (Row < 0 ; Col < 0), !.
count_consecutive(Board, Row, Col, Player, DRow, DCol, Count) :-
    (   nth0(Row, Board, RowCells),
        nth0(Col, RowCells, Player) ->
        NextRow is Row + DRow,
        NextCol is Col + DCol,
        count_consecutive(Board, NextRow, NextCol, Player, DRow, DCol, SubCount),
        Count is SubCount + 1
    ;   Count = 0
    ).

% ==============================================================================
% Предикат: check_draw
% Опис: Перевіряє наявність нічиєї (відсутність вільних клітинок 0 на дошці).
% Використані вбудовані предикати: member/2 (перевірка елемента у списку).
%
% Індикатори: check_draw(+, +)
% Тільки логічна перевірка факту.
% ==============================================================================
check_draw(Board, _Params) :-
    \+ (member(Row, Board), member(0, Row)).

% ==============================================================================
% Предикат: alpha_beta
% Опис: Точка входу до алгоритму Мінімакс із альфа-бета відсіченням.
%
% Індикатори та мультипризначенність:
% 1. alpha_beta(+, ++, +, ++, -, -)
%    Отримання найкращого ходу (BestMove) та його оцінки (Score).
% Інші комбінації не застосовуються, предикат є детермінованим генератором.
% ==============================================================================
alpha_beta(Board, Player, Params, Depth, BestMove, Score) :-
    Params = params(N, M, K),
    (   Depth =< 0 ->
        evaluate(Board, N, M, K, Score),
        BestMove = none
    ;   findall(
            Col, 
            (eval_between(0, M-1, Col), drop_row(Board, Col, N, _)), 
            Moves
        ),
        (   Moves == [] ->
            Score = 0,
            BestMove = none
        ;   (   Player == 1 ->
                alpha_beta_max(Board, Player, Params, Depth, -1000001, 1000001, Moves, BestMove, Score)
            ;   alpha_beta_min(Board, Player, Params, Depth, -1000001, 1000001, Moves, BestMove, Score)
            )
        )
    ).

% ==============================================================================
% Предикати: alpha_beta_max, alpha_beta_min, select_move_max, select_move_min
% Опис: Рекурсивний обхід дерева рішень з оновленням меж альфа та бета.
%       При неминучій поразці предикат віддає перший хід (FirstMove).
%
% Індикатори: alpha_beta_max(+, ++, +, ++, ++, ++, +, -, -)
% ==============================================================================
alpha_beta_max(Board, Player, Params, Depth, Alpha, Beta, [FirstMove | Rest], BestMove, BestScore) :-
    select_move_max(
        [FirstMove | Rest], Board, Player, Params, Depth, 
        Alpha, Beta, FirstMove, -1000001, BestMove, BestScore
    ).

select_move_max([], _, _, _, _, _, _, BestMove, BestScore, BestMove, BestScore).
select_move_max([Col | Rest], Board, Player, Params, Depth, Alpha, Beta, BestMoveSoFar, BestScoreSoFar, BestMove, BestScore) :-
    valid_move(Board, Col, Player, Params, NewBoard, Row),
    (   check_win(NewBoard, Row, Col, Player, Params) ->
        NextGameOver = true,
        NextWinner = Player
    ;   check_draw(NewBoard, Params) ->
        NextGameOver = true,
        NextWinner = 0
    ;   NextGameOver = false,
        NextWinner = 0
    ),
    NextPlayer is 3 - Player,
    NextDepth is Depth - 1,
    (   NextGameOver == true ->
        (   NextWinner == 1 -> Score = 1000000
        ;   NextWinner == 2 -> Score = -1000000
        ;   Score = 0
        ),
        NewBestScore = Score,
        NewBestMove = Col,
        NewAlpha is max(Alpha, Score)
    ;   alpha_beta(NewBoard, NextPlayer, Params, NextDepth, _, Score),
        (   Score > BestScoreSoFar ->
            NewBestScore = Score,
            NewBestMove = Col,
            NewAlpha is max(Alpha, Score)
        ;   NewBestScore = BestScoreSoFar,
            NewBestMove = BestMoveSoFar,
            NewAlpha = Alpha
        )
    ),
    (   NewAlpha >= Beta ->
        BestMove = NewBestMove,
        BestScore = NewBestScore
    ;   select_move_max(Rest, Board, Player, Params, Depth, NewAlpha, Beta, NewBestMove, NewBestScore, BestMove, BestScore)
    ).

alpha_beta_min(Board, Player, Params, Depth, Alpha, Beta, [FirstMove | Rest], BestMove, BestScore) :-
    select_move_min(
        [FirstMove | Rest], Board, Player, Params, Depth, 
        Alpha, Beta, FirstMove, 1000001, BestMove, BestScore
    ).

select_move_min([], _, _, _, _, _, _, BestMove, BestScore, BestMove, BestScore).
select_move_min([Col | Rest], Board, Player, Params, Depth, Alpha, Beta, BestMoveSoFar, BestScoreSoFar, BestMove, BestScore) :-
    valid_move(Board, Col, Player, Params, NewBoard, Row),
    (   check_win(NewBoard, Row, Col, Player, Params) ->
        NextGameOver = true,
        NextWinner = Player
    ;   check_draw(NewBoard, Params) ->
        NextGameOver = true,
        NextWinner = 0
    ;   NextGameOver = false,
        NextWinner = 0
    ),
    NextPlayer is 3 - Player,
    NextDepth is Depth - 1,
    (   NextGameOver == true ->
        (   NextWinner == 1 -> Score = 1000000
        ;   NextWinner == 2 -> Score = -1000000
        ;   Score = 0
        ),
        NewBestScore = Score,
        NewBestMove = Col,
        NewBeta is min(Beta, Score)
    ;   alpha_beta(NewBoard, NextPlayer, Params, NextDepth, _, Score),
        (   Score < BestScoreSoFar ->
            NewBestScore = Score,
            NewBestMove = Col,
            NewBeta is min(Beta, Score)
        ;   NewBestScore = BestScoreSoFar,
            NewBestMove = BestMoveSoFar,
            NewBeta = Beta
        )
    ),
    (   Alpha >= NewBeta ->
        BestMove = NewBestMove,
        BestScore = NewBestScore
    ;   select_move_min(Rest, Board, Player, Params, Depth, Alpha, NewBeta, NewBestMove, NewBestScore, BestMove, BestScore)
    ).

% ==============================================================================
% Предикат: evaluate та window_score
% Опис: Евристична функція. Розраховує статичну оцінку дошки (Score) для 
%       штучного інтелекту, розбиваючи дошку на "вікна" довжиною K.
% Використані вбудовані предикати: include/3 (відбір елементів списку за умовою).
%
% Індикатори: evaluate(+, ++, ++, ++, -)
%             window_score(+, ++, ++, ++, ++, ++, -)
% Тільки обчислення результату (-), зворотне визначення дошки (+) зі Score неможливе.
% ==============================================================================
evaluate(Board, N, M, K, Score) :-
    findall(Val, (
        eval_between(0, N-1, R),
        eval_between(0, M-K, C),
        window_score(Board, R, C, 0, 1, K, Val)
    ), HorizScores),
    findall(Val, (
        eval_between(0, N-K, R),
        eval_between(0, M-1, C),
        window_score(Board, R, C, 1, 0, K, Val)
    ), VertScores),
    findall(Val, (
        eval_between(0, N-K, R),
        eval_between(0, M-K, C),
        window_score(Board, R, C, 1, 1, K, Val)
    ), Diag1Scores),
    findall(Val, (
        eval_between(0, N-K, R),
        eval_between(K-1, M-1, C),
        window_score(Board, R, C, 1, -1, K, Val)
    ), Diag2Scores),
    append([HorizScores, VertScores, Diag1Scores, Diag2Scores], AllScores),
    my_sum_list(AllScores, Score).

window_score(Board, R, C, DRow, DCol, K, Score) :-
    findall(Cell, (
        eval_between(0, K-1, I),
        RowIdx is R + I*DRow,
        ColIdx is C + I*DCol,
        nth0(RowIdx, Board, RowCells),
        nth0(ColIdx, RowCells, Cell)
    ), Cells),
    include(==(1), Cells, P1),
    include(==(2), Cells, P2),
    length(P1, L1), length(P2, L2),
    (   L1 > 0, L2 > 0 -> Score = 0
    ;   L1 > 0 -> Score is L1 * L1
    ;   L2 > 0 -> Score is -L2 * L2
    ;   Score = 0
    ).

% ==============================================================================
% Предикат: my_sum_list
% Опис: Допоміжний предикат для сумування елементів списку чисел.
%
% Індикатори: my_sum_list(+, -)
% Працює лише для обчислення суми конкретизованого списку.
% ==============================================================================
my_sum_list([], 0).
my_sum_list([H | T], Sum) :- 
    my_sum_list(T, Rest), 
    Sum is H + Rest.