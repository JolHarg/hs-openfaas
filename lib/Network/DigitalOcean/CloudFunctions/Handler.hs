{-# LANGUAGE OverloadedLists     #-}
{-# LANGUAGE OverloadedStrings   #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Network.DigitalOcean.CloudFunctions.Handler where

import Control.Monad.IO.Class
import Data.Aeson
import Data.ByteString.Lazy.Char8                   qualified as BSL
import Data.Text                                    qualified as T
import Network.DigitalOcean.CloudFunctions.Response

handle ∷ forall from to m. (FromJSON from, ToJSON to, MonadIO m) ⇒ (from → m to) → m ()
handle f = do
    input <- liftIO BSL.getContents

    let mInputDecoded = eitherDecode input :: Either String from

    case mInputDecoded of
        Left error' -> liftIO . BSL.putStrLn . encode $ Response {
            body = Object [
                "message" .= String "Decode error caught",
                "error" .= String (T.pack error')
            ],
            statusCode = 400,
            headers = [
                ("Content-Type", "application/json")
                ]
        }
        Right inputDecoded -> do
            output <- f inputDecoded :: m to

            liftIO . BSL.putStrLn . encode $ output
