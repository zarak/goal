-- | Definitions for working with exponential families.
module Goal.Probability.ExponentialFamily
    ( -- * Exponential Families
    ExponentialFamily (sufficientStatistic, baseMeasure)
    , ClosedFormExponentialFamily
    , sufficientStatisticT
    , unnormalizedDensity
    , exponentialFamilyDensity
    -- ** Coordinate Systems
    , Natural
    , Mean
    , Source
    -- ** Coordinate Transforms
    , toNatural
    , toMean
    , toSource
    -- ** Entropies
    , relativeEntropy
    , crossEntropy
    , stochasticCrossEntropy
    , stochasticConditionalCrossEntropy
    , estimateStochasticCrossEntropyDifferential
    , backpropagation
    -- ** Conditional Distributions
    , (>.>*)
    , (>$>*)
    , (>>.>*)
    , (>>$>*)
    , (*<.<)
    , (*<$<)
    ) where

--- Imports ---


-- Package --

import Goal.Probability.Statistical

import Goal.Core
import Goal.Geometry

import qualified Goal.Core.Vector.Boxed as B
import qualified Goal.Core.Vector.Generic as G

--- Exponential Families ---

-- Source Chart --

-- | A parameterization which represents the standard or typical parameterization of
-- the given manifold, e.g. the 'Poisson' rate or 'Normal' mean and standard deviation.
data Source


-- | A parameterization in terms of the natural coordinates of an exponential family.
data Natural

-- | A representation in terms of the mean sufficient statistics of an exponential family.
data Mean

instance Primal Natural where
    type Dual Natural = Mean

instance Primal Mean where
    type Dual Mean = Natural

toNatural :: (Transition c Natural m, RealFloat x) => Point c m x -> Point Natural m x
toNatural = transition

toMean :: (Transition c Mean m, RealFloat x) => Point c m x -> Point Mean m x
toMean = transition

toSource :: (Transition c Source m, RealFloat x) => Point c m x -> Point Source m x
toSource = transition


-- | A 'Statistical' 'Manifold' is a member of the 'ExponentialFamily' if we can
-- specify a 'sufficientStatistic' of fixed length, and a 'baseMeasure' which
-- fully determines the normalization of the distribution in exponential family
-- form.
--
-- 'ExponentialFamily' distributions theoretically have a 'Riemannian' geometry
-- given by the Fisher information metric, given rise to the 'Dual' coordinate
-- system given by the 'Natural' and 'Mean' coordinates. However, not all
-- distributions (e.g. the von Mises distribution) allow for closed form
-- expressions of the relevant structures, and so we define a distinct class for
-- this purpose.
class Statistical m => ExponentialFamily m where
    sufficientStatistic :: RealFloat x => Sample m -> Point Mean m x
    baseMeasure :: RealFloat x => Proxy m -> Sample m -> x

-- | When the 'Riemannian' properties of the given 'ExponentialFamily' may be
-- computed in closed-form, then we refer to it as a
-- 'ClosedFormExponentialFamily'.
type ClosedFormExponentialFamily m =
    ( ExponentialFamily m, Legendre Natural m, Legendre Mean m, AbsolutelyContinuous Natural m
    , Transition Natural Mean m, Transition Mean Natural m )

-- | The sufficient statistic of N iid random variables.
sufficientStatisticT
    :: (ExponentialFamily m, RealFloat x, Traversable t)
    => t (Sample m) -> Point Mean m x
{-# INLINE sufficientStatisticT #-}
sufficientStatisticT xs = averagePoint (sufficientStatistic <$> xs)

-- | A function for computing the relative entropy, also known as the KL-divergence.
relativeEntropy
    :: (ClosedFormExponentialFamily m, Transition c Mean m, Transition d Natural m, RealFloat x)
    => Point c m x -> Point d m x -> x
{-# INLINE relativeEntropy #-}
relativeEntropy p q = divergence (toMean p) (toNatural q)

-- | A function for computing the relative entropy, also known as the KL-divergence.
crossEntropy
    :: (ClosedFormExponentialFamily m, Transition c Mean m, Transition d Natural m, RealFloat x)
    => Point c m x -> Point d m x -> x
{-# INLINE crossEntropy #-}
crossEntropy p q =
    let mp = toMean p
        nq = toNatural q
     in potential nq - (mp <.> nq)

-- | A function for computing the relative entropy, also known as the KL-divergence.
estimateStochasticCrossEntropyDifferential0
    :: (Traversable t, ExponentialFamily m, RealFloat x)
    => t (Sample m) -- ^ True Samples
    -> t (Sample m) -- ^ Model Samples
    -> Point Mean m x -- ^ Differential Estimate
{-# INLINE estimateStochasticCrossEntropyDifferential0 #-}
estimateStochasticCrossEntropyDifferential0 pxs qxs =
    sufficientStatisticT qxs <-> sufficientStatisticT pxs

-- | A function for computing the relative entropy, also known as the KL-divergence.
estimateStochasticCrossEntropyDifferential1
    :: (ExponentialFamily m)
    => Point Mean m x -- ^ Differential Estimate
    -> CotangentVector Natural m x -- ^ Differential Estimate
{-# INLINE estimateStochasticCrossEntropyDifferential1 #-}
estimateStochasticCrossEntropyDifferential1 = Point . coordinates

-- | A function for computing the relative entropy, also known as the KL-divergence.
estimateStochasticCrossEntropyDifferential
    :: (Traversable t, ExponentialFamily m, RealFloat x)
    => t (Sample m) -- ^ True Samples
    -> t (Sample m) -- ^ Model Samples
    -> CotangentVector Natural m x -- ^ Differential Estimate
{-# INLINE estimateStochasticCrossEntropyDifferential #-}
estimateStochasticCrossEntropyDifferential pxs qxs =
    estimateStochasticCrossEntropyDifferential1 $ estimateStochasticCrossEntropyDifferential0 pxs qxs

-- | A function for computing the relative entropy, also known as the KL-divergence.
stochasticCrossEntropy
    :: (Traversable t, ClosedFormExponentialFamily m, RealFloat x)
    => t (Sample m) -> Point Natural m x -> x
{-# INLINE stochasticCrossEntropy #-}
stochasticCrossEntropy xs nq =
    let mp = sufficientStatisticT xs
     in potential nq - (mp <.> nq)

-- | A function for computing the relative entropy, also known as the KL-divergence.
stochasticConditionalCrossEntropy
    :: (KnownNat k, Apply Mean Natural f, ExponentialFamily (Domain f), ClosedFormExponentialFamily (Codomain f), RealFloat x)
    => B.Vector k (Sample (Domain f))
    -> B.Vector k (Sample (Codomain f))
    -> Point (Mean ~> Natural) f x
    -> x
{-# INLINE stochasticConditionalCrossEntropy #-}
stochasticConditionalCrossEntropy xs ys f =
    average . B.zipWith stochasticCrossEntropy (B.singleton <$> ys) $ f >$>* xs

-- | A function for computing the relative entropy, also known as the KL-divergence.
backpropagation
    :: ( Propagate Mean Natural f
       , ExponentialFamily (Domain f)
       , ClosedFormExponentialFamily (Codomain f)
       , KnownNat k)
    => B.Vector k (Sample (Domain f))
    -> B.Vector k (Sample (Codomain f))
    -> Mean ~> Natural # f
    -> CotangentVector (Mean ~> Natural) f Double
{-# INLINE backpropagation #-}
backpropagation xs ys f =
    let (df,yhts) = propagate mys (sufficientStatistic <$> xs) f
        mys = B.zipWith differentiator ys yhts
     in primalIsomorphism df
        where differentiator y yht =
                  dualIsomorphism $ differential (stochasticCrossEntropy $ B.singleton y) yht

unnormalizedDensity :: forall m x. (ExponentialFamily m, RealFloat x) => Point Natural m x -> Sample m -> x
unnormalizedDensity p x =
    exp (p <.> sufficientStatistic x) * baseMeasure (Proxy :: Proxy m) x

exponentialFamilyDensity
    :: (ExponentialFamily m, Legendre Natural m, RealFloat x)
    => Point Natural m x -> Sample m -> x
{-# INLINE exponentialFamilyDensity #-}
exponentialFamilyDensity p x = unnormalizedDensity p x * (exp . negate $ potential p)

replicatedBaseMeasure0 :: (ExponentialFamily m, Storable (Sample m), KnownNat k, RealFloat x)
                       => Proxy m -> Proxy (Replicated k m) -> B.Vector k (Sample m) -> x
{-# INLINE replicatedBaseMeasure0  #-}
replicatedBaseMeasure0 prxym _ xs = B.sum $ B.map (baseMeasure prxym) xs

sumBaseMeasure0
    :: (ExponentialFamily m, ExponentialFamily n, RealFloat x)
    => Proxy m
    -> Proxy n
    -> Proxy (Sum m n)
    -> (Sample m, Sample n)
    -> x
{-# INLINE sumBaseMeasure0  #-}
sumBaseMeasure0 prxym prxyn _ (xm,xn) = baseMeasure prxym xm * baseMeasure prxyn xn


--- Conditional Distributions ---


-- | Applies the given conditional distribution to a sample from the 'SampleSpace' of the 'Domain'.
(>>.>*) :: (Apply Mean c m, ExponentialFamily (Domain m))
        => (Mean ~> c) # m
        -> Sample (Domain m)
        -> c # Codomain m
{-# INLINE (>>.>*) #-}
(>>.>*) p x = p >>.> sufficientStatistic x

-- | Mapped application on samples.
(>>$>*) :: (Apply Mean c m, ExponentialFamily (Domain m), KnownNat k)
        => Mean ~> c # m
        -> B.Vector k (Sample (Domain m))
        -> B.Vector k (c # Codomain m)
{-# INLINE (>>$>*) #-}
(>>$>*) p xs = p >>$> G.map sufficientStatistic xs

infix 8 >>.>*
infix 8 >>$>*

-- | Applies the given conditional distribution to a sample from the 'SampleSpace' of the 'Domain'.
(>.>*) :: (Apply Mean c m, ExponentialFamily (Domain m), RealFloat x)
       => Point (Mean ~> c) m x
       -> Sample (Domain m)
       -> Point c (Codomain m) x
{-# INLINE (>.>*) #-}
(>.>*) p x = p >.> sufficientStatistic x

-- | Mapped application on samples.
(>$>*) :: (Apply Mean c m, ExponentialFamily (Domain m), KnownNat k, RealFloat x)
       => Point (Mean ~> c) m x
       -> B.Vector k (Sample (Domain m))
       -> B.Vector k (Point c (Codomain m) x)
{-# INLINE (>$>*) #-}
(>$>*) p xs = p >$> G.map sufficientStatistic xs

infix 8 >.>*
infix 8 >$>*

-- | Applies the given conditional distribution to a sample from the 'SampleSpace' of the 'Domain'.
(*<.<) :: (Bilinear Mean Natural f, ExponentialFamily (Codomain f), RealFloat x)
       => Sample (Codomain f)
       -> Point (Function Mean Natural) f x
       -> Point Natural (Domain f) x
{-# INLINE (*<.<) #-}
(*<.<) x p = sufficientStatistic x <.< p

-- | Mapped application on samples.
(*<$<) :: (Bilinear Mean Natural f, ExponentialFamily (Codomain f), KnownNat k, RealFloat x)
       => B.Vector k (Sample (Codomain f))
       -> Point (Function Mean Natural) f x
       -> B.Vector k (Point Natural (Domain f) x)
{-# INLINE (*<$<) #-}
(*<$<) xs p = G.map sufficientStatistic xs <$< p

infix 8 *<.<
infix 8 *<$<



--- Instances ---


-- Transitions --

instance Legendre Mean m => Transition Mean Natural m where
    {-# INLINE transition #-}
    transition = dualTransition

instance Legendre Natural m => Transition Natural Mean m where
    {-# INLINE transition #-}
    transition = dualTransition


-- Replicated --

instance (Legendre Natural m, Riemannian Natural m, KnownNat k) => Riemannian Natural (Replicated k m) where
    {-# INLINE metric #-}
    metric = hessian potential
    {-# INLINE flat #-}
    flat = replicatedJoinTangentPair . G.map flat . replicatedSplitTangentPair
    {-# INLINE sharp #-}
    sharp = replicatedJoinTangentPair . G.map sharp . replicatedSplitTangentPair

instance (ExponentialFamily m, ExponentialFamily n) => ExponentialFamily (Sum m n) where
    {-# INLINE sufficientStatistic #-}
    sufficientStatistic (xm,xn) = joinSum (sufficientStatistic xm) (sufficientStatistic xn)
    {-# INLINE baseMeasure #-}
    baseMeasure = sumBaseMeasure0 Proxy Proxy

instance (ExponentialFamily m, Storable (Sample m), KnownNat k) => ExponentialFamily (Replicated k m) where
    {-# INLINE sufficientStatistic #-}
    sufficientStatistic xs = joinReplicated $ G.map sufficientStatistic xs
    {-# INLINE baseMeasure #-}
    baseMeasure = replicatedBaseMeasure0 Proxy

instance (Manifold m, Manifold n, Transition Natural Source m, Transition Natural Source n) => Transition Natural Source (Sum m n) where
    {-# INLINE transition #-}
    transition pmn =
        let (pm,pn) = splitSum pmn
         in joinSum (transition pm) (transition pn)
