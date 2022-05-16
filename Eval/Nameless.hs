{-# OPTIONS_GHC -Wall #-}
module Eval.Nameless where

import           Syntax.Nameless.Abs

isValue :: Expr -> Bool
isValue expr =
  case expr of
    ConstTrue     -> True
    ConstFalse    -> True
    Abstraction _ -> True
    _             -> isNatValue expr

isNatValue :: Expr -> Bool
isNatValue expr =
  case expr of
    ConstInteger _ -> True
    Succ v    -> isNatValue v
    _         -> False

evalStep :: Expr -> Maybe Expr
evalStep expr =
  case expr of
    If ConstTrue  t2 _t3 -> Just t2
    If ConstFalse _t2 t3 -> Just t3
    If t1 t2 t3 ->
      case evalStep t1 of
        Nothing  -> Nothing
        Just t1' -> Just (If t1' t2 t3)

    Succ t ->
      case evalStep t of
        Nothing -> Nothing
        Just t' -> Just (Succ t')

    Pred (ConstInteger 0) -> Just (ConstInteger 0)
    Pred (Succ t)  -> Just t
    Pred t ->
      case evalStep t of
        Nothing -> Nothing
        Just t' -> Just (Pred t')

    IsZero (ConstInteger 0) -> Just ConstTrue
    IsZero (Succ _)  -> Just ConstFalse
    IsZero t ->
      case evalStep t of
        Nothing -> Nothing
        Just t' -> Just (IsZero t')

    Application (Abstraction body) arg ->
      Just (substitute (0, arg.head) body)
    Application (LazyAbstraction body) arg ->
      Just (substitute (0, arg) body)
    Application t1 t2 ->
      case evalStep t1 of
        Nothing  -> Nothing
        Just t1' -> Just (Application t1' t2)

    Abstraction _ -> Nothing
    ConstTrue -> Nothing
    ConstFalse -> Nothing
    ConstInteger _ -> Nothing
    FreeVar _ -> Nothing
    BoundVar _ -> Nothing

shiftFrom :: Integer -> Expr -> Expr
shiftFrom k = go
  where
    go expr =
      case expr of
        BoundVar n
          | n >= k    -> BoundVar (n + 1)
          | otherwise -> expr
        FreeVar _ -> expr
        Abstraction body -> Abstraction (shiftFrom (k + 1) body)
        LazyAbstraction body -> LazyAbstraction (shiftFrom (k + 1) body)
      
        Application t1 t2 -> Application (go t1) (map go t2)
        Assignment t1 t2 -> Assignment (go t1) (go t2)
        ConstTrue -> ConstTrue
        ConstFalse -> ConstFalse
        If t1 t2 t3 -> If (go t1) (go t2) (go t3)

        ConstInteger x -> ConstInteger x
        Succ t -> Succ (go t)
        Pred t -> Pred (go t)
        Print t1 t2 -> Print (go t1) (go t2)
        IsZero t -> IsZero (go t)

shift :: Expr -> Expr
shift = shiftFrom 0

substitute :: (Integer, Expr) -> Expr -> Expr
substitute (n, s) = go
  where
    go expr =
      case expr of
        BoundVar m
          | n == m -> s
          | otherwise -> expr
        FreeVar _ -> expr
        Abstraction body -> Abstraction (substitute (n + 1, shift s) body)
        Application t1 t2 -> Application (go t1) (map go t2)
        Assignment t1 t2 -> Assignment (substitute (n + 1, shift s) t1) (go t2)
        LazyAbstraction body -> LazyAbstraction (substitute (n + 1, shift s) body)

        ConstTrue -> ConstTrue
        ConstFalse -> ConstFalse
        If t1 t2 t3 -> If (go t1) (go t2) (go t3)

        ConstInteger x -> ConstInteger x
        Succ t -> Succ (go t)
        Pred t -> Pred (go t)
        IsZero t -> IsZero (go t)
        Print t1 t2 -> Print (go t1) (go t2)

