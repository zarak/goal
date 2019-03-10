{-# OPTIONS_GHC -fplugin=GHC.TypeLits.KnownNat.Solver -fplugin=GHC.TypeLits.Normalise #-}

{-# LANGUAGE
    FlexibleContexts,
    TypeFamilies,
    TypeOperators,
    TypeApplications,
    ScopedTypeVariables,
    DataKinds
    #-}


--- Imports ---


import NeuralData
import NeuralData.Mixture

import Goal.Core
import Goal.Geometry
import Goal.Probability

import qualified Goal.Core.Vector.Storable as S


--- Globals ---


nbns :: Int
nbns = 10

nstms :: Int
nstms = 8

stms :: [Double]
stms = tail $ range mnx mxx (nstms + 1)

xsmps :: [Double]
xsmps = init $ range mnx mxx 101


--- CLI ---


data ValidationOpts = ValidationOpts Int Int Int Double NatNumber Double Int Int Double Double

validationOpts :: Parser ValidationOpts
validationOpts = ValidationOpts
    <$> option auto
        ( short 'n'
        <> long "n-population"
        <> help "Number of shotgun populations to generate."
        <> showDefault
        <> value 10 )
    <*> option auto
        ( short 'f'
        <> long "k-fold-validation"
        <> help "Number of (k-)folds."
        <> showDefault
        <> value 5 )
    <*> option auto
        ( short 'm'
        <> long "dirichlet"
        <> help "Number of mixture model counts to test."
        <> showDefault
        <> value 8 )
    <*> option auto
        ( short 'M'
        <> long "concentration"
        <> help "Concetration of mixture weights."
        <> showDefault
        <> value 2 )
    <*> option auto
        ( short 's'
        <> long "mixture-step"
        <> help "Number of mixture counts to step each iteration."
        <> showDefault
        <> value 1 )
    <*> option auto
        ( short 'l'
        <> long "learning-rate"
        <> help "The learning rate."
        <> showDefault
        <> value (-0.05) )
    <*> option auto
        ( short 'b'
        <> long "n-batch"
        <> help "Batch size."
        <> showDefault
        <> value 10 )
    <*> option auto
        ( short 'e'
        <> long "n-epochs"
        <> help "Number of batches to run the learning over."
        <> showDefault
        <> value 5000 )
    <*> option auto
        ( short 'p'
        <> long "log-mu-precision"
        <> help "The mu parameter of the initial precision log-normal."
        <> showDefault
        <> value (-1) )
    <*> option auto
        ( short 'P'
        <> long "log-sd-precision"
        <> help "The sd parameter of the initial precision log-normal."
        <> showDefault
        <> value 0.5 )

data AllOpts = AllOpts ExperimentOpts ValidationOpts

allOpts :: Parser AllOpts
allOpts = AllOpts <$> experimentOpts <*> validationOpts

runOpts :: AllOpts -> IO ()
runOpts ( AllOpts expopts@(ExperimentOpts expnm _)
    (ValidationOpts npop kfld nmx cnc nstp eps nbtch nepchs pmu psd) ) = do

    dsts <- readDatasets expopts

    let expmnt = Experiment prjnm expnm

        lgnrm :: Natural # LogNormal
        lgnrm = toNatural . Point @ Source $ S.doubleton pmu psd

    forM_ dsts $ \dst -> do

        putStrLn "\nDataset:"
        putStrLn dst

        let ceanl = Just $ Analysis "cross-validation" dst

        (k,zxs0 :: [([Int], Double)]) <- getNeuralData expnm dst

        putStrLn "\nNumber of Mixers:"

        case someNatVal k of
            SomeNat (Proxy :: Proxy k) -> do

                let zxs1 :: [(Response k, Double)]
                    zxs1 = strengthenNeuralData zxs0
                zxs <- realize $ shuffleList zxs1

                let idxs = take nmx [0,nstp..]

                cvls <- forM idxs $ \m -> case someNatVal m

                    of SomeNat (Proxy :: Proxy m) -> do

                        print $ m+1

                        let drch :: Natural # Dirichlet (m+1)
                            drch = Point $ S.replicate cnc

                        (sgdnrms, nnans, mlkls) <- realize
                            $ shotgunFitMixtureLikelihood npop eps nbtch nepchs drch lgnrm zxs

                        let mlkl = last mlkls

                        goalExportNamed (m==0) expmnt ceanl sgdnrms

                        putStrLn $ concat ["\nNumber of NaNs: ", show nnans , " / ", show npop]

                        let rltv = "../population-parameters/"
                            ttl = show (m+1) ++ "-mixers"

                        runPopulationParameterAnalyses expmnt dst xsmps nbns rltv ttl Nothing Nothing mlkl

                        realize $ crossValidateMixtureLikelihood kfld npop eps nbtch nepchs drch lgnrm zxs

                goalExportNamed False expmnt ceanl cvls

        runGnuplot expmnt ceanl defaultGnuplotOptions "cross-entropy-descent.gpi"
        runGnuplot expmnt ceanl defaultGnuplotOptions "cross-validation.gpi"


--- Main ---


main :: IO ()
main = do

    let prgstr = "Stress test the fitting of likelihoods."
        hdrstr = "Stress test the fitting of likelihoods."
        opts = info (allOpts <**> helper) (fullDesc <> progDesc prgstr <> header hdrstr)
    runOpts =<< execParser opts