module ReportCreator where

import           TokenCreator
import Text.PrettyPrint.Boxes
import Colonnade
import Data.List ( zipWith5, sortBy, zipWith6 )
import Data.List.Extra (nub)
import TokenToBlock
import Data.Tuple
import Data.Tuple.Extra (uncurry3)
import qualified Data.Maybe as MB


data Ranks = Ranks { place       :: Int
                   , amount      :: Int
                   , probability :: Float
                   , token       :: String
                   , block       :: String
                   , knownName   :: String
                   } deriving (Show)

data LenStats = LenStats { lengthLen :: Int
                         , tokenLen  :: String
                         , blockLen  :: String
                         } deriving (Show)


makeRanks :: TokenCreatorState -> [(String, String)] -> [Ranks]
makeRanks state namedBlocks = zipWith6 Ranks [1..] amounts probabilities tokens blocks fromattedKnownNames
    where
        tokenAmounts = humanReadebleRankings (topTokens state) state
        tokenDictionary = nub $ concatMap words (texts state)

        amounts = map snd tokenAmounts
        totalAmount = toEnum $ sum amounts
        probabilities = map ((/ totalAmount) . toEnum) amounts
        tokens = map fst tokenAmounts
        blocks = map (tokenToBlock tokenDictionary) tokens
        knownNames = map (\blk -> lookup blk (map swap namedBlocks)) blocks
        fromattedKnownNames = map (MB.fromMaybe "") knownNames


makeLenStats :: TokenCreatorState -> [LenStats]
makeLenStats state = map (uncurry3 LenStats) triples
    where
        tokenAmounts = humanReadebleRankings (topTokens state) state
        tokenDictionary = nub $ concatMap words (texts state)

        tokens = map fst tokenAmounts
        blocks = map (tokenToBlock tokenDictionary) tokens
        lengths = map (length . words) blocks

        triples = sortBy (flip (\(a,_, _) (b,_, _) -> compare a b)) (zip3 lengths tokens blocks)

colRanks :: Colonnade Headed Ranks String
colRanks = mconcat
        [ headed "Place" (show . place)
        , headed "Amount" (show . amount)
        , headed "%" (show . (* 100) . probability)
        , headed "Token" token
        , headed "Block" block
        , headed "Known name" knownName
        ]

colLenStats :: Colonnade Headed LenStats String
colLenStats = mconcat
        [ headed "Length" (show . lengthLen)
        , headed "Token" tokenLen
        , headed "Block" blockLen
        ]

makeStats :: TokenCreatorState -> [Ranks] -> [(String, String)] -> Box
makeStats state ranks knownBlocks = stats
    where
        precentBool = zip (map probability ranks) (map ((> 1) . length . words . block) ranks)
        meaningfulPercent = (* 100) $ sum $ map fst $ filter snd precentBool

        shannonInformation = (-1) * sum [p * logBase 2 p | p <- map probability ranks]

        foundBlocks = filter (/= "") (map knownName ranks)

        stats = vcat top [ hcat top $ map text ["% of covered by meaningful blocks ", show meaningfulPercent]
                         , hcat top $ map text ["information/entropy by Shannon ", show shannonInformation]
                         , hcat top $ map text ["found ", show $ length foundBlocks, " out of ", show $ length knownBlocks, " known blocks"]
                         ]

createReport :: TokenCreatorState -> [(String, String)] -> String
createReport state namedBlocks = report
    where
        ranks = ascii colRanks $ makeRanks state namedBlocks
        lenStats = ascii colLenStats $ take 20 $ makeLenStats state
        stats = render $ makeStats state (makeRanks state namedBlocks) namedBlocks
        report = unlines [ "Information about found tokens:"
                         , stats
                         , lenStats
                         , ranks ]