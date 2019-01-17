{-# LANGUAGE
    GADTs,
    ScopedTypeVariables,
    DataKinds,
    DeriveGeneric,
    TypeOperators,
    BangPatterns,
    TypeApplications
    #-}

module NeuralData.VonMises
    ( -- * Parsing
      getFittedIPLikelihood
    , strengthenIPLikelihood
    -- * Indexing
    , subIPLikelihood
    , subsampleIPLikelihood
    -- * Fitting
    , fitIPLikelihood
    , fitLinearDecoder
    -- * Algorithms
    , linearDecoderDivergence
    , fisherInformation
    , averageLogFisherInformation
    -- * Analyses
    , analyzeTuningCurves
    , analyzeInformations
    , populationParameters
    -- ** CSV
    , PopulationParameterCounts (PopulationParameterCounts)
    , PopulationParameterDensities (PopulationParameterDensities)
    , PopulationCodeInformations (PopulationCodeInformations)
    ) where


--- Imports ---


-- Goal --

import NeuralData

import Goal.Core
import Goal.Geometry
import Goal.Probability

import qualified Goal.Core.Vector.Storable as S
import qualified Goal.Core.Vector.Boxed as B
import qualified Goal.Core.Vector.Generic as G

import qualified Data.List as L


--- Types ---


--- CSV ---


--- Inference ---


-- Under the assumption of a flat prior
linearDecoderDivergence
    :: KnownNat k
    => Mean #> Natural # VonMises <* Neurons k
    -> (Double -> Double) -- ^ True Density
    -> Response k
    -> Double
linearDecoderDivergence dcd trudns z =
    let dcddns = density (dcd >.>* z)
        dv0 x = trudns x * log (trudns x / dcddns x)
     in fst $ integrate 1e-3 dv0 mnx mxx

getFittedIPLikelihood
    :: String
    -> String
    -> IO (NatNumber,[Double])
getFittedIPLikelihood expnm dst =
    read <$> goalReadDataset (Experiment prjnm expnm) dst

strengthenIPLikelihood
    :: KnownNat k
    => [Double]
    -> Mean #> Natural # Neurons k <* VonMises
strengthenIPLikelihood xs = Point . fromJust $ S.fromList xs


--- Analysis ---

-- | Returns x axis samples, and then y axis sum of tuning curves, rectification
-- curve fit, and individual tuning curves.
analyzeTuningCurves
    :: forall k . KnownNat k
    => Sample VonMises
    -> Mean #> Natural # Neurons k <* VonMises
    -> [[Double]]
analyzeTuningCurves xsmps lkl =
    let nzs = lkl >$>* xsmps
        tcss = listCoordinates . dualTransition <$> nzs
        stcs = potential <$> nzs
        (rho0,rprms) = regressRectificationParameters lkl xsmps
        rcrv = rectificationCurve rho0 rprms xsmps
        mxtcs = maximum <$> tcss
     in zipWith (++) (L.transpose (xsmps:stcs:rcrv:[mxtcs])) tcss

ppcStimulusDerivatives
    :: KnownNat k
    => Mean #> Natural # Neurons k <* VonMises
    -> SamplePoint VonMises
    -> S.Vector k Double
ppcStimulusDerivatives ppc x =
    let fxs = coordinates . dualTransition $ ppc >.> mx
        tcs = toRows . snd $ splitAffine ppc
     in S.zipWith zipper fxs tcs
    where mx = sufficientStatistic x
          (cx,sx) = S.toPair $ coordinates mx
          zipper fx (Point cs) =
              let (tht1,tht2) = S.toPair cs
               in fx*(cx * tht2 - sx * tht1)

fisherInformation
    :: KnownNat k
    => Mean #> Natural # Neurons k <* VonMises
    -> Double
    -> Double
fisherInformation ppc x =
    let fxs2' = S.map square $ ppcStimulusDerivatives ppc x
        fxs = coordinates . dualTransition $ ppc >.>* x
     in S.sum $ S.zipWith (/) fxs2' fxs

averageLogFisherInformation
    :: KnownNat k
    => Mean #> Natural # Neurons k <* VonMises
    -> Double
averageLogFisherInformation ppc =
    average $ log . (/(2*pi*exp 1)) . fisherInformation ppc <$> tail (range 0 (2*pi) 101)

fitIPLikelihood
    :: forall r k . KnownNat k
    => [(Response k,Double)]
    -> Random r (Mean #> Natural # Neurons k <* VonMises)
fitIPLikelihood xzs = do
    let eps = -0.1
        nepchs = 500
    kps <- S.replicateM $ uniformR (0.2,0.6)
    let sps = S.zipWith (\kp mu -> Point $ S.doubleton mu kp) kps $ S.range 0 (2*pi)
    gns' <- Point <$> S.replicateM (uniformR (0,2))
    let gns0 = transition . sufficientStatisticT $ fst <$> xzs
        gns = gns0 <+> gns'
        ppc0 = vonMisesPopulationEncoder True (Right gns) sps
        (zs,xs) = unzip xzs
        backprop p = joinTangentPair p $ stochasticConditionalCrossEntropyDifferential xs zs p
    return (vanillaGradientSequence backprop eps defaultAdamPursuit ppc0 !! nepchs)

-- NB: Actually affine, not linear
fitLinearDecoder
    :: forall s k . KnownNat k
    => Mean #> Natural # Neurons k <* VonMises
    -> Sample VonMises
    -> Random s (Mean #> Natural # VonMises <* Neurons k)
fitLinearDecoder lkl xs = do
    zs <- mapM samplePoint (lkl >$>* xs)
    let eps = -0.1
        nepchs = 500
        sps :: S.Vector k (Source # VonMises)
        sps = S.map (\mu -> Point $ S.fromTuple (mu,1)) $ S.range 0 (2*pi)
        nxz = transpose . fromRows $ S.map toNatural sps
        nx = Point $ S.fromTuple (0,0.5)
        aff0 = joinAffine nx nxz
        backprop aff = joinTangentPair aff $ stochasticConditionalCrossEntropyDifferential zs xs aff
    return (vanillaGradientSequence backprop eps defaultAdamPursuit aff0 !! nepchs)

subIPLikelihood
    :: forall k m . (KnownNat k, KnownNat m)
    => Mean #> Natural # Neurons (k + m) <* VonMises
    ->  Mean #> Natural # Neurons k <* VonMises
subIPLikelihood ppc =
    let (bs,tns) = splitAffine ppc
        tns' = fromMatrix . S.fromRows . S.take . S.toRows $ toMatrix tns
        bs' = S.take $ coordinates bs
     in joinAffine (Point bs') tns'

subsampleIPLikelihood
    :: (KnownNat k, KnownNat m)
    => Mean #> Natural # Neurons (k+m) <* VonMises
    -> S.Vector k Int
    -> Mean #> Natural # Neurons k <* VonMises
subsampleIPLikelihood ppc idxs =
    let (bs,tns) = splitAffine ppc
        tns' = fromMatrix . S.fromRows . flip S.backpermute idxs . S.toRows $ toMatrix tns
        bs' = Point . flip S.backpermute idxs $ coordinates bs
     in joinAffine bs' tns'


--- CSV ---


data PopulationParameterCounts = PopulationParameterCounts
    { binCentre :: Double
    , parameterCount :: Int
    , parameterAverage :: Double }
    deriving (Generic, Show)

instance FromNamedRecord PopulationParameterCounts
instance ToNamedRecord PopulationParameterCounts
instance DefaultOrdered PopulationParameterCounts

data PopulationParameterDensities = PopulationParameterDensities
    { parameterValue :: Double
    , parameterDensity :: Double }
    deriving (Generic, Show)

instance FromNamedRecord PopulationParameterDensities
instance ToNamedRecord PopulationParameterDensities
instance DefaultOrdered PopulationParameterDensities

data PopulationParameterDensityParameters = PopulationParameterDensityParameters
    { parameterMean :: Double
    , parameterShape :: Double }
    deriving (Generic, Show)

instance FromNamedRecord PopulationParameterDensityParameters
instance ToNamedRecord PopulationParameterDensityParameters
instance DefaultOrdered PopulationParameterDensityParameters

data PopulationCodeInformations = PopulationCodeInformations
    { mutualInformationMean :: Double
    , mutualInformationSD :: Double
    , linearDivergenceMean :: Double
    , linearDivergenceSD :: Double
    , linearDivergenceRatioMean :: Double
    , linearDivergenceRatioSD :: Double
    , affineDivergenceMean :: Double
    , affineDivergenceSD :: Double
    , affineDivergenceRatioMean :: Double
    , affineDivergenceRatioSD :: Double
    , decoderDivergenceMean :: Maybe Double
    , decoderDivergenceSD :: Maybe Double
    , meanDecoderDivergenceRatio :: Maybe Double
    , sdDecoderDivergenceRatio :: Maybe Double }
    deriving (Generic, Show)

instance FromNamedRecord PopulationCodeInformations
instance ToNamedRecord PopulationCodeInformations
instance DefaultOrdered PopulationCodeInformations


--- Statistics ---


populationParameters
    :: KnownNat k
    => Int
    -> Mean #> Natural # Neurons k <* VonMises
    -> [ ( [PopulationParameterCounts]
         , [PopulationParameterDensities]
         , PopulationParameterDensityParameters ) ]
populationParameters nbns lkl =
    let (nz,nxs) = splitVonMisesPopulationEncoder True lkl
        gns = listCoordinates $ toSource nz
        (mus,kps) = unzip $ S.toPair . coordinates . toSource <$> S.toList nxs
     in do
         (bl,prms) <- zip [False,True,False] [gns,mus,kps]
         let (bns,[cnts],[wghts]) = histograms nbns Nothing [prms]
             dx = head (tail bns) - head bns
             (ppds,dprms) = if bl
               then let backprop vm' = joinTangentPair vm' $ stochasticCrossEntropyDifferential prms vm'
                        vm0 = Point $ S.doubleton 0.01 0.01
                        vm :: Natural # VonMises
                        vm = vanillaGradientSequence backprop (-0.1) defaultAdamPursuit vm0 !! 500
                        xs = range mnx mxx 1000
                        dnss = density vm <$> xs
                        (mu,prcs) = S.toPair . coordinates $ toSource vm
                     in ( zipWith PopulationParameterDensities xs dnss
                        , PopulationParameterDensityParameters mu prcs )
               else let lgnrm :: Natural # LogNormal
                        lgnrm = mle prms
                        xs = range 0 (last bns + dx/2) 1000
                        dnss = density lgnrm <$> xs
                        (mu,sd) = S.toPair . coordinates $ toSource lgnrm
                     in ( zipWith PopulationParameterDensities xs dnss
                        , PopulationParameterDensityParameters mu sd )
         return (zipWith3 PopulationParameterCounts bns cnts wghts,ppds,dprms)

analyzeInformations
    :: forall k m r . (KnownNat k, KnownNat m)
    => Int -- ^ Number of regression/rectification samples
    -> Int -- ^ Number of numerical centering samples
    -> Int -- ^ Number of monte carlo integration samples
    -> Maybe Int -- ^ (Maybe) number of linear decoder samples
    -> Int -- ^ Number of subpopulation samples
    -> Mean #> Natural # Neurons (k+m+1) <* VonMises -- ^ Complete likelihood
    -> Proxy k -- ^ Subpopulation size
    -> Random r PopulationCodeInformations -- ^ Divergence Statistics
analyzeInformations nrct ncntr nmcmc mndcd nsub lkl _ = do
    let [rctsmps,cntrsmps,mcmcsmps] = tail . range mnx mxx . (+1) <$> [nrct,ncntr,nmcmc]
        mdcdsmps = tail . range mnx mxx . (+1) <$> mndcd
    dvgss <- replicateM nsub $ do
            (idxs :: B.Vector (k+1) Int) <- generateIndices (Proxy @ (k+m+1))
            let sublkl = subsampleIPLikelihood lkl $ G.convert idxs
            mdcd <- case mdcdsmps of
                     Just smps -> Just <$> fitLinearDecoder sublkl smps
                     Nothing -> return Nothing
            estimateInformations mdcd rctsmps cntrsmps nmcmc mcmcsmps sublkl
    return $ normalInformationStatistics dvgss

normalInformationStatistics
    :: [(Double,Double,Double,Double,Double,Maybe Double,Maybe Double)]
    -> PopulationCodeInformations
normalInformationStatistics dvgss =
    let (mis,lndvgs,lnrtos,affdvgs,affrtos,mdcddvgs,mdcdrtos) = L.unzip7 dvgss
        [ (mimu,misd),(lnmu,lnsd),(lnrtomu,lnrtosd),(affmu,affsd),(affrtomu,affrtosd)]
            = meanSDInliers <$> [mis,lndvgs,lnrtos,affdvgs,affrtos]
        (mdcdmu,mdcdsd,mdcdrtomu,mdcdrtosd) =
            if isNothing (head mdcddvgs)
               then (Nothing,Nothing,Nothing,Nothing)
               else let (dvgmu,dvgsd) = meanSDInliers $ fromJust <$> mdcddvgs
                        (rtomu,rtosd) = meanSDInliers $ fromJust <$> mdcdrtos
                     in (Just dvgmu, Just dvgsd, Just rtomu, Just rtosd)
     in PopulationCodeInformations
        mimu misd lnmu lnsd lnrtomu lnrtosd affmu affsd affrtomu affrtosd mdcdmu mdcdsd mdcdrtomu mdcdrtosd

-- Assumes a uniform prior over stimuli
estimateInformations
    :: KnownNat k
    => Maybe (Mean #> Natural # VonMises <* Neurons k)
    -> Sample VonMises
    -> Sample VonMises
    -> Int
    -> Sample VonMises
    -> Mean #> Natural # Neurons k <* VonMises
    -> Random r (Double,Double,Double,Double,Double,Maybe Double,Maybe Double)
estimateInformations mdcd rctsmps cntrsmps nmcmc mcmcsmps lkl = do
    let (rho0,rprms) = regressRectificationParameters lkl rctsmps
    (truprt0,ptnl0,lnprt0,affprt0,mdcddvg0)
        <- foldM (informationsFolder mdcd cntrsmps lkl rprms) (0,0,0,0,Just 0) mcmcsmps
    let k' = fromIntegral nmcmc
        (truprt,ptnl,lnprt,affprt,mdcddvg)
          = (truprt0/k',ptnl0/k',lnprt0/k',affprt0/k',(/k') <$> mdcddvg0)
        !lndvg = lnprt - truprt - rho0
        !affdvg = affprt - truprt - rho0
        !mi = ptnl - truprt - rho0
    return (mi,lndvg,lndvg/mi,affdvg,affdvg/mi,mdcddvg,(/mi) <$> mdcddvg)

informationsFolder
    :: KnownNat k
    => Maybe (Mean #> Natural # VonMises <* Neurons k)
    -> Sample VonMises -- ^ centering samples
    -> Mean #> Natural # Neurons k <* VonMises
    -> Natural # VonMises
    -> (Double,Double,Double,Double,Maybe Double)
    -> SamplePoint VonMises
    -> Random r (Double,Double,Double,Double,Maybe Double)
informationsFolder mdcd cntrsmps lkl rprms (truprt,ptnl,lnprt,affprt,mdcddvg) x = do
    z <- samplePoint $ lkl >.>* x
    let (dns,truprt') = numericalRecursiveBayesianInference 1e-6 mnx mxx cntrsmps [lkl] [z] (const 1)
        lnprt' = potential . fromOneHarmonium $ rectifiedBayesRule zero lkl z zero
        affprt' = potential . fromOneHarmonium $ rectifiedBayesRule rprms lkl z zero
        ptnl' = sufficientStatistic z <.> (snd (splitAffine lkl) >.>* x)
        mdcddvg' = do
            dcd <- mdcd
            dcddvg <- mdcddvg
            let dcddvg' = linearDecoderDivergence dcd dns z
            return $ dcddvg + dcddvg'
    return (truprt + truprt',ptnl + ptnl',lnprt + lnprt',affprt + affprt', mdcddvg')
