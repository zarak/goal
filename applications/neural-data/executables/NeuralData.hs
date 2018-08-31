{-# LANGUAGE DataKinds,KindSignatures,TypeOperators #-}

module NeuralData
    ( NeuralModel
    , Neurons
    , Response
    , NeuralData (NeuralData,neuralDataProject,neuralDataFile,neuralDataOutputFile,neuralDataPath,neuralDataGroups)
    , getNeuralData
    , stimulusResponseMap
    , empiricalTuningCurves
    , ppcPosterior0
    -- * Patterson 2013
    , pattersonSmallPooled
    , patterson112l44
    , patterson112l45
    , patterson112r35
    , patterson112r36
    , patterson105r62
    , patterson107l114
    , patterson112l16
    , patterson112r32
    -- * Coen-Cagli 2015
    , coenCagli1
    , coenCagli2
    , coenCagli3
    , coenCagli4
    , coenCagli5
    , coenCagli6
    , coenCagli7
    , coenCagli8
    , coenCagli9
    , coenCagli10
    , coenCagliPooled
    ) where


--- Imports ---


-- Goal --

import Goal.Core
import Goal.Geometry
import Goal.Probability

import qualified Goal.Core.Vector.Storable as S

-- Qualified --

import qualified Data.Map as M


--- Types ---


type NeuralModel s k = Harmonium Tensor (Replicated k Poisson) s
type Neurons k = Replicated k Poisson
type Response k = SamplePoint (Neurons k)

data NeuralData (k :: Nat) s = NeuralData
    { neuralDataProject :: String
    , neuralDataPath :: String
    , neuralDataFile :: String
    , neuralDataOutputFile :: String
    , neuralDataGroups :: [String] }


--- Functions ---


getNeuralData :: (KnownNat k, Read s) => NeuralData k s -> IO [[(Response k, s)]]
getNeuralData (NeuralData dprj dpth df _ _) = read <$> goalReadFile (dprj ++ "/" ++ dpth) df

stimulusResponseMap :: Ord s => [(Response k, s)] -> M.Map s [Response k]
stimulusResponseMap zxs = M.fromListWith (++) [(x,[z]) | (z,x) <- zxs]

empiricalTuningCurves :: (Ord s, KnownNat k) => M.Map s [Response k] -> M.Map s (Mean # Neurons k)
empiricalTuningCurves zxmp = sufficientStatisticT <$> zxmp

-- Under the assumption of a flat prior
unnormalizedPPCPosterior0
    :: KnownNat k
    => Bool
    -> Response k
    -> Mean # Neurons k
    -> Double
unnormalizedPPCPosterior0 True z mz =
    let smz = S.sum $ coordinates mz
     in exp $ dualTransition mz <.> sufficientStatistic z + smz
unnormalizedPPCPosterior0 False z mz =
     exp $ dualTransition mz <.> sufficientStatistic z

-- Under the assumption of a flat prior
ppcPosterior0
    :: (Ord s, KnownNat k)
    => Bool -> Response k -> M.Map s (Mean # Neurons k) -> M.Map s Double
ppcPosterior0 nrmb z xzmp =
    let udns = unnormalizedPPCPosterior0 nrmb z <$> xzmp
        nrm = sum udns
     in (/nrm) <$> udns

-- Under the assumption of a flat prior
estimatePPCMutualInformation0
    :: (Ord s, KnownNat k)
    => Int
    -> M.Map s (Mean # Neurons k)
    -> Random r Double
estimatePPCMutualInformation0 nsmps xzmp = do
    zss <- mapM (sample nsmps) xzmp
    let scl = recip . fromIntegral . length $ M.keys xzmp
        f z = sum [ d * log (d*scl) | d <- M.elems $ ppcPosterior0 True z xzmp ]
    return . average $ f <$> concat zss

--- Patterson 2013 Data ---


pattersonSmallPooled :: NeuralData 121 Double
pattersonSmallPooled = NeuralData
    { neuralDataProject = "patterson-2013"
    , neuralDataPath = "small40/pooled"
    , neuralDataFile = "zxs01"
    , neuralDataOutputFile = "small-pooled"
    , neuralDataGroups = ["pre-adapt","post-adapt"]
    }

patterson112l44 :: NeuralData 55 Double
patterson112l44 = NeuralData
    { neuralDataProject = "patterson-2013"
    , neuralDataPath = "small40/112l44"
    , neuralDataFile = "zxs01"
    , neuralDataOutputFile = "112l44"
    , neuralDataGroups = ["pre-adapt","post-adapt"]
    }

patterson112l45 :: NeuralData 42 Double
patterson112l45 = NeuralData
    { neuralDataProject = "patterson-2013"
    , neuralDataPath = "small40/112l45"
    , neuralDataFile = "zxs01"
    , neuralDataOutputFile = "112l45"
    , neuralDataGroups = ["pre-adapt","post-adapt"]
    }

patterson112r35 :: NeuralData 11 Double
patterson112r35 = NeuralData
    { neuralDataProject = "patterson-2013"
    , neuralDataPath = "small40/112r35"
    , neuralDataFile = "zxs01"
    , neuralDataOutputFile = "112r35"
    , neuralDataGroups = ["pre-adapt","post-adapt"]
    }

patterson112r36 :: NeuralData 13 Double
patterson112r36 = NeuralData
    { neuralDataProject = "patterson-2013"
    , neuralDataPath = "small40/112r36"
    , neuralDataFile = "zxs01"
    , neuralDataOutputFile = "112r36"
    , neuralDataGroups = ["pre-adapt","post-adapt"]
    }

patterson105r62 :: NeuralData 81 Double
patterson105r62 = NeuralData
    { neuralDataProject = "patterson-2013"
    , neuralDataPath = "big40/105r62"
    , neuralDataFile = "zxs01"
    , neuralDataOutputFile = "105r62"
    , neuralDataGroups = ["pre-adapt","post-adapt"]
    }

patterson107l114 :: NeuralData 126 Double
patterson107l114 = NeuralData
    { neuralDataProject = "patterson-2013"
    , neuralDataPath = "big40/107l114"
    , neuralDataFile = "zxs01"
    , neuralDataOutputFile = "107l114"
    , neuralDataGroups = ["pre-adapt","post-adapt"]
    }

patterson112l16 :: NeuralData 118 Double
patterson112l16 = NeuralData
    { neuralDataProject = "patterson-2013"
    , neuralDataPath = "big40/112l16"
    , neuralDataFile = "zxs01"
    , neuralDataOutputFile = "112l16"
    , neuralDataGroups = ["pre-adapt","post-adapt"]
    }

patterson112r32 :: NeuralData 126 Double
patterson112r32 = NeuralData
    { neuralDataProject = "patterson-2013"
    , neuralDataPath = "big40/112r32"
    , neuralDataFile = "zxs01"
    , neuralDataOutputFile = "112r32"
    , neuralDataGroups = ["pre-adapt","post-adapt"]
    }


--- Coen-Cagli 2015 ---


coenCagli1 :: NeuralData 102 Double
coenCagli1 = NeuralData
    { neuralDataProject = "coen-cagli-2015"
    , neuralDataPath = "data"
    , neuralDataFile = "zxs1"
    , neuralDataOutputFile = "zxs1"
    , neuralDataGroups = ["data"]
    }

coenCagli2 :: NeuralData 112 Double
coenCagli2 = NeuralData
    { neuralDataProject = "coen-cagli-2015"
    , neuralDataPath = "data"
    , neuralDataFile = "zxs2"
    , neuralDataOutputFile = "zxs2"
    , neuralDataGroups = ["data"]
    }

coenCagli3 :: NeuralData 112 Double
coenCagli3 = NeuralData
    { neuralDataProject = "coen-cagli-2015"
    , neuralDataPath = "data"
    , neuralDataFile = "zxs3"
    , neuralDataOutputFile = "zxs3"
    , neuralDataGroups = ["data"]
    }
coenCagli4 :: NeuralData 105 Double
coenCagli4 = NeuralData
    { neuralDataProject = "coen-cagli-2015"
    , neuralDataPath = "data"
    , neuralDataFile = "zxs4"
    , neuralDataOutputFile = "zxs4"
    , neuralDataGroups = ["data"]
    }
coenCagli5 :: NeuralData 121 Double
coenCagli5 = NeuralData
    { neuralDataProject = "coen-cagli-2015"
    , neuralDataPath = "data"
    , neuralDataFile = "zxs5"
    , neuralDataOutputFile = "zxs5"
    , neuralDataGroups = ["data"]
    }
coenCagli6 :: NeuralData 94 Double
coenCagli6 = NeuralData
    { neuralDataProject = "coen-cagli-2015"
    , neuralDataPath = "data"
    , neuralDataFile = "zxs6"
    , neuralDataOutputFile = "zxs6"
    , neuralDataGroups = ["data"]
    }
coenCagli7 :: NeuralData 111 Double
coenCagli7 = NeuralData
    { neuralDataProject = "coen-cagli-2015"
    , neuralDataPath = "data"
    , neuralDataFile = "zxs7"
    , neuralDataOutputFile = "zxs7"
    , neuralDataGroups = ["data"]
    }
coenCagli8 :: NeuralData 134 Double
coenCagli8 = NeuralData
    { neuralDataProject = "coen-cagli-2015"
    , neuralDataPath = "data"
    , neuralDataFile = "zxs8"
    , neuralDataOutputFile = "zxs8"
    , neuralDataGroups = ["data"]
    }
coenCagli9 :: NeuralData 150 Double
coenCagli9 = NeuralData
    { neuralDataProject = "coen-cagli-2015"
    , neuralDataPath = "data"
    , neuralDataFile = "zxs9"
    , neuralDataOutputFile = "zxs9"
    , neuralDataGroups = ["data"]
    }

coenCagli10 :: NeuralData 153 Double
coenCagli10 = NeuralData
    { neuralDataProject = "coen-cagli-2015"
    , neuralDataPath = "data"
    , neuralDataFile = "zxs10"
    , neuralDataOutputFile = "zxs10"
    , neuralDataGroups = ["data"]
    }

coenCagliPooled :: NeuralData 1194 Double
coenCagliPooled = NeuralData
    { neuralDataProject = "coen-cagli-2015"
    , neuralDataPath = "data"
    , neuralDataFile = "zxs-pooled"
    , neuralDataOutputFile = "zxs-pooled"
    , neuralDataGroups = ["data"]
    }
