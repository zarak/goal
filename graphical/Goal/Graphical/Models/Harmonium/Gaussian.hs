{-# OPTIONS_GHC -fplugin=GHC.TypeLits.KnownNat.Solver -fplugin=GHC.TypeLits.Normalise -fconstraint-solver-iterations=10 #-}
{-# LANGUAGE
    TypeApplications,
    UndecidableInstances,
    NoStarIsType,
    GeneralizedNewtypeDeriving,
    StandaloneDeriving,
    ScopedTypeVariables,
    ExplicitNamespaces,
    TypeOperators,
    KindSignatures,
    DataKinds,
    RankNTypes,
    TypeFamilies,
    FlexibleContexts,
    MultiParamTypeClasses,
    ConstraintKinds,
    FlexibleInstances
#-}
-- | An Exponential Family 'Harmonium' is a product exponential family with a
-- particular bilinear structure (<https://papers.nips.cc/paper/2672-exponential-family-harmoniums-with-an-application-to-information-retrieval Welling, et al., 2005>).
-- A 'Mixture' model is a special case of harmonium. A 'FactorAnalysis' model
-- can also be interpreted as a 'Harmonium' with a fixed latent distribution.
module Goal.Graphical.Models.Harmonium.Gaussian
    (
    -- * Factor Analysis
      factorAnalysisObservableDistribution
    , factorAnalysisExpectationMaximization
    , factorAnalysisUniqueness
    -- * Principle Component Analysis
    , naturalPCAToLGH
    , pcaObservableDistribution
    , pcaExpectationMaximization
    ) where

--- Imports ---


import Goal.Core
import Goal.Geometry
import Goal.Probability

import Goal.Graphical.Models
import Goal.Graphical.Models.Harmonium

import qualified Goal.Core.Vector.Storable as S


--- Factor Analysis ---


type instance Observation (FactorAnalysis n k) = S.Vector n Double

factorAnalysisObservableDistribution
    :: (KnownNat n, KnownNat k)
    => Natural # FactorAnalysis n k
    -> Natural # MultivariateNormal n
factorAnalysisObservableDistribution =
     snd . splitConjugatedHarmonium . transposeHarmonium
     . naturalFactorAnalysisToLGH

factorAnalysisExpectationMaximization
    :: ( KnownNat n, KnownNat k)
    => [S.Vector n Double]
    -> Natural # FactorAnalysis n k
    -> Natural # FactorAnalysis n k
factorAnalysisExpectationMaximization zs fa =
    transition . sourceFactorAnalysisMaximizationStep . expectationStep zs
        $ naturalFactorAnalysisToLGH fa

factorAnalysisUniqueness
    :: (KnownNat n, KnownNat k)
    => Natural # FactorAnalysis n k
    -> S.Vector n Double
factorAnalysisUniqueness fa =
    let lds = toMatrix . snd . split $ toSource fa
        sgs = S.takeDiagonal . snd . splitMultivariateNormal . toSource
                $ factorAnalysisObservableDistribution fa
        cms = S.takeDiagonal . S.matrixMatrixMultiply lds $ S.transpose lds
     in (sgs - cms) / sgs

-- Internal --

naturalFactorAnalysisToLGH
    :: (KnownNat n, KnownNat k)
    => Natural # FactorAnalysis n k
    -> Natural # LinearGaussianHarmonium n k
naturalFactorAnalysisToLGH fa =
    let (nzs,tns) = split fa
        mvn = diagonalNormalToFull nzs
        fa' = join mvn tns
     in joinConjugatedHarmonium fa' $ toNatural . joinMultivariateNormal 0 $ S.diagonalMatrix 1

sourceFactorAnalysisMaximizationStep
    :: forall n k . (KnownNat n, KnownNat k)
    => Mean # LinearGaussianHarmonium n k
    -> Source # FactorAnalysis n k
sourceFactorAnalysisMaximizationStep hrm =
    let (mz,mzx,mx) = splitHarmonium hrm
        (muz,etaz) = splitMeanMultivariateNormal mz
        (mux,etax) = splitMeanMultivariateNormal mx
        outrs = toMatrix mzx - S.outerProduct muz mux
        wmtx = S.matrixMatrixMultiply outrs $ S.inverse etax
        zcvr = etaz - S.outerProduct muz muz
        vrs = S.takeDiagonal $ zcvr - S.matrixMatrixMultiply wmtx (S.transpose outrs)
        snrms = join (Point muz) $ Point vrs
     in join snrms $ fromMatrix wmtx


--- Principle Component Analysis ---


naturalPCAToIGH
    :: (KnownNat n, KnownNat k)
    => Natural # PrincipleComponentAnalysis n k
    -> Natural # IsotropicGaussianHarmonium n k
naturalPCAToIGH pca =
     joinConjugatedHarmonium pca $ toNatural . joinMultivariateNormal 0 $ S.diagonalMatrix 1

naturalPCAToLGH
    :: (KnownNat n, KnownNat k)
    => Natural # PrincipleComponentAnalysis n k
    -> Natural # LinearGaussianHarmonium n k
naturalPCAToLGH pca =
    let (iso,tns) = split pca
        (mus0,vr) = split iso
        mus = coordinates mus0
        sgma = S.diagonalMatrix . S.replicate . S.head $ coordinates vr
        mvn = joinNaturalMultivariateNormal mus sgma
        pca' = join mvn tns
     in joinConjugatedHarmonium pca' $ toNatural . joinMultivariateNormal 0 $ S.diagonalMatrix 1

pcaExpectationMaximization
    :: ( KnownNat n, KnownNat k)
    => [S.Vector n Double]
    -> Natural # PrincipleComponentAnalysis n k
    -> Natural # PrincipleComponentAnalysis n k
pcaExpectationMaximization zs pca =
    transition . sourcePCAMaximizationStep . expectationStep zs
        $ naturalPCAToIGH pca

sourcePCAMaximizationStep
    :: forall n k . (KnownNat n, KnownNat k)
    => Mean # IsotropicGaussianHarmonium n k
    -> Source # PrincipleComponentAnalysis n k
sourcePCAMaximizationStep hrm =
    let (mz,mzx,mx) = splitHarmonium hrm
        (muz0,etaz) = split mz
        (mux,etax) = splitMeanMultivariateNormal mx
        muz = coordinates muz0
        outrs = toMatrix mzx - S.outerProduct muz mux
        wmtx = S.matrixMatrixMultiply outrs $ S.inverse etax
        wmtxtr = S.transpose wmtx
        n = fromIntegral $ natVal (Proxy @n)
        ztr = S.head (coordinates etaz) - S.dotProduct muz muz
        vr = ztr - 2*S.trace (S.matrixMatrixMultiply wmtx $ S.transpose outrs)
            + S.trace (S.matrixMatrixMultiply (S.matrixMatrixMultiply wmtx etax) wmtxtr)
        iso = join (Point muz) $ singleton vr / n
     in join iso $ fromMatrix wmtx

--pcaExpectationMaximization'
--    :: ( KnownNat n, KnownNat k)
--    => [S.Vector n Double]
--    -> Natural # PrincipleComponentAnalysis n k
--    -> Natural # PrincipleComponentAnalysis n k
--pcaExpectationMaximization' zs pca =
--    transition . sourcePCAMaximizationStep' . expectationStep zs
--        $ naturalPCAToLGH pca

pcaObservableDistribution
    :: (KnownNat n, KnownNat k)
    => Natural # PrincipleComponentAnalysis n k
    -> Natural # MultivariateNormal n
pcaObservableDistribution =
     snd . splitConjugatedHarmonium . transposeHarmonium
     . naturalPCAToLGH


