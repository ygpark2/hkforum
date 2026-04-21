{-# LANGUAGE OverloadedStrings #-}
module Handler.Root (getRootR, getFaviconR, getRobotsR) where

import Import

getRootR :: Handler Html
getRootR = notFound

getFaviconR :: Handler TypedContent
getFaviconR = sendFile "image/x-icon" "config/favicon.ico"

getRobotsR :: Handler TypedContent
getRobotsR = sendFile "text/plain; charset=utf-8" "config/robots.txt"
