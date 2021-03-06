module Web.SimpleServer (
      simpleServe
    , echo
    , HTTPRequest(..)
    , HTTPResponse(..)
) where

import Web.SimpleServer.HTTPRequest (HTTPRequest, getHttpRequest)
import Web.SimpleServer.HTTPResponse

import Control.Concurrent (forkIO)
import Control.Monad (forever)
import Network.Socket
import System.IO

type HTTPHandler = HTTPRequest -> IO HTTPResponse

route :: (Socket, SockAddr) -> HTTPHandler -> IO ()
route (sock, _) handler = do
    connHdl <- socketToHandle sock ReadWriteMode
    hSetBuffering connHdl NoBuffering
    recvd <- hGetContents connHdl
    response <- case getHttpRequest recvd of
            (Right req) -> handler req
            (Left error) -> return . badRequest . show $ error
    hPutStrLn connHdl (format response)

    hClose connHdl

serveOn :: Socket -> HTTPHandler -> IO ()
serveOn sock handler = forever $ do
    conn <- accept sock
    forkIO (route conn handler)  -- handle in a new thread

simpleServe :: PortNumber -> HTTPHandler -> IO ()
simpleServe port handler = do
    sock <- socket AF_INET Stream 0            -- create socket
    setSocketOption sock ReuseAddr 1           -- make socket immediately reusable - eases debugging.
    bind sock (SockAddrInet port iNADDR_ANY)   -- listen on supplied TCP port.
    listen sock 2                              -- set a max of 2 queued connections
    serveOn sock handler

echo :: HTTPHandler
echo = return . okMessage . show
