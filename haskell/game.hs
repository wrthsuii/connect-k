module ConnectK where

import Data.List (transpose, tails, isPrefixOf)
import Data.Maybe (isJust)

type Player = Int
type Board = [[Int]]
data Params = Params { nP :: Int, mP :: Int, kP :: Int }

-- Ініціалізація та хід
makeMove :: Board -> Int -> Player -> Board
makeMove board col player =
    let row = getDropRow board col
    in case row of
        Nothing -> board
        Just r  -> replace2D board r col player

getDropRow :: Board -> Int -> Maybe Int
getDropRow board col =
    let column = map (!! col) board
        emptyRows = [r | (r, val) <- zip [0..] column, val == 0]
    in if null emptyRows then Nothing else Just (last emptyRows)

replace2D :: Board -> Int -> Int -> Int -> Board
replace2D b r c val =
    let (before, targetRow:after) = splitAt r b
        newRow = take c targetRow ++ [val] ++ drop (c + 1) targetRow
    in before ++ [newRow] ++ after

-- Перевірка перемоги
isWin :: Params -> Board -> Player -> Bool
isWin p b player = any (hasK (kP p) player) (allLines b)
  where
    hasK k ply line = any (replicate k ply `isPrefixOf`) (tails line)
    allLines bd = bd ++ transpose bd ++ diags bd ++ diags (map reverse bd)
    diags bd = transpose [replicate i 0 ++ r | (i, r) <- zip [0..] bd]

-- Евристична оцінка
evaluate :: Params -> Board -> Int
evaluate p b = sum $ map scoreWindow (allWindows (kP p) b)
  where
    allWindows k bd = concatMap (getWindows k) (allLines bd)
    
    getWindows k line
        | length line < k = []
        | otherwise = take k line : getWindows k (tail line)
        
    allLines bd = bd ++ transpose bd ++ diags bd ++ diags (map reverse bd)
    diags bd = transpose [replicate i (-1) ++ r | (i, r) <- zip [0..] bd] 
    
    scoreWindow win
        | (-1) `elem` win = 0 
        | 1 `elem` win && 2 `elem` win = 0 
        | otherwise = (length (filter (==1) win))^2 - (length (filter (==2) win))^2

-- Alpha-Beta MinMax
alphaBeta :: Params -> Board -> Int -> Int -> Int -> Player -> (Int, Maybe Int)
alphaBeta p b depth alpha beta player
    | depth == 0 = (evaluate p b, Nothing)
    | null moves = (0, Nothing)
    | player == 1 = maximize moves alpha beta (-2000000) Nothing
    | otherwise   = minimize moves alpha beta 2000000 Nothing
  where
    moves = [c | c <- [0..(mP p - 1)], isJust (getDropRow b c)]

    maximize [] _ _ bestV bestM = (bestV, bestM)
    maximize (m:ms) a b bestV bestM =
        let nextB = makeMove b m 1
            score = if isWin p nextB 1 then 1000000 + depth 
                    else fst $ alphaBeta p nextB (depth - 1) a b 2
            (nV, nM) = if score > bestV then (score, Just m) else (bestV, bestM)
            nA = max a nV
        in if b <= nA then (nV, nM) else maximize ms nA b nV nM

    minimize [] _ _ bestV bestM = (bestV, bestM)
    minimize (m:ms) a b bestV bestM =
        let nextB = makeMove b m 2
            score = if isWin p nextB 2 then -1000000 - depth 
                    else fst $ alphaBeta p nextB (depth - 1) a b 1
            (nV, nM) = if score < bestV then (score, Just m) else (bestV, bestM)
            nB = min b nV
        in if nB <= a then (nV, nM) else minimize ms a nB nV nM