{-# LANGUAGE TypeFamilies, GeneralizedNewtypeDeriving #-}
module Javascript.YieldTrampoline (YieldTrampoline) where

import Javascript.Language as Js
import Data.Monoid
import qualified RTS.Objects as RTS

newtype YieldTrampoline js = YTC js
  deriving ( Monoid
           , JavascriptCallable
           , JavascriptNativeCall
           , JavascriptExpression
           , JavascriptStatement
           , Javascript
           )

instance Show js => Show (YieldTrampoline js)
  where show (YTC js) = show js

trampoline :: Javascript js => Expression js
trampoline = var "$yt"

instance JavascriptBase js => JavascriptBase (YieldTrampoline js)
  where newtype Expression (YieldTrampoline js) = YTCE { runYTCE :: Expression js }

instance Javascript js => JavascriptReturnResult (YieldTrampoline js)
  where return (YTCE res) = YTC $ expression $ yield $ new (property trampoline "Result") [res]

instance Javascript js => JavascriptJump (YieldTrampoline js)
  where jumpToApplyMethod (YTCE obj) args =
          YTC $ expression $ yield $ new (property trampoline "Jump") [property obj RTS.applyMethodName, obj, runYTCE . list $ args]

        jumpToMethod (YTCE obj) method args =
          YTC $ expression $ yield $ new (property trampoline "Jump") [property obj method, obj, runYTCE . list $ args]

        jumpToFunction (YTCE func) args =
          YTC $ expression $ yield $ new (property trampoline "Jump") [func, Js.null, runYTCE . list $ args]

        maybeJumpToApplyMethod (YTCE obj) =
          YTC $ Js.ifelse (RTS.isNotEvaluatedAndNotPrimitive obj)
                (expression $ yield $ new (property trampoline "Jump") [property obj RTS.applyMethodName, obj])
                (Js.return obj)

instance Javascript js => JavascriptCall (YieldTrampoline js)
  where assignMethodCallResult v (YTCE obj) method args rest = mconcat
          [ YTC $ assign (Js.var v) $ yield $ nativeMethodCall obj method (map runYTCE args)
          , rest
          ]

        declareApplyMethodCallResult var (YTCE obj) args rest = mconcat
          [ YTC $ declare var $ yield $ nativeMethodCall obj RTS.applyMethodName (map runYTCE args)
          , rest
          ]

        declareMethodCallResult var (YTCE obj) method args rest = mconcat
          [ YTC $ declare var $ yield $ nativeMethodCall obj method (map runYTCE args)
          , rest
          ]

        callMethod (YTCE obj) method args rest = mconcat
          [ YTC $ expression $ yield $ nativeMethodCall obj method (map runYTCE args)
          , rest
          ]

        assignFunctionCallResult v (YTCE func) args rest = mconcat
          [ YTC $ assign (Js.var v) $ yield $ nativeFunctionCall func (map runYTCE args)
          , rest
          ]

        declareFunctionCallResult var (YTCE func) args rest = mconcat
          [ YTC $ declare var $ yield $ nativeFunctionCall func (map runYTCE args)
          , rest
          ]

        callFunction (YTCE func) args rest = mconcat
          [ YTC $ expression $ yield $ nativeFunctionCall func (map runYTCE args)
          , rest
          ]

        maybeAssignApplyMethodCallResult v (YTCE obj) (YTC rest) = YTC $ mconcat
          [ Js.declare v obj
          , Js.if_ (RTS.isNotEvaluatedAndNotPrimitive obj) $
              assign (Js.var v) $ yield $ nativeMethodCall obj RTS.applyMethodName []
          , rest
          ]

