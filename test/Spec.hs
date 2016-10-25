module Main where

import Test.Tasty
import Test.Tasty.HUnit

main :: IO ()
main = do
  defaultMain tests


tests :: TestTree
tests = testGroup "Tests"
  [ testCase "TODO" testExample ]

testExample :: Assertion
testExample = pure ()
