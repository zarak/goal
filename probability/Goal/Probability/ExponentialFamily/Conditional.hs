{-# OPTIONS_GHC -fplugin=GHC.TypeLits.KnownNat.Solver -fplugin=GHC.TypeLits.Normalise -fconstraint-solver-iterations=10 #-}
{-# LANGUAGE UndecidableInstances,Arrows #-}

-- | 'Statistical' models where the observable biases depend on additional inputs.
module Goal.Probability.ExponentialFamily.Conditional
    ( SampleMap
    -- ** Conditional Distributions
    , conditionalLogLikelihood
    , conditionalLogLikelihoodDifferential
    , conditionalDataMap
    , mapConditionalLogLikelihood
    , mapConditionalLogLikelihoodDifferential
     -- * Conditional Harmoniums
    , ConditionalBias
    , ConditionalBiases
    , ConditionalDeepHarmonium
    , ConditionalHarmonium
    , ConditionalMixture
    , ConditionalMixture'
    -- ** Construction
    , joinConditionalHarmonium
    , splitConditionalHarmonium
    , joinConditionalDeepHarmonium
    , splitConditionalDeepHarmonium
    -- ** Evaluation
    , mapConditionalHarmoniumExpectationStep
    ) where


--- Imports  ---


-- Goal --

import Goal.Core
import Goal.Geometry

import Goal.Probability.Statistical
import Goal.Probability.Distributions
import Goal.Probability.ExponentialFamily

import qualified Goal.Core.Vector.Storable as S
import Goal.Probability.ExponentialFamily.Harmonium

import qualified Data.Map as M



--- Generic ---


type SampleMap z x = M.Map (SamplePoint x) (Sample z)


dependantLogLikelihood
    :: (LogLikelihood d y s, Map Mean d f y x)
    => [([s], Mean # x)] -> Function Mean d # f y x -> Double
{-# INLINE dependantLogLikelihood #-}
dependantLogLikelihood ysxs chrm =
    let (yss,xs) = unzip ysxs
     in average . zipWith logLikelihood yss $ chrm >$> xs

dependantLogLikelihoodDifferential
    :: (LogLikelihood d y s, Propagate Mean d f y x)
    => [([s], Mean # x)] -> Function Mean d # f y x -> Function Mean d #* f y x
{-# INLINE dependantLogLikelihoodDifferential #-}
dependantLogLikelihoodDifferential ysxs chrm =
    let (yss,xs) = unzip ysxs
        (df,yhts) = propagate mys xs chrm
        mys = zipWith logLikelihoodDifferential yss yhts
     in df

conditionalDataMap
    :: Ord x
    => [(t, x)] -- ^ Output/Input Pairs
    -> M.Map x [t] -- ^ Input Output map
{-# INLINE conditionalDataMap #-}
conditionalDataMap yxs =
    M.fromListWith (++) [(x, [y]) | (y, x) <- yxs]

-- | The conditional 'logLikelihood' for a conditional distribution.
conditionalLogLikelihood
    :: (ExponentialFamily x, Map Mean Natural f y x, LogLikelihood Natural y t)
    => [(t, SamplePoint x)] -- ^ Output/Input Pairs
    -> Natural #> f y x -- ^ Function
    -> Double -- ^ conditional cross entropy estimate
{-# INLINE conditionalLogLikelihood #-}
conditionalLogLikelihood yxs f =
    let ysxs = [ ([y],sufficientStatistic x) | (y,x) <- yxs ]
     in dependantLogLikelihood ysxs f

-- | The conditional 'logLikelihoodDifferential' for a conditional distribution.
conditionalLogLikelihoodDifferential
    :: ( ExponentialFamily x, LogLikelihood Natural y t, Propagate Mean Natural f y x )
    => [(t, SamplePoint x)] -- ^ Output/Input Pairs
    -> Natural #> f y x -- ^ Function
    -> Natural #*> f y x -- ^ Differential
{-# INLINE conditionalLogLikelihoodDifferential #-}
conditionalLogLikelihoodDifferential yxs f =
    let ysxs = [ ([y],sufficientStatistic x) | (y,x) <- yxs ]
     in dependantLogLikelihoodDifferential ysxs f

-- | The conditional 'logLikelihood' for a conditional distribution, where
-- redundant conditions/inputs are combined. This can dramatically increase performance when
-- the number of distinct conditions/inputs is small.
mapConditionalLogLikelihood
    :: ( ExponentialFamily x, Map Mean Natural f y x, LogLikelihood Natural y t )
    => M.Map (SamplePoint x) [t] -- ^ Output/Input Pairs
    -> Natural #> f y x -- ^ Function
    -> Double -- ^ conditional cross entropy estimate
{-# INLINE mapConditionalLogLikelihood #-}
mapConditionalLogLikelihood xtsmp f =
     dependantLogLikelihood [ (ts, sufficientStatistic x) | (x,ts) <- M.toList xtsmp] f

-- | The conditional 'logLikelihoodDifferential', where redundant conditions are
-- combined. This can dramatically increase performance when the number of
-- distinct conditions is small.
mapConditionalLogLikelihoodDifferential
    :: ( ExponentialFamily x, LogLikelihood Natural y t
       , Propagate Mean Natural f y x, Ord (SamplePoint x) )
    => M.Map (SamplePoint x) [t] -- ^ Output/Input Pairs
    -> Natural #> f y x -- ^ Function
    -> Natural #*> f y x -- ^ Differential
{-# INLINE mapConditionalLogLikelihoodDifferential #-}
mapConditionalLogLikelihoodDifferential xtsmp f =
     dependantLogLikelihoodDifferential [ (ts, sufficientStatistic x) | (x,ts) <- M.toList xtsmp] f


---- | Ascent of the conditional EM objective on conditional harmoniums, which
---- allows conditional harmoniums to be fit by approximate EM.
--conditionalExpectationMaximizationAscent
--    :: ( Propagate Mean Natural f (y,x) z, Bilinear g y x, Map Mean Natural g x y
--       , LegendreExponentialFamily (Harmonium y g x), LegendreExponentialFamily x
--       , ExponentialFamily y, ExponentialFamily z )
--    => Double -- ^ Learning rate
--    -> GradientPursuit -- ^ Gradient pursuit algorithm
--    -> Int -- ^ Minibatch size
--    -> Int -- ^ Number of iterations
--    -> Sample (y,z) -- ^ (Output,Input) samples
--    -> Natural #> ConditionalHarmonium f y g x z
--    -> Random r (Natural #> ConditionalHarmonium f y g x z)
--{-# INLINE conditionalExpectationMaximizationAscent #-}
--conditionalExpectationMaximizationAscent eps gp nbtch nstps yzs0 chrm0 = do
--    let chrmcrc = loopCircuit' chrm0 $ proc (mhrmzs,chrm) -> do
--            let (mhrms,zs) = unzip mhrmzs
--                dhrms = zipWith (-) mhrms $ transition <$> hrmhts
--                (dchrm,hrmhts) = propagate dhrms zs chrm
--            gradientCircuit eps gp -< (chrm,vanillaGradient dchrm)
--    let zs0 = snd <$> yzs0
--        mhrms0 = mapConditionalHarmoniumExpectationStep yzs0 chrm0
--        ncycs = 1 + div (length yzs0 - 1) (nstps * nbtch)
--    mhrmzs0 <- replicateM ncycs (shuffleList . zip mhrms0 $ sufficientStatistic <$> zs0)
--    let mhrmzss = take nstps . breakEvery nbtch $ concat mhrmzs0
--    iterateCircuit chrmcrc mhrmzss
--
---- | An approximate differntial for conjugating a harmonium likelihood.
--conditionalHarmoniumConjugationDifferential
--    :: ( Propagate Mean Natural f (y,x) z, Manifold (g y x), LegendreExponentialFamily (Harmonium y g x)
--       , LegendreExponentialFamily x, ExponentialFamily y, ExponentialFamily z )
--    => Double -- ^ Conjugation shift
--    -> Natural # z -- ^ Conjugation parameters
--    -> Sample z -- ^ Sample points
--    -> Natural #> ConditionalHarmonium f y g x z
--    -> Mean #> ConditionalHarmonium f y g x z
--{-# INLINE conditionalHarmoniumConjugationDifferential #-}
--conditionalHarmoniumConjugationDifferential rho0 rprms xsmps chrm =
--    let rcts = conjugationCurve rho0 rprms xsmps
--        mhrms = transition <$> nhrms
--        ptns = potential <$> nhrms
--        dhrms = [ (ptn - rct) .> mhrm | (rct,mhrm,ptn) <- zip3 rcts mhrms ptns ]
--        (dchrm,nhrms) = propagate dhrms (sufficientStatistic <$> xsmps) chrm
--     in dchrm
--


--- Types ---


-- | A generic conditional model.
data ConditionalBias (f :: Type -> Type -> Type) z x

-- | Another generic conditional model.
data ConditionalBiases (f :: Type -> Type -> Type) z x

-- | A conditional 'DeepHarmonium', where the observable biases of the
-- 'Harmonium' model depend on additional variables.
type ConditionalDeepHarmonium f y (gxs :: [(Type -> Type -> Type,Type)])
  = ConditionalBias f (DeepHarmonium y gxs)

-- | A conditional 'Harmonium', where the observable biases of the
-- 'Harmonium' model depend on additional variables.
type ConditionalHarmonium f y g x = ConditionalBiases f (Harmonium y (g :: Type -> Type -> Type) x)

-- | A conditional 'Harmonium', where the observable biases of the
-- 'Harmonium' model depend on additional variables.
type ConditionalHarmonium' f y g x = ConditionalDeepHarmonium f y ('[ '(g,x)])

-- | A conditional 'Mixture', where the observable biases of the
-- 'Harmonium' model depend on additional variables.
type ConditionalMixture f y k = ConditionalHarmonium f y Tensor (Categorical k) -- ^ Function

-- | A conditional 'Mixture', where the observable biases of the
-- 'Harmonium' model depend on additional variables.
type ConditionalMixture' f y k = ConditionalHarmonium' f y Tensor (Categorical k) -- ^ Function

-- | Splits a conditional 'DeepHarmonium'/'Harmonium'/'Mixture' into the
-- unbiased harmonium and the function which models the dependence.
splitConditionalHarmonium
    :: Manifold (Harmonium y g x)
    => c #> ConditionalHarmonium f y g x z -- ^ Conditional Harmonium
    -> (c # Harmonium y g x, c #> f (y,x) z) -- ^ Matrix function and upper part
{-# INLINE splitConditionalHarmonium #-}
splitConditionalHarmonium chrm =
    let (hrmcs,fcs) = S.splitAt $ coordinates chrm
     in (Point hrmcs, Point fcs)

-- | Creates a conditional 'DeepHarmonium'/'Harmonium'/'Mixture' given an
-- unbiased harmonium and a function which models the dependence.
joinConditionalHarmonium
    :: Manifold (Harmonium y g x)
    => c # Harmonium y g x
    -> c #> f (y,x) z
    -> c #> ConditionalHarmonium f y g x z -- ^ Conditional Harmonium
{-# INLINE joinConditionalHarmonium #-}
joinConditionalHarmonium (Point hrmcs) (Point fcs) =
    Point $ hrmcs S.++ fcs

-- | Splits a conditional 'DeepHarmonium'/'Harmonium'/'Mixture' into the
-- unbiased harmonium and the function which models the dependence.
splitConditionalDeepHarmonium
    :: (Manifold (f y z), Manifold (DeepHarmonium y gxs))
    => c #> ConditionalDeepHarmonium f y gxs z -- ^ Conditional Harmonium
    -> (c # DeepHarmonium y gxs, c #> f y z) -- ^ Matrix function and upper part
{-# INLINE splitConditionalDeepHarmonium #-}
splitConditionalDeepHarmonium dhrm =
    let (dhrmcs,fcs) = S.splitAt $ coordinates dhrm
     in (Point dhrmcs,Point fcs)

-- | Creates a conditional 'DeepHarmonium'/'Harmonium'/'Mixture' given an
-- unbiased harmonium and a function which models the dependence.
joinConditionalDeepHarmonium
    :: ( Manifold (f y z), Manifold (DeepHarmonium y gxs) )
    => c # DeepHarmonium y gxs
    -> c #> f y z
    -> c #> ConditionalDeepHarmonium f y gxs z -- ^ Conditional Harmonium
{-# INLINE joinConditionalDeepHarmonium #-}
joinConditionalDeepHarmonium (Point dcs) (Point fcs) = Point $ dcs S.++ fcs

-- | Empirical expectations of a conditional harmonium.
mapConditionalHarmoniumExpectationStep
    :: ( ExponentialFamily y, ExponentialFamily z, Bilinear g y x
       , Map Mean Natural g x y , Map Mean Natural f (Harmonium y g x) z
       , LegendreExponentialFamily x, Ord (SamplePoint z) )
    => SampleMap y z -- ^ Model Samples
    -> Natural #> f (Harmonium y g x) z -- ^ Harmonium
    -> M.Map (SamplePoint z) (Mean # Harmonium y g x) -- ^ Harmonium expected sufficient statistics
{-# INLINE mapConditionalHarmoniumExpectationStep #-}
mapConditionalHarmoniumExpectationStep yzmp chrm =
    let (zs,yss) = unzip $ M.toList yzmp
        hrms = chrm >$>* zs
     in M.fromList . zip zs $ zipWith harmoniumExpectationStep yss hrms


--- Instances ---


instance (Map Mean Natural f (y,x) z, Manifold (Harmonium y g x))
    => Manifold (ConditionalHarmonium f y g x z) where
        type Dimension (ConditionalHarmonium f y g x z)
          = Dimension (Harmonium y g x) + Dimension (f (y,x) z)

instance ( Map Mean Natural f (y,x) z, Manifold (g y x)
         , Manifold (Harmonium y g x), Manifold y, Manifold x )
     => Map Mean Natural (ConditionalBiases f) (Harmonium y g x) z where
    {-# INLINE (>.>) #-}
    (>.>) pdhrm mzs =
        let (hrm,fyxz) = splitConditionalHarmonium pdhrm
            (ny,nyx,nx) = splitHarmonium hrm
            (ny',nx') = splitPair $ fyxz >.> mzs
         in joinHarmonium (ny + ny') nyx (nx + nx')
    {-# INLINE (>$>) #-}
    (>$>) pdhrm mzs =
        let (hrm,fyxz) = splitConditionalHarmonium pdhrm
            (ny,nyx,nx) = splitHarmonium hrm
            nyxs = fyxz >$> mzs
         in [ joinHarmonium (ny + ny') nyx (nx + nx') | (ny',nx') <- splitPair <$> nyxs ]

instance ( Propagate Mean Natural f (y,x) z, Manifold (Harmonium y g x)
         , Manifold y, Manifold x, Manifold (g y x) )
  => Propagate Mean Natural (ConditionalBiases f) (Harmonium y g x) z where
        {-# INLINE propagate #-}
        propagate dhrms mzs chrm =
            let (dys,_,dxs) = unzip3 $ splitHarmonium <$> dhrms
                (hrm,f) = splitConditionalHarmonium chrm
                (ny,nyx,nx) = splitHarmonium hrm
                (df,nyxs) = propagate (zipWith joinPair dys dxs) mzs f
             in ( joinConditionalHarmonium (average dhrms) df
                , [ joinHarmonium (ny + ny') nyx (nx + nx') | (ny',nx') <- splitPair <$> nyxs ] )

instance (Map Mean Natural f y z, Manifold (DeepHarmonium y gxs))
    => Manifold (ConditionalDeepHarmonium f y gxs z) where
        type Dimension (ConditionalDeepHarmonium f y gxs z)
          = Dimension (DeepHarmonium y gxs) + Dimension (f y z)

instance ( Map Mean Natural f y z, Manifold (DeepHarmonium y gxs) )
     => Map Mean Natural (ConditionalBias f) (DeepHarmonium y gxs) z where
    {-# INLINE (>.>) #-}
    (>.>) pdhrm q =
        let (dhrm,pq) = splitConditionalDeepHarmonium pdhrm
         in biasBottom (pq >.> q) dhrm
    {-# INLINE (>$>) #-}
    (>$>) pdhrm qs =
        let (dhrm,pq) = splitConditionalDeepHarmonium pdhrm
         in flip biasBottom dhrm <$> (pq >$> qs)

instance (Propagate Mean Natural f y z, Manifold (DeepHarmonium y gxs))
  => Propagate Mean Natural (ConditionalBias f) (DeepHarmonium y gxs) z where
        {-# INLINE propagate #-}
        propagate dhrms dzs chrm =
            let dys = getBottomBias <$> dhrms
                (hrm,f) = splitConditionalDeepHarmonium chrm
                (df,hrmhts) = propagate dys dzs f
             in (joinConditionalDeepHarmonium (average dhrms) df, flip biasBottom hrm <$> hrmhts)
