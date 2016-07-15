module Language.Hakaru.CodeGen.HOAS.Statement
  ( ifS
  , guardS
  , gotoS
  , exitS
  , printS
  , labelS
  , whileS
  , doWhileS
  ) where

import Language.C.Syntax.AST
import Language.C.Data.Node
import Language.C.Data.Ident

import Language.Hakaru.CodeGen.HOAS.Expression

node :: NodeInfo
node = undefNode

ifS :: CExpr -> CStat -> CStat -> CStat
ifS e thn els = CIf e thn (Just els) node

guardS :: CExpr -> CStat -> CStat
guardS e thn = CIf e thn Nothing node

gotoS :: Ident -> CStat
gotoS i = CGoto i node

exitS :: CStat
exitS = CReturn (Just $ intConstE 0) node

printS :: String -> CStat
printS s = CExpr (Just $ printE s) node

labelS :: Ident -> CStat
labelS i = CLabel i (CCont node) [] node

whileS :: CExpr -> [CStat] -> CStat
whileS b stmts = CWhile b (CCompound [] (fmap CBlockStmt stmts) node) False node

doWhileS :: CExpr -> [CStat] -> CStat
doWhileS b stmts = CWhile b (CCompound [] (fmap CBlockStmt stmts) node) True node
