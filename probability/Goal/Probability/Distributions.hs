{-# LANGUAGE UndecidableInstances #-}

-- | Various instances of statistical manifolds, with a focus on exponential families.
module Goal.Probability.Distributions
    ( -- * Exponential Families
      --Uniform
      Bernoulli
    , Binomial
    , binomialTrials
    , Categorical
    , categories
    , Poisson
    , Normal
    , MeanNormal
    , meanNormalVariance
    , VonMises
    ) where

-- Package --

import Goal.Core
import Goal.Probability.Statistical
import Goal.Probability.ExponentialFamily

import Goal.Geometry
import System.Random.MWC.Probability hiding (sample)

import qualified Goal.Core.Vector.Storable as S
import qualified Goal.Core.Vector.Boxed as B
import qualified Goal.Core.Vector.Generic as G

-- Uniform --

-- | A 'Uniform' distribution on a specified interval of the real line. This
-- distribution does not have interesting geometric properties, and does not
-- have coordinates.
--data Uniform mn mx

-- Bernoulli Distribution --

-- | The Bernoulli 'Family' with 'SampleSpace' 'Bernoulli' = 'Bool' (because why not).
data Bernoulli

-- Binomial Distribution --

-- | Models a number of coin flips, with a probability of tails given
-- by the parameter of the family.
data Binomial (n :: Nat)

binomialTrials :: forall c n. KnownNat n => Point c (Binomial n) -> Int
binomialTrials _ = natValInt (Proxy :: Proxy n)

categories :: (1 <= n, KnownNat n, Enum e) => Point c (Categorical e n) -> B.Vector n e
categories = categories0 Proxy

-- Categorical Distribution --

-- | A 'Categorical' distribution where the probability of the last category is
-- given by the normalization constraint.
data Categorical e (n :: Nat)

-- | Takes a weighted list of elements representing a probability mass function, and
-- returns a sample from the Categorical distribution.
sampleCategorical :: (Enum a, KnownNat n) => S.Vector n Double -> Random s a
sampleCategorical ps = do
    let ps' = S.scanl' (+) 0 ps
    p <- uniform
    let ma = subtract 1 . finiteInt <$> S.findIndex (> p) ps'
    return . toEnum $ fromMaybe (S.length ps) ma

-- Curved Categorical Distribution --

-- | A 'CurvedCategorical' distribution is a 'Categorical' distribution where
-- each probability is explicitly represented.
--data CurvedCategorical s

-- Poisson Distribution --

-- | Returns a sample from a Poisson distribution with the given rate.
samplePoisson :: Double -> Random s Int
samplePoisson lmda = uniform >>= renew 0
    where l = exp (-lmda)
          renew k p
            | p <= l = return k
            | otherwise = do
                u <- uniform
                renew (k+1) (p*u)

-- | The 'Manifold' of 'Poisson' distributions. The 'Source' coordinate is the
-- rate of the Poisson distribution.
data Poisson

-- Normal Distribution --

-- | The 'Manifold' of 'Normal' distributions. The standard coordinates are the
-- mean and the variance.
data Normal

-- MeanNormal Distribution --

-- | The 'Manifold' of 'Normal' distributions with known variance. The standard
-- coordinate is simply the mean.
data MeanNormal v

meanNormalVariance :: forall n d c. (KnownNat n, KnownNat d)
                   => Point c (MeanNormal (n/d)) -> Rational
meanNormalVariance _ = ratVal (Proxy :: Proxy (n/d))


-- Multivariate Normal --

-- | The 'Manifold' of 'MultivariateNormal' distributions. The standard coordinates are the
-- (vector) mean and the covariance matrix. When building a multivariate normal
-- distribution using e.g. 'fromList', the elements of the mean come first, and
-- then the elements of the covariance matrix in row major order.
--data MultivariateNormal (n :: Nat)
--
--splitMultivariateNormal :: KnownNat n => Point c (MultivariateNormal n) x -> (B.Vector n x, Matrix n n x)
--splitMultivariateNormal (Point xs) =
--    let (mus,cvrs) = G.splitAt xs
--     in (mus,Matrix cvrs)
--
{-
-- | Samples from a multivariate Normal.
sampleMultivariateNormal :: C.Vector Double -> M.Matrix Double -> RandST s (C.Vector Double)
sampleMultivariateNormal mus rtsgma = do
    nrms <- C.replicateM n $ normal 0 1
    return $ mus + (M.#>) rtsgma nrms
    where n = C.length mus

-- | samples a multivariateNormal by way of a covariance matrix i.e. by taking
-- the square root.
joinMultivariateNormal :: C.Vector Double -> M.Matrix Double -> c :#: MultivariateNormal
joinMultivariateNormal mus sgma =
    fromCoordinates (MultivariateNormal $ C.length mus) $ mus C.++ M.flatten sgma

     -}

-- von Mises --

-- | The 'Manifold' of 'VonMises' distributions. The 'Source' coordinates are
-- the mean and concentration.
data VonMises




--- Internal ---

categories0 :: (1 <= n, KnownNat n, Enum e)
            => Proxy (Categorical e n) -> Point c (Categorical e n) -> B.Vector n e
categories0 prxy _ = sampleSpace prxy

binomialBaseMeasure0 :: (KnownNat n) => Proxy n -> Proxy (Binomial n) -> Sample (Binomial n) -> Double
binomialBaseMeasure0 prxyn _ = realToFrac . choose (natValInt prxyn)

meanNormalBaseMeasure0 :: (KnownNat n, KnownNat d) => Proxy (n/d) -> Proxy (MeanNormal (n/d)) -> Sample (MeanNormal (n/d)) -> Double
meanNormalBaseMeasure0 prxyr _ x =
    let vr = realToFrac $ ratVal prxyr
     in (exp . negate $ 0.5 * x^(2 :: Int) / vr) / sqrt (2*pi*vr)

--sampleUniform
--    :: forall mnn mnd mxn mxd s x.
--    (KnownNat mnn, KnownNat mnd, KnownNat mxn, KnownNat mxd)
--    => Point Source (Uniform (mnn/mnd) (mxn/mxd)) x
--    -> Random s Double
--sampleUniform _ = uniformR (realToFrac $ ratVal (Proxy :: Proxy (mnn/mnd)), realToFrac $ ratVal (Proxy :: Proxy (mxn/mxd)))
--

--multivariateNormalBaseMeasure0 :: (KnownNat n) => Proxy n -> Proxy (MultivariateNormal n) -> B.Vector n Double -> x
--multivariateNormalBaseMeasure0 prxyn _ _ =
--    let n = natValInt prxyn
--     in (2*pi)**(-fromIntegral n/2)

--- Instances ---


-- Uniform --

--instance (KnownNat mnn, KnownNat mnd, KnownNat mxn, KnownNat mxd) => Manifold (Uniform (mnn/mnd) (mxn/mxd)) where
--    type Dimension (Uniform (mnn/mnd) (mxn/mxd)) = 0
--
--instance (KnownNat mnn, KnownNat mnd, KnownNat mxn, KnownNat mxd) => Statistical (Uniform (mnn/mnd) (mxn/mxd)) where
--    type Sample (Uniform (mnn/mnd) (mxn/mxd)) = Double
--
--instance (KnownNat mnn, KnownNat mnd, KnownNat mxn, KnownNat mxd) => Generative Source (Uniform (mnn/mnd) (mxn/mxd)) where
--    sample = sampleUniform

-- Bernoulli Distribution --

instance Manifold Bernoulli where
    type Dimension Bernoulli = 1

instance Statistical Bernoulli where
    type Sample Bernoulli = Bool

instance Discrete Bernoulli where
    type Cardinality Bernoulli = 2
    sampleSpace _ = G.doubleton True False

instance ExponentialFamily Bernoulli where
    baseMeasure _ _ = 1
    {-# INLINE sufficientStatistic #-}
    sufficientStatistic True = Point $ G.singleton 1
    sufficientStatistic False = Point $ G.singleton 0

instance Legendre Natural Bernoulli where
    {-# INLINE potential #-}
    potential p = log $ 1 + exp (G.head $ coordinates p)
    {-# INLINE potentialDifferential #-}
    potentialDifferential = Point . S.map logistic . coordinates

instance Legendre Mean Bernoulli where
    {-# INLINE potential #-}
    potential p =
        let eta = G.head $ coordinates p
         in logit eta * eta - log (1 / (1 - eta))
    {-# INLINE potentialDifferential #-}
    potentialDifferential = Point . S.map logit . coordinates

instance Riemannian Natural Bernoulli where
    {-# INLINE metric #-}
    metric p =
        let stht = logistic . S.head $ coordinates p
         in Point . S.singleton $ stht * (1-stht)

--instance Riemannian Natural Bernoulli where
--    {-# INLINE metric #-}
--    metric = hessian potential
--
--instance Riemannian Mean Bernoulli where
--    {-# INLINE metric #-}
--    metric = hessian potential

instance Transition Source Mean Bernoulli where
    {-# INLINE transition #-}
    transition = breakChart

instance Transition Mean Source Bernoulli where
    {-# INLINE transition #-}
    transition = breakChart

instance Transition Source Natural Bernoulli where
    {-# INLINE transition #-}
    transition = dualTransition . toMean

instance Transition Natural Source Bernoulli where
    {-# INLINE transition #-}
    transition = transition . dualTransition

instance (Transition c Source Bernoulli) => Generative c Bernoulli where
    {-# INLINE sample #-}
    sample = bernoulli . G.head . coordinates . toSource

instance Transition Mean c Bernoulli => MaximumLikelihood c Bernoulli where
    mle = transition . sufficientStatisticT

instance AbsolutelyContinuous Source Bernoulli where
    density (Point p) True = G.head p
    density (Point p) False = 1 - G.head p

instance AbsolutelyContinuous Mean Bernoulli where
    density = density . toSource

instance AbsolutelyContinuous Natural Bernoulli where
    density = exponentialFamilyDensity


-- Binomial Distribution --

instance KnownNat n => Manifold (Binomial n) where
    type Dimension (Binomial n) = 1

instance KnownNat n => Statistical (Binomial n) where
    type Sample (Binomial n) = Int

instance KnownNat n => Discrete (Binomial n) where
    type Cardinality (Binomial n) = n + 1
    sampleSpace _ = G.generate finiteInt

instance KnownNat n => ExponentialFamily (Binomial n) where
    baseMeasure = binomialBaseMeasure0 Proxy
    {-# INLINE sufficientStatistic #-}
    sufficientStatistic = Point . G.singleton . fromIntegral

instance KnownNat n => Legendre Natural (Binomial n) where
    {-# INLINE potential #-}
    potential p =
        let n = fromIntegral $ binomialTrials p
            tht = G.head $ coordinates p
         in n * log (1 + exp tht)
    {-# INLINE potentialDifferential #-}
    potentialDifferential p =
        let n = fromIntegral $ binomialTrials p
         in Point . S.singleton $ n * logistic (S.head $ coordinates p)

instance KnownNat n => Legendre Mean (Binomial n) where
    {-# INLINE potential #-}
    potential p =
        let n = fromIntegral $ binomialTrials p
            eta = G.head $ coordinates p
        in eta * log (eta / (n - eta)) - n * log (n / (n - eta))
    {-# INLINE potentialDifferential #-}
    potentialDifferential p =
        let n = fromIntegral $ binomialTrials p
            eta = S.head $ coordinates p
         in Point . S.singleton . log $ eta / (n - eta)


instance KnownNat n => Transition Source Natural (Binomial n) where
    transition = dualTransition . toMean

instance KnownNat n => Transition Natural Source (Binomial n) where
    transition = transition . dualTransition

instance KnownNat n => Transition Source Mean (Binomial n) where
    transition p =
        let n = fromIntegral $ binomialTrials p
         in breakChart $ n .> p

instance KnownNat n => Transition Mean Source (Binomial n) where
    transition p =
        let n = fromIntegral $ binomialTrials p
         in breakChart $ n /> p


instance (KnownNat n, Transition c Source (Binomial n)) => Generative c (Binomial n) where
    sample p0 = do
        let p = toSource p0
            n = binomialTrials p
        bls <- replicateM n . bernoulli . realToFrac . G.head $ coordinates p
        return $ sum [ if bl then 1 else 0 | bl <- bls ]

instance KnownNat n => AbsolutelyContinuous Source (Binomial n) where
    density p k =
        let n = binomialTrials p
            c = G.head $ coordinates p
         in realToFrac (choose n k) * c^k * (1 - c)^(n-k)

instance KnownNat n => AbsolutelyContinuous Mean (Binomial n) where
    density = density . toSource

instance KnownNat n => AbsolutelyContinuous Natural (Binomial n) where
    density = exponentialFamilyDensity

instance (KnownNat n, Transition Mean c (Binomial n)) => MaximumLikelihood c (Binomial n) where
    mle = transition . sufficientStatisticT

-- Categorical Distribution --

instance (KnownNat n, 1 <= n) => Manifold (Categorical e n) where
    type Dimension (Categorical e n) = n - 1

instance (KnownNat n, 1 <= n) => Statistical (Categorical e n) where
    type Sample (Categorical e n) = e

instance (Enum e, KnownNat n, 1 <= n) => Discrete (Categorical e n) where
    type Cardinality (Categorical e n) = n
    sampleSpace _ = G.generate (toEnum . finiteInt)

instance (Enum e, KnownNat n, 1 <= n) => ExponentialFamily (Categorical e n) where
    baseMeasure _ _ = 1
    {-# INLINE sufficientStatistic #-}
    sufficientStatistic k = Point $ G.generate (\i -> if finiteInt i == fromEnum k then 1 else 0)

instance (Enum e, KnownNat n, 1 <= n) => Legendre Natural (Categorical e n) where
    {-# INLINE potential #-}
    potential (Point cs) = log $ 1 + S.sum (S.map exp cs)
    {-# INLINE potentialDifferential #-}
    potentialDifferential p =
        let exps = S.map exp $ coordinates p
            nrm = 1 + S.sum exps
         in nrm /> Point exps


instance (Enum e, KnownNat n, 1 <= n) => Legendre Mean (Categorical e n) where
    {-# INLINE potential #-}
    potential (Point cs) =
        let scs = 1 - S.sum cs
         in S.sum (S.zipWith (*) cs $ S.map log cs) + scs * log scs
    {-# INLINE potentialDifferential #-}
    potentialDifferential (Point xs) =
        let nrm = 1 - S.sum xs
         in  Point . log $ S.map (/nrm) xs


instance Transition Source Mean (Categorical e n) where
    transition = breakChart

instance Transition Mean Source (Categorical e n) where
    transition = breakChart

instance (Enum e, KnownNat n, 1 <= n) => Transition Source Natural (Categorical e n) where
    transition = dualTransition . toMean

instance (Enum e, KnownNat n, 1 <= n) => Transition Natural Source (Categorical e n) where
    transition = transition . dualTransition

instance (Enum e, KnownNat n, 1 <= n, Transition c Source (Categorical e n))
  => Generative c (Categorical e n) where
    sample p0 =
        let p = toSource p0
         in sampleCategorical $ coordinates p

instance (KnownNat n, 1 <= n, Enum e, Transition Mean c (Categorical e n)) => MaximumLikelihood c (Categorical e n) where
    mle = transition . sufficientStatisticT

instance (Enum e, KnownNat n, 1 <= n) => AbsolutelyContinuous Source (Categorical e n) where
    density (Point ps) e =
        let mk = packFinite . toInteger $ fromEnum e
            mp = G.index ps <$> mk
         in fromMaybe (1 - S.sum ps) mp

instance (KnownNat n, 1 <= n, Enum e) => AbsolutelyContinuous Mean (Categorical e n) where
    density = density . toSource

instance (KnownNat n, 1 <= n, Enum e) => AbsolutelyContinuous Natural (Categorical e n) where
    density = exponentialFamilyDensity


{-

-- Curved Categorical Distribution --

instance Finite s => Manifold (CurvedCategorical s) where
    dimension = length . samples

instance Finite s => Statistical (CurvedCategorical s) where
    type SampleSpace (CurvedCategorical s) = s
    sampleSpace (CurvedCategorical s) = s

instance Finite s => Generative Source (CurvedCategorical s) where
    sample p = sampleCategorical (samples $ manifold p) (coordinates p)

instance Finite s => AbsolutelyContinuous Source (CurvedCategorical s) where
    density p k = cs C.! idx
          where ks = samples $ manifold p
                cs = coordinates p
                idx = fromMaybe (error "attempted to calculate density of non-categorical element")
                    $ elemIndex k ks
                    -}

-- Poisson Distribution --

instance Manifold Poisson where
    type Dimension Poisson = 1

instance Statistical Poisson where
    type Sample Poisson = Int

instance ExponentialFamily Poisson where
    {-# INLINE sufficientStatistic #-}
    sufficientStatistic = Point . G.singleton . fromIntegral
    baseMeasure _ k = recip . realToFrac $ factorial k

instance Legendre Natural Poisson where
    {-# INLINE potential #-}
    potential = exp . G.head . coordinates
    {-# INLINE potentialDifferential #-}
    potentialDifferential = Point . exp . coordinates

instance Legendre Mean Poisson where
    {-# INLINE potential #-}
    potential (Point xs) =
        let eta = G.head xs
         in eta * log eta - eta
    {-# INLINE potentialDifferential #-}
    potentialDifferential = Point . log . coordinates

instance Transition Source Natural Poisson where
    transition = transition . toMean

instance Transition Natural Source Poisson where
    transition = transition . dualTransition

instance Transition Source Mean Poisson where
    transition = breakChart

instance Transition Mean Source Poisson where
    transition = breakChart

instance (Transition c Source Poisson) => Generative c Poisson where
    sample = samplePoisson . G.head . coordinates . toSource

instance AbsolutelyContinuous Source Poisson where
    density (Point xs) k =
        let lmda = G.head xs
         in  lmda^k / realToFrac (factorial k) * exp (-lmda)

instance AbsolutelyContinuous Mean Poisson where
    density = density . toSource

instance AbsolutelyContinuous Natural Poisson where
    density = exponentialFamilyDensity

instance Transition Mean c Poisson => MaximumLikelihood c Poisson where
    mle = transition . sufficientStatisticT

-- Normal Distribution --

instance Manifold Normal where
    type Dimension Normal = 2

instance Statistical Normal where
    type Sample Normal = Double

instance ExponentialFamily Normal where
    {-# INLINE sufficientStatistic #-}
    sufficientStatistic x = Point . G.doubleton x $ x**2
    baseMeasure _ _ = recip . sqrt $ 2 * pi

instance Legendre Natural Normal where
    {-# INLINE potential #-}
    potential (Point cs) =
        let (tht0,tht1) = G.toPair cs
         in -(tht0^(2 :: Int) / (4*tht1)) - 0.5 * log(-2*tht1)
    {-# INLINE potentialDifferential #-}
    potentialDifferential p =
        let (tht0,tht1) = S.toPair $ coordinates p
            dv = tht0/tht1
         in Point $ S.doubleton (-0.5*dv) (0.25 * dv^(2 :: Int) - 0.5/tht1)

instance Legendre Mean Normal where
    {-# INLINE potential #-}
    potential (Point cs) =
        let (eta0,eta1) = G.toPair cs
         in -0.5 * log(eta1 - eta0^(2 :: Int)) - 1/2
    {-# INLINE potentialDifferential #-}
    potentialDifferential p =
        let (eta0,eta1) = S.toPair $ coordinates p
            dff = eta0^(2 :: Int) - eta1
         in Point $ S.doubleton (-eta0 / dff) (0.5 / dff)


--instance Riemannian Natural Normal where
--    metric = hessian potential
--
--instance Riemannian Mean Normal where
--    metric = hessian potential

instance Transition Source Mean Normal where
    transition (Point cs) =
        let (mu,vr) = G.toPair cs
         in Point . G.doubleton mu $ vr + mu^(2 :: Int)

instance Transition Mean Source Normal where
    transition (Point cs) =
        let (eta0,eta1) = G.toPair cs
         in Point . G.doubleton eta0 $ eta1 - eta0^(2 :: Int)

instance Transition Source Natural Normal where
    transition (Point cs) =
        let (mu,vr) = G.toPair cs
         in Point $ G.doubleton (mu / vr) (negate . recip $ 2 * vr)

instance Transition Natural Source Normal where
    transition (Point cs) =
        let (tht0,tht1) = G.toPair cs
         in Point $ G.doubleton (-0.5 * tht0 / tht1) (negate . recip $ 2 * tht1)

instance (Transition c Source Normal) => Generative c Normal where
    sample p =
        let (Point cs) = toSource p
            (mu,vr) = G.toPair cs
         in normal mu (sqrt vr)

instance AbsolutelyContinuous Source Normal where
    density (Point cs) x =
        let (mu,vr) = G.toPair cs
         in recip (sqrt $ vr*2*pi) * exp (negate $ (x - mu) ** 2 / (2*vr))

instance AbsolutelyContinuous Mean Normal where
    density = density . toSource

instance AbsolutelyContinuous Natural Normal where
    density = exponentialFamilyDensity

instance Transition Mean c Normal => MaximumLikelihood c Normal where
    mle = transition . sufficientStatisticT


{-
instance Riemannian Source Normal where
    metric (Point xs) =
         in  [recip vr,0,0,recip $ 2*vr^2]
         -}

-- MeanNormal Distribution --

instance Manifold (MeanNormal v) where
    type Dimension (MeanNormal v) = 1

instance Statistical (MeanNormal v) where
    type Sample (MeanNormal v) = Double

instance (KnownNat n, KnownNat d) => ExponentialFamily (MeanNormal (n / d)) where
    {-# INLINE sufficientStatistic #-}
    sufficientStatistic x = Point $ G.singleton x
    baseMeasure = meanNormalBaseMeasure0 Proxy

instance (KnownNat n, KnownNat d) => Legendre Natural (MeanNormal (n/d)) where
    {-# INLINE potential #-}
    potential p =
        let vr = realToFrac $ meanNormalVariance p
            mu = G.head $ coordinates p
         in 0.5 * vr * mu^(2 :: Int)
    {-# INLINE potentialDifferential #-}
    potentialDifferential p =
        let vr = realToFrac $ meanNormalVariance p
         in Point . S.singleton $ vr * S.head (coordinates p)


instance (KnownNat n, KnownNat d) => Legendre Mean (MeanNormal (n/d)) where
    {-# INLINE potential #-}
    potential p =
        let vr = realToFrac $ meanNormalVariance p
            mu = G.head $ coordinates p
         in 0.5 / vr * mu^(2 :: Int)
    {-# INLINE potentialDifferential #-}
    potentialDifferential p =
        let vr = realToFrac $ meanNormalVariance p
         in Point . S.singleton $ S.head (coordinates p) / vr


instance Transition Source Mean (MeanNormal v) where
    transition = breakChart

instance Transition Mean Source (MeanNormal v) where
    transition = breakChart

instance (KnownNat n, KnownNat d) => Transition Source Natural (MeanNormal (n/d)) where
    transition = dualTransition . toMean

instance (KnownNat n, KnownNat d) => Transition Natural Source (MeanNormal (n/d)) where
    transition = toSource . dualTransition

instance (KnownNat n, KnownNat d) => AbsolutelyContinuous Source (MeanNormal (n/d)) where
    density p =
        let vr = realToFrac $ meanNormalVariance p
            mu = G.head $ coordinates p
            nrm :: Double -> Double -> Point Source Normal
            nrm x y = Point $ G.doubleton x y
         in density $ nrm mu vr

instance (KnownNat n, KnownNat d) => AbsolutelyContinuous Mean (MeanNormal (n/d)) where
    density = density . toSource

instance (KnownNat n, KnownNat d) => AbsolutelyContinuous Natural (MeanNormal (n/d)) where
    density = exponentialFamilyDensity

instance (KnownNat n, KnownNat d, Transition Mean c (MeanNormal (n/d))) => MaximumLikelihood c (MeanNormal (n/d)) where
    mle = transition . sufficientStatisticT

instance (KnownNat n, KnownNat d, Transition c Source (MeanNormal (n/d))) => Generative c (MeanNormal (n/d)) where
    sample p =
        let (Point cs) = toSource p
            mu = G.head cs
            vr = realToFrac $ meanNormalVariance p
         in normal mu (sqrt vr)

-- Multivariate Normal --

--instance KnownNat n => Manifold (MultivariateNormal n) where
--    type Dimension (MultivariateNormal n) = n + n * n
--
--instance KnownNat n => Statistical (MultivariateNormal n) where
--    type Sample (MultivariateNormal n) = B.Vector n Double
--
--instance KnownNat n => ExponentialFamily (MultivariateNormal n) where
--    {-# INLINE sufficientStatistic #-}
--    sufficientStatistic xs =
--        let Matrix cvrs = matrixMatrixMultiply (columnVector xs) (rowVector xs)
--         in fmap realToFrac . Point $ joinV xs cvrs
--    baseMeasure = multivariateNormalBaseMeasure0 Proxy

{-
instance Legendre Natural MultivariateNormal where
    potential p =
        let (tmu,tsgma) = splitMultivariateNormal p
            invtsgma = matrixInverse tsgma
         in -0.25 * dotProduct tmu (matrixVectorMultiply invtsgma tmu) - 0.5 * log(M.det $ M.scale (-2) tsgma)

instance Legendre Mean MultivariateNormal where
    potential p =
        let (mmu,msgma) = splitMultivariateNormal p
         in -0.5 * (1 + M.dot mmu (M.pinv msgma M.#> mmu)) - 0.5 * log (M.det msgma)

instance Transition Source Natural MultivariateNormal where
    transition p =
        let (mu,sgma) = splitMultivariateNormal p
            invsgma = M.pinv sgma
         in fromCoordinates (manifold p) $ (invsgma M.#> mu) C.++ M.flatten (M.scale (-0.5) invsgma)

instance Transition Natural Source MultivariateNormal where
    transition p =
        let (emu,esgma) = splitMultivariateNormal p
            invesgma = M.scale (-0.5) $ M.pinv esgma
         in fromCoordinates (manifold p) $ (invesgma M.#> emu) C.++ M.flatten invesgma

instance Transition Source Mean MultivariateNormal where
    transition p =
        let (mu,sgma) = splitMultivariateNormal p
         in fromCoordinates (manifold p) $ mu C.++ M.flatten (sgma + M.outer mu mu)

instance Transition Mean Source MultivariateNormal where
    transition p =
        let (mmu,msgma) = splitMultivariateNormal p
         in fromCoordinates (manifold p) $ mmu C.++ M.flatten (msgma -M.outer mmu mmu)

instance Generative Source MultivariateNormal where
    sample p =
        let n = sampleSpaceDimension $ manifold p
            (mus,sds) = C.splitAt n $ coordinates p
         in sampleMultivariateNormal mus $ M.reshape n sds

instance AbsolutelyContinuous Source MultivariateNormal where
    density p xs =
        let n = sampleSpaceDimension $ manifold p
            (mus,sgma) = splitMultivariateNormal p
         in recip ((2*pi)**(fromIntegral n / 2) * sqrt (M.det sgma))
            * exp (-0.5 * ((M.tr (M.pinv sgma) M.#> C.zipWith (-) xs mus) `M.dot` C.zipWith (-) xs mus))

instance MaximumLikelihood Source MultivariateNormal where
    mle _ xss =
        let n = fromIntegral $ length xss
            mus = recip (fromIntegral n) * sum xss
            sgma = recip (fromIntegral $ n - 1)
                * sum (map (\xs -> let xs' = xs - mus in M.outer xs' xs') xss)
        in  joinMultivariateNormal mus sgma
        -}

-- VonMises --

instance Manifold VonMises where
    type Dimension VonMises = 2

instance Statistical VonMises where
    type Sample VonMises = Double

instance Generative Source VonMises where
    sample p@(Point cs) = do
        let (mu,kap) = G.toPair cs
            tau = 1 + sqrt (1 + 4 * kap^(2 :: Int))
            rho = (tau - sqrt (2*tau))/(2*kap)
            r = (1 + rho^(2 :: Int)) / (2 * rho)
        [u1,u2,u3] <- replicateM 3 uniform
        let z = cos (pi * u1)
            f = (1 + r * z)/(r + z)
            c = kap * (r - f)
        if log (c / u2) + 1 - c < 0
           then sample p
           else return . toPi $ signum (u3 - 0.5) * acos f + mu

instance ExponentialFamily VonMises where
    sufficientStatistic tht = Point $ G.doubleton (cos tht) (sin tht)
    baseMeasure _ _ = recip $ 2 * pi

instance Transition Source Natural VonMises where
    transition (Point cs) =
        let (mu,kap) = G.toPair cs
         in Point $ G.doubleton (kap * cos mu) (kap * sin mu)

instance Transition Natural Source VonMises where
    transition (Point cs) =
        let (tht0,tht1) = G.toPair cs
         in Point $ G.doubleton (atan2 tht1 tht0) (sqrt $ tht0^(2 :: Int) + tht1^(2 :: Int))
