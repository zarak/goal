{-# OPTIONS_GHC -fplugin=GHC.TypeLits.KnownNat.Solver -fplugin=GHC.TypeLits.Normalise #-}
{-# LANGUAGE FlexibleContexts,GADTs,ScopedTypeVariables,DataKinds,TypeOperators #-}

--- Imports ---


-- Goal --

import NeuralData

import Goal.Core
import Goal.Geometry
import Goal.Probability

import qualified Goal.Core.Vector.Storable as S


--- Globals ---


-- General --

mnx,mxx :: Double
mnx = 0
mxx = 2*pi

nstms :: Int
nstms = 8

nsmps :: Int
nsmps = 100

stms :: [Double]
stms = tail $ range mnx mxx (nstms + 1)

wghts0 :: (KnownNat n, 1 <= n) => Natural # Categorical Int n
wghts0 = zero

wghts :: (KnownNat n, 1 <= n) => Source # Categorical Int n
wghts = transition wghts0

fromConditionalOneMixture
    :: Mean #> Natural # MixtureGLM (Neurons k) Int 1 VonMises
    -> Mean #> Natural # Neurons k <* VonMises
fromConditionalOneMixture = breakPoint



-- Convolutional --

cmus :: KnownNat k => S.Vector k Double
cmus = S.init $ S.range mnx mxx

ckp :: Double
ckp = 1

csps :: KnownNat k => S.Vector k (Source # VonMises)
csps = S.map (Point . flip S.doubleton ckp) cmus

cgnss :: forall n k . (KnownNat n, KnownNat k) => S.Vector n (Source # Neurons k)
cgnss = S.generateP generator
    where generator :: (KnownNat j, j <= n) => Proxy j -> (Source # Neurons k)
          generator prxj = Point . S.replicate $ 10 + 5 * fromIntegral (natValInt prxj)

clkl
    :: (KnownNat k, KnownNat n, 1 <= n)
    => Proxy n -> Mean #> Natural # MixtureGLM (Neurons k) Int n VonMises
clkl _ = vonMisesMixturePopulationEncoder True wghts cgnss csps

-- Random --

rmus :: KnownNat k => Random r (S.Vector k Double)
rmus = S.replicateM $ uniformR (mnx,mxx)

rkps :: KnownNat k => Random r (S.Vector k Double)
rkps = S.replicateM $ uniformR (0.5,1.5)

rsps :: KnownNat k => Random r (S.Vector k (Source # VonMises))
rsps = S.zipWith (\x y -> Point $ S.doubleton x y) <$> rmus <*> rkps

rgnss :: (KnownNat n, KnownNat k) => Random r (S.Vector n (Source # Neurons k))
rgnss = S.replicateM . fmap Point . S.replicateM $ uniformR (10,20)

rlklr
    :: (KnownNat k, KnownNat n, 1 <= n)
    => Random r (Mean #> Natural # MixtureGLM (Neurons k) Int n VonMises)
rlklr = do
    gnss <- rgnss
    vonMisesMixturePopulationEncoder True wghts gnss <$> rsps

normalizeMixtureLikelihood
    :: (KnownNat k, KnownNat n, 1 <= n)
    => Mean #> Natural # MixtureGLM (Neurons k) Int n VonMises
    -> Mean #> Natural # MixtureGLM (Neurons k) Int n VonMises
normalizeMixtureLikelihood lkl0 =
    let (nzk,nzx) = splitBottomSubLinear lkl0
        bnd = 0.0001
        eps = -0.005
        xsmps = range mnx mxx 100
        cauchify = last . take 10000 . cauchySequence euclideanDistance bnd
        rho0 = average $ potential <$> lkl0 >$>* xsmps
        diff = conditionalHarmoniumRectificationDifferential rho0 zero xsmps nzx
        nzk' = cauchify $ vanillaGradientSequence diff eps defaultAdamPursuit nzk
     in joinBottomSubLinear nzk' nzx

--normalizeLikelihood
--    :: KnownNat k
--    => Mean #> Natural # Neurons k <* VonMises
--    -> Mean #> Natural # Neurons k <* VonMises
--normalizeLikelihood lkl0 =
--    let (nz,nzx) = splitAffine lkl0
--        bnd = 0.0001
--        eps = -0.005
--        xsmps = range mnx mxx 100
--        cauchify = last . take 10000 . cauchySequence euclideanDistance bnd
--        rho0 = average $ potential <$> lkl0 >$>* xsmps
--        diff = populationCodeRectificationDifferential rho0 zero xsmps nzx
--        nz' = cauchify $ vanillaGradientSequence diff eps defaultAdamPursuit nz
--     in joinAffine nz' nzx

combineStimuli :: [[Response k]] -> [([Int],Double)]
combineStimuli zss =
    concat $ zipWith (\zs x -> zip (toList <$> zs) $ repeat x) zss stms

-- IO --

syntheticExperiment :: Int -> String
syntheticExperiment k = "synthetic-" ++ show k ++ "k"

trueSyntheticExperiment :: Int -> String
trueSyntheticExperiment k = "true-" ++ syntheticExperiment k

syntheticMixtureExperiment :: Int -> Int -> String
syntheticMixtureExperiment k n = "synthetic-" ++ show k ++ "k-" ++ show n ++ "n"

trueSyntheticMixtureExperiment :: Int -> Int -> String
trueSyntheticMixtureExperiment k n = "true-" ++ syntheticMixtureExperiment k n

--- Main ---


data SyntheticOpts = SyntheticOpts Int Int

syntheticOpts :: Parser SyntheticOpts
syntheticOpts = SyntheticOpts
    <$> option auto (long "kneurons" <> help "number of neurons" <> short 'k' <> value 50)
    <*> option auto (long "nmixers" <> help "number of mixers" <> short 'm' <> value 3)


synthesizeData :: forall k . KnownNat k => Proxy k -> IO ()
synthesizeData prxk = do

    rlkl0 <- realize rlklr
    let rlkl = fromConditionalOneMixture rlkl0

    let nrlkl :: Mean #> Natural # Neurons k <* VonMises
        nrlkl = fromConditionalOneMixture $ normalizeMixtureLikelihood rlkl0

    let clkln = fromConditionalOneMixture $ clkl Proxy

    (czss :: [[Response k]]) <- realize (mapM (sample nsmps) $ clkln >$>* stms)
    (rzss :: [[Response k]]) <- realize (mapM (sample nsmps) $ rlkl >$>* stms)
    (nrzss :: [[Response k]]) <- realize (mapM (sample nsmps) $ nrlkl >$>* stms)


    let czxs,rzxs,nrzxs :: [([Int], Double)]
        czxs = combineStimuli czss
        rzxs = combineStimuli rzss
        nrzxs = combineStimuli nrzss

    let dsts@[cnvdst,rnddst,nrmdst] = Dataset <$> ["convolutional","random","random-normalized"]

    let k = natValInt prxk

    goalWriteDataset prjnm (syntheticExperiment k) cnvdst $ show (k,czxs)
    goalWriteDataset prjnm (syntheticExperiment k) rnddst $ show (k,rzxs)
    goalWriteDataset prjnm (syntheticExperiment k) nrmdst $ show (k,nrzxs)

    goalWriteDatasetsCSV prjnm (syntheticExperiment k) dsts

    goalWriteDataset prjnm (trueSyntheticExperiment k) cnvdst $ show (k,listCoordinates clkln)
    goalWriteDataset prjnm (trueSyntheticExperiment k) rnddst $ show (k,listCoordinates rlkl)
    goalWriteDataset prjnm (trueSyntheticExperiment k) nrmdst $ show (k,listCoordinates nrlkl)

    goalWriteDatasetsCSV prjnm (trueSyntheticExperiment k) dsts

synthesizeMixtureData :: forall k n . (KnownNat k, KnownNat n, 1 <= n) => Proxy k -> Proxy n -> IO ()
synthesizeMixtureData prxk prxn = do

    (rlkl :: Mean #> Natural # MixtureGLM (Neurons k) Int n VonMises) <- realize rlklr

    let nrlkl :: Mean #> Natural # MixtureGLM (Neurons k) Int n VonMises
        nrlkl = normalizeMixtureLikelihood rlkl
--
    (rzss :: [[Response k]]) <- realize (mapM (fmap (map hHead) . sample nsmps) $ rlkl >$>* stms)
    (nrzss :: [[Response k]]) <- realize (mapM (fmap (map hHead) . sample nsmps) $ nrlkl >$>* stms)
--
--
    let rzxs,nrzxs :: [([Int], Double)]
        rzxs = combineStimuli rzss
        nrzxs = combineStimuli nrzss
--
    let dsts@[rnddst,nrmdst] = Dataset <$> ["random","random-normalized"]
--
    let k = natValInt prxk
        n = natValInt prxn
--
--    goalWriteDataset prjnm (syntheticMixtureExperiment k n) rnddst $ show (k,rzxs)
--    goalWriteDataset prjnm (syntheticMixtureExperiment k n) nrmdst $ show (k,nrzxs)
--
--    goalWriteDatasetsCSV prjnm (syntheticMixtureExperiment k n) dsts

    goalWriteDataset prjnm (trueSyntheticMixtureExperiment k n) rnddst $ show (k,n,listCoordinates rlkl)
    goalWriteDataset prjnm (trueSyntheticMixtureExperiment k n) nrmdst $ show (k,n,listCoordinates nrlkl)
--
--    goalWriteDatasetsCSV prjnm (trueSyntheticMixtureExperiment k n) dsts


runOpts :: SyntheticOpts -> IO ()
runOpts (SyntheticOpts k n)
  | n < 1 = withNat k synthesizeData
  | otherwise = withNat1 n (withNat k synthesizeMixtureData)

--- Main ---


main :: IO ()
main = do

    let opts = info (syntheticOpts <**> helper) (fullDesc <> progDesc prgstr)
        prgstr = "Generate synthetic data"

    runOpts =<< execParser opts