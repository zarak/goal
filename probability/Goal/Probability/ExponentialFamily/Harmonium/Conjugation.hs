{-# LANGUAGE
    DataKinds,
    TypeOperators,
    TypeFamilies,
    FlexibleContexts,
    ScopedTypeVariables,
    RankNTypes
    #-}
-- | Population codes and exponential families.
module Goal.Probability.ExponentialFamily.Harmonium.Conjugation
    (
    -- * Conjugation
      regressConjugationParameters
    , conjugationCurve
    , mixtureLikelihoodConjugationParameters
    ) where


--- Imports ---


-- Goal --

import Goal.Core
import Goal.Geometry

import qualified Goal.Core.Vector.Storable as S

import Goal.Probability.Statistical
import Goal.Probability.Distributions
import Goal.Probability.ExponentialFamily


--- Population Encoders ---


-- | Computes the conjugation parameters of a likelihood defined by a categorical latent variable.
mixtureLikelihoodConjugationParameters
    :: (KnownNat k, Enum e, Legendre Natural z)
    => Mean #> Natural # z <* Categorical e k -- ^ Categorical likelihood
    -> (Double, Natural # Categorical e k) -- ^ Conjugation parameters
{-# INLINE mixtureLikelihoodConjugationParameters #-}
mixtureLikelihoodConjugationParameters aff =
    let (nz,nzx) = splitAffine aff
        rho0 = potential nz
        rprms = S.map (\nzxi -> subtract rho0 . potential $ nz <+> Point nzxi) $ S.toColumns (toMatrix nzx)
     in (rho0, Point rprms)

-- Population Code Conjugation


-- | Computes the conjugation curve given a set of conjugation parameters,
-- at the given set of points.
conjugationCurve
    :: ExponentialFamily x
    => Double -- ^ Conjugation shift
    -> Natural # x -- ^ Conjugation parameters
    -> Sample x -- ^ Samples points
    -> [Double] -- ^ Conjugation curve at sample points
{-# INLINE conjugationCurve #-}
conjugationCurve rho0 rprms mus = (\x -> rprms <.> sufficientStatistic x + rho0) <$> mus

-- Linear Least Squares

-- | Returns the conjugation parameters which best satisfy the conjugation
-- equation for the given population code.
regressConjugationParameters
    :: (Map Mean Natural f z x, ExponentialFamily x, Legendre Natural z)
    => Mean #> Natural # f z x -- ^ PPC
    -> Sample x -- ^ Sample points
    -> (Double, Natural # x) -- ^ Approximate conjugation parameters
{-# INLINE regressConjugationParameters #-}
regressConjugationParameters lkl mus =
    let dpnds = potential <$> lkl >$>* mus
        indpnds = independentVariables0 lkl mus
        (rho0,rprms) = S.splitAt $ S.linearLeastSquares indpnds dpnds
     in (S.head rho0, Point rprms)

--- Internal ---

independentVariables0
    :: forall f x z
    . ExponentialFamily x
    => Mean #> Natural # f z x
    -> Sample x
    -> [S.Vector (Dimension x + 1) Double]
independentVariables0 _ mus =
    let sss :: [Mean # x]
        sss = sufficientStatistic <$> mus
     in (S.singleton 1 S.++) . coordinates <$> sss

