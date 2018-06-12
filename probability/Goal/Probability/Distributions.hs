{-# LANGUAGE UndecidableInstances #-}

-- | Various instances of statistical manifolds, with a focus on exponential families.
module Goal.Probability.Distributions
    ( -- * Exponential Families
      Bernoulli
    , Binomial
    , binomialTrials
    , Categorical
    , Poisson
    , Normal
    , MeanNormal
    , StandardNormal
    , meanNormalVariance
    , meanNormalToNormal
    , VonMises
    , LinearModel
    , fitLinearModel
    , linearModelVariance
    ) where

-- Package --

import Goal.Core
import Goal.Probability.Statistical
import Goal.Probability.ExponentialFamily

import Goal.Geometry
import System.Random.MWC.Probability

import qualified Goal.Core.Vector.Storable as S
import qualified Goal.Core.Vector.Boxed as B
import qualified Goal.Core.Vector.Generic as G

import qualified Numeric.GSL.Special.Bessel as GSL

-- Uniform --

type StandardNormal = MeanNormal (1/1)

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

-- | Returns the number of trials used to define this binomial distribution.
binomialTrials :: forall c n. KnownNat n => Point c (Binomial n) -> Int
{-# INLINE binomialTrials #-}
binomialTrials _ = natValInt (Proxy :: Proxy n)

-- Categorical Distribution --

-- | A 'Categorical' distribution where the probability of the last category is
-- given by the normalization constraint.
data Categorical e (n :: Nat)

-- | Takes a weighted list of elements representing a probability mass function, and
-- returns a sample from the Categorical distribution.
sampleCategorical :: (Enum e, KnownNat n) => S.Vector n Double -> Random s e
{-# INLINE sampleCategorical #-}
sampleCategorical ps = do
    let ps' = S.scanl' (+) 0 ps
    p <- uniform
    let ma = subtract 1 . finiteInt <$> S.findIndex (> p) ps'
    return . toEnum $ fromMaybe ( S.length ps) ma

-- Curved Categorical Distribution --

-- Poisson Distribution --

-- | Returns a sample from a Poisson distribution with the given rate.
samplePoisson :: Double -> Random s Int
{-# INLINE samplePoisson #-}
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

-- | Returns the known variance of the given 'MeanNormal' distribution.
meanNormalVariance :: forall n d c . (KnownNat n, KnownNat d)
                   => Point c (MeanNormal (n/d)) -> Double
{-# INLINE meanNormalVariance #-}
meanNormalVariance _ = realToFrac $ ratVal (Proxy :: Proxy (n/d))

-- | Returns the known variance of the given 'MeanNormal' distribution.
meanNormalToNormal :: forall n d . (KnownNat n, KnownNat d)
                   => Source # MeanNormal (n/d) -> Source # Normal
{-# INLINE meanNormalToNormal #-}
meanNormalToNormal p = Point $ coordinates p S.++ S.singleton (meanNormalVariance p)


-- Multivariate Normal --

-- | The 'Manifold' of 'MultivariateNormal' distributions. The standard coordinates are the
-- (vector) mean and the covariance matrix. When building a multivariate normal
-- distribution using e.g. 'fromList', the elements of the mean come first, and
-- then the elements of the covariance matrix in row major order.
--data MultivariateNormal (n :: Nat)
--
--splitMultivariateNormal :: KnownNat n => Point c (MultivariateNormal n) x -> (S.Vector n x, Matrix n n x)
--splitMultivariateNormal (Point xs) =
--    let (mus,cvrs) = S.splitAt xs
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


-- Linear Models --


data LinearModel m n

linearModelVariance
    :: Manifold n
    => Mean ~> Source # LinearModel Normal n
    -> Double
{-# INLINE linearModelVariance #-}
linearModelVariance = snd . S.toPair . coordinates . fst . splitLinearModel

splitLinearModel
    :: Manifold n
    => Mean ~> Source # LinearModel Normal n
    -> (Source # Normal, c ~> Cartesian # Tensor (Euclidean 1) n)
{-# INLINE splitLinearModel #-}
splitLinearModel (Point cppqs) =
    let (cps,cpqs) = S.splitAt cppqs
     in (Point cps, Point cpqs)

joinLinearModel
    :: Manifold n
    => Source # Normal
    -> Mean ~> Cartesian # Tensor (Euclidean 1) n
    -> Mean ~> Source # LinearModel Normal n
{-# INLINE joinLinearModel #-}
joinLinearModel (Point cps) (Point cpqs) = Point $ cps S.++ cpqs

fitLinearModel
    :: forall k n
    . (1 <= k, KnownNat k, ExponentialFamily n)
    => Sample k n
    -> Sample k Normal
    -> Mean ~> Source # LinearModel Normal n
{-# INLINE fitLinearModel #-}
fitLinearModel xs0 ys0 =
    let xs0' :: B.Vector k (Mean # n)
        xs0' = sufficientStatistic <$> xs0
        xs = G.convert $ coordinates <$> xs0'
        ys = G.convert ys0
        xs' = S.map (S.singleton 1 S.++) xs
        bts0 = linearLeastSquares xs' ys
        mu0 :: S.Vector 1 Double
        (mu0,bts) = S.splitAt bts0
        mu = S.head mu0
        yhts = S.map ((+ mu) . S.dotProduct bts) xs
        vr = S.average . S.map square $ S.zipWith (-) yhts ys
     in joinLinearModel (Point $ S.doubleton mu vr) (Point bts)

--- Internal ---

binomialBaseMeasure0 :: (KnownNat n) => Proxy n -> Proxy (Binomial n) -> SamplePoint (Binomial n) -> Double
{-# INLINE binomialBaseMeasure0 #-}
binomialBaseMeasure0 prxyn _ = choose (natValInt prxyn)

meanNormalBaseMeasure0 :: (KnownNat n, KnownNat d) => Proxy (n/d) -> Proxy (MeanNormal (n/d)) -> SamplePoint (MeanNormal (n/d)) -> Double
{-# INLINE meanNormalBaseMeasure0 #-}
meanNormalBaseMeasure0 prxyr _ x =
    let vr = realToFrac $ ratVal prxyr
     in (exp . negate $ 0.5 * square x / vr) / sqrt (2*pi*vr)

--multivariateNormalBaseMeasure0 :: (KnownNat n) => Proxy n -> Proxy (MultivariateNormal n) -> S.Vector n Double -> x
--multivariateNormalBaseMeasure0 prxyn _ _ =
--    let n = natValInt prxyn
--     in (2*pi)**(-fromIntegral n/2)

--- Instances ---


-- Bernoulli Distribution --

instance Manifold Bernoulli where
    type Dimension Bernoulli = 1

instance Statistical Bernoulli where
    type SamplePoint Bernoulli = Bool

instance Discrete Bernoulli where
    type Cardinality Bernoulli = 2
    sampleSpace _ = B.doubleton True False

instance ExponentialFamily Bernoulli where
    baseMeasure _ _ = 1
    {-# INLINE sufficientStatistic #-}
    sufficientStatistic True = Point $ S.singleton 1
    sufficientStatistic False = Point $ S.singleton 0

instance Legendre Natural Bernoulli where
    {-# INLINE potential #-}
    potential p = log $ 1 + exp (S.head $ coordinates p)
    {-# INLINE potentialDifferential #-}
    potentialDifferential = Point . S.map logistic . coordinates

instance {-# OVERLAPS #-} KnownNat k => Legendre Natural (Replicated k Bernoulli) where
    {-# INLINE potential #-}
    potential p = S.sum . S.map (log . (1 +) .  exp) $ coordinates p
    {-# INLINE potentialDifferential #-}
    potentialDifferential = Point . S.map logistic . coordinates

instance Legendre Mean Bernoulli where
    {-# INLINE potential #-}
    potential p =
        let eta = S.head $ coordinates p
         in logit eta * eta - log (1 / (1 - eta))
    {-# INLINE potentialDifferential #-}
    potentialDifferential = Point . S.map logit . coordinates

instance Riemannian Natural Bernoulli where
    {-# INLINE metric #-}
    metric p =
        let stht = logistic . S.head $ coordinates p
         in Point . S.singleton $ stht * (1-stht)
    {-# INLINE flat #-}
    flat pp' =
        let (p,p') = splitTangentPair pp'
            stht = logistic . S.head $ coordinates p
            dp = breakPoint $ (stht * (1-stht)) .> p'
         in joinTangentPair p dp

instance {-# OVERLAPS #-} KnownNat k => Riemannian Natural (Replicated k Bernoulli) where
    {-# INLINE metric #-}
    metric = error "Do not call metric on a replicated manifold"
    {-# INLINE flat #-}
    flat pp' =
        let (p,p') = splitTangentPair pp'
            sthts = S.map ((\stht -> stht * (1-stht)) . logistic) $ coordinates p
            dp = S.zipWith (*) sthts $ coordinates p'
         in joinTangentPair p (Point dp)

instance {-# OVERLAPS #-} KnownNat k => Riemannian Mean (Replicated k Bernoulli) where
    {-# INLINE metric #-}
    metric = error "Do not call metric on a replicated manifold"
    {-# INLINE sharp #-}
    sharp pdp =
        let (p,dp) = splitTangentPair pdp
            sthts' = S.map (\stht -> stht * (1-stht)) $ coordinates p
            p' = S.zipWith (*) sthts' $ coordinates dp
         in joinTangentPair p (Point p')

instance Transition Mean Natural Bernoulli where
    {-# INLINE transition #-}
    transition = dualTransition

instance Transition Natural Mean Bernoulli where
    {-# INLINE transition #-}
    transition = dualTransition

instance Transition Source Mean Bernoulli where
    {-# INLINE transition #-}
    transition = breakPoint

instance Transition Mean Source Bernoulli where
    {-# INLINE transition #-}
    transition = breakPoint

instance Transition Source Natural Bernoulli where
    {-# INLINE transition #-}
    transition = dualTransition . toMean

instance Transition Natural Source Bernoulli where
    {-# INLINE transition #-}
    transition = transition . dualTransition

instance (Transition c Source Bernoulli) => Generative c Bernoulli where
    {-# INLINE samplePoint #-}
    samplePoint = bernoulli . S.head . coordinates . toSource

instance Transition Mean c Bernoulli => MaximumLikelihood c Bernoulli where
    mle = transition . sufficientStatisticT

instance AbsolutelyContinuous Source Bernoulli where
    density (Point p) True = S.head p
    density (Point p) False = 1 - S.head p

instance AbsolutelyContinuous Mean Bernoulli where
    density = density . toSource

instance AbsolutelyContinuous Natural Bernoulli where
    density = exponentialFamilyDensity

-- Binomial Distribution --

instance KnownNat n => Manifold (Binomial n) where
    type Dimension (Binomial n) = 1

instance KnownNat n => Statistical (Binomial n) where
    type SamplePoint (Binomial n) = Int

instance KnownNat n => Discrete (Binomial n) where
    type Cardinality (Binomial n) = n + 1
    sampleSpace _ = B.generate finiteInt

instance KnownNat n => ExponentialFamily (Binomial n) where
    baseMeasure = binomialBaseMeasure0 Proxy
    {-# INLINE sufficientStatistic #-}
    sufficientStatistic = Point . S.singleton . fromIntegral

instance KnownNat n => Legendre Natural (Binomial n) where
    {-# INLINE potential #-}
    potential p =
        let n = fromIntegral $ binomialTrials p
            tht = S.head $ coordinates p
         in n * log (1 + exp tht)
    {-# INLINE potentialDifferential #-}
    potentialDifferential p =
        let n = fromIntegral $ binomialTrials p
         in Point . S.singleton $ n * logistic (S.head $ coordinates p)

instance KnownNat n => Legendre Mean (Binomial n) where
    {-# INLINE potential #-}
    potential p =
        let n = fromIntegral $ binomialTrials p
            eta = S.head $ coordinates p
        in eta * log (eta / (n - eta)) - n * log (n / (n - eta))
    {-# INLINE potentialDifferential #-}
    potentialDifferential p =
        let n = fromIntegral $ binomialTrials p
            eta = S.head $ coordinates p
         in Point . S.singleton . log $ eta / (n - eta)

instance KnownNat n => Transition Source Natural (Binomial n) where
    {-# INLINE transition #-}
    transition = dualTransition . toMean

instance KnownNat n => Transition Natural Source (Binomial n) where
    {-# INLINE transition #-}
    transition = transition . dualTransition

instance KnownNat n => Transition Source Mean (Binomial n) where
    {-# INLINE transition #-}
    transition p =
        let n = fromIntegral $ binomialTrials p
         in breakPoint $ n .> p

instance KnownNat n => Transition Mean Source (Binomial n) where
    {-# INLINE transition #-}
    transition p =
        let n = fromIntegral $ binomialTrials p
         in breakPoint $ n /> p

instance (KnownNat n, Transition c Source (Binomial n)) => Generative c (Binomial n) where
    samplePoint p0 = do
        let p = toSource p0
            n = binomialTrials p
        bls <- replicateM n . bernoulli . S.head $ coordinates p
        return $ sum [ if bl then 1 else 0 | bl <- bls ]

instance KnownNat n => AbsolutelyContinuous Source (Binomial n) where
    density p k =
        let n = binomialTrials p
            c = S.head $ coordinates p
         in choose n k * c^k * (1 - c)^(n-k)

instance KnownNat n => AbsolutelyContinuous Mean (Binomial n) where
    density = density . toSource

instance KnownNat n => AbsolutelyContinuous Natural (Binomial n) where
    density = exponentialFamilyDensity

instance (KnownNat n, Transition Mean c (Binomial n)) => MaximumLikelihood c (Binomial n) where
    mle = transition . sufficientStatisticT

-- Categorical Distribution --

instance (Enum e, KnownNat n, 1 <= n) => Manifold (Categorical e n) where
    type Dimension (Categorical e n) = n - 1

instance (Enum e, KnownNat n, 1 <= n) => Statistical (Categorical e n) where
    type SamplePoint (Categorical e n) = e

instance (Enum e, KnownNat n, 1 <= n) => Discrete (Categorical e n) where
    type Cardinality (Categorical e n) = n
    sampleSpace _ = B.generate (toEnum . finiteInt)

instance (Enum e, KnownNat n, 1 <= n) => ExponentialFamily (Categorical e n) where
    baseMeasure _ _ = 1
    {-# INLINE sufficientStatistic #-}
    sufficientStatistic k = Point $ S.generate (\i -> if finiteInt i == fromEnum k then 1 else 0)

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

instance (Enum e, KnownNat n, 1 <= n) => Transition Mean Natural (Categorical e n) where
    {-# INLINE transition #-}
    transition = dualTransition

instance (Enum e, KnownNat n, 1 <= n) => Transition Natural Mean (Categorical e n) where
    {-# INLINE transition #-}
    transition = dualTransition

instance Transition Source Mean (Categorical e n) where
    {-# INLINE transition #-}
    transition = breakPoint

instance Transition Mean Source (Categorical e n) where
    {-# INLINE transition #-}
    transition = breakPoint

instance (Enum e, KnownNat n, 1 <= n) => Transition Source Natural (Categorical e n) where
    {-# INLINE transition #-}
    transition = dualTransition . toMean

instance (Enum e, KnownNat n, 1 <= n) => Transition Natural Source (Categorical e n) where
    {-# INLINE transition #-}
    transition = transition . dualTransition

instance (Enum e, KnownNat n, 1 <= n, Transition c Source (Categorical e n))
  => Generative c (Categorical e n) where
    {-# INLINE samplePoint #-}
    samplePoint p0 =
        let p = toSource p0
         in sampleCategorical $ coordinates p

instance (Enum e, KnownNat n, 1 <= n, Transition Mean c (Categorical e n)) => MaximumLikelihood c (Categorical e n) where
    mle = transition . sufficientStatisticT

instance (Enum e, KnownNat n, 1 <= n) => AbsolutelyContinuous Source (Categorical e n) where
    density (Point ps) e =
        let mk = packFinite . fromIntegral $ fromEnum e
            mp = S.index ps <$> mk
         in fromMaybe (1 - S.sum ps) mp

instance (Enum e, KnownNat n, 1 <= n) => AbsolutelyContinuous Mean (Categorical e n) where
    density = density . toSource

instance (Enum e, KnownNat n, 1 <= n) => AbsolutelyContinuous Natural (Categorical e n) where
    density = exponentialFamilyDensity

-- Poisson Distribution --

instance Manifold Poisson where
    type Dimension Poisson = 1

instance Statistical Poisson where
    type SamplePoint Poisson = Int

instance ExponentialFamily Poisson where
    {-# INLINE sufficientStatistic #-}
    sufficientStatistic = Point . S.singleton . fromIntegral
    baseMeasure _ k = recip $ factorial k

instance Legendre Natural Poisson where
    {-# INLINE potential #-}
    potential = exp . S.head . coordinates
    {-# INLINE potentialDifferential #-}
    potentialDifferential = Point . exp . coordinates

instance Legendre Mean Poisson where
    {-# INLINE potential #-}
    potential (Point xs) =
        let eta = S.head xs
         in eta * log eta - eta
    {-# INLINE potentialDifferential #-}
    potentialDifferential = Point . log . coordinates

instance Transition Mean Natural Poisson where
    {-# INLINE transition #-}
    transition = dualTransition

instance Transition Natural Mean Poisson where
    {-# INLINE transition #-}
    transition = dualTransition

instance Transition Source Natural Poisson where
    {-# INLINE transition #-}
    transition = transition . toMean

instance Transition Natural Source Poisson where
    {-# INLINE transition #-}
    transition = transition . dualTransition

instance Transition Source Mean Poisson where
    {-# INLINE transition #-}
    transition = breakPoint

instance Transition Mean Source Poisson where
    {-# INLINE transition #-}
    transition = breakPoint

instance (Transition c Source Poisson) => Generative c Poisson where
    {-# INLINE samplePoint #-}
    samplePoint = samplePoisson . S.head . coordinates . toSource

instance AbsolutelyContinuous Source Poisson where
    density (Point xs) k =
        let lmda = S.head xs
         in  lmda^k / factorial k * exp (-lmda)

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
    type SamplePoint Normal = Double

instance ExponentialFamily Normal where
    {-# INLINE sufficientStatistic #-}
    sufficientStatistic x =
         Point . S.doubleton x $ x**2
    {-# INLINE baseMeasure #-}
    baseMeasure _ _ = recip . sqrt $ 2 * pi

instance Legendre Natural Normal where
    {-# INLINE potential #-}
    potential (Point cs) =
        let (tht0,tht1) = S.toPair cs
         in -(square tht0 / (4*tht1)) - 0.5 * log(-2*tht1)
    {-# INLINE potentialDifferential #-}
    potentialDifferential p =
        let (tht0,tht1) = S.toPair $ coordinates p
            dv = tht0/tht1
         in Point $ S.doubleton (-0.5*dv) (0.25 * square dv - 0.5/tht1)

instance Legendre Mean Normal where
    {-# INLINE potential #-}
    potential (Point cs) =
        let (eta0,eta1) = S.toPair cs
         in -0.5 * log(eta1 - square eta0) - 1/2
    {-# INLINE potentialDifferential #-}
    potentialDifferential p =
        let (eta0,eta1) = S.toPair $ coordinates p
            dff = eta1 - square eta0
         in Point $ S.doubleton (eta0 / dff) (-0.5 / dff)

instance Riemannian Natural Normal where
    {-# INLINE metric #-}
    metric p =
        let (tht0,tht1) = S.toPair $ coordinates p
            d00 = -1/(2*tht1)
            d01 = tht0/(2*square tht1)
            d11 = 0.5*(1/square tht1 - square tht0 / (tht1^(3 :: Int)))
         in Point $ S.doubleton d00 d01 S.++ S.doubleton d01 d11

instance Riemannian Mean Normal where
    {-# INLINE metric #-}
    metric p =
        let (eta0,eta1) = S.toPair $ coordinates p
            eta02 = square eta0
            dff2 = square $ eta1 - eta02
            d00 = (dff2 + 2 * eta02) / dff2
            d01 = -eta0 / dff2
            d11 = 0.5 / dff2
         in Point $ S.doubleton d00 d01 S.++ S.doubleton d01 d11

instance Riemannian Source Normal where
    {-# INLINE metric #-}
    metric p =
        let (_,vr) = S.toPair $ coordinates p
         in Point $ S.doubleton (recip vr) 0 S.++ S.doubleton 0 (recip $ 2*square vr)

instance Transition Mean Natural Normal where
    {-# INLINE transition #-}
    transition = dualTransition

instance Transition Natural Mean Normal where
    {-# INLINE transition #-}
    transition = dualTransition

instance Transition Source Mean Normal where
    {-# INLINE transition #-}
    transition (Point cs) =
        let (mu,vr) = S.toPair cs
         in Point . S.doubleton mu $ vr + square mu

instance Transition Mean Source Normal where
    {-# INLINE transition #-}
    transition (Point cs) =
        let (eta0,eta1) = S.toPair cs
         in Point . S.doubleton eta0 $ eta1 - square eta0

instance Transition Source Natural Normal where
    {-# INLINE transition #-}
    transition (Point cs) =
        let (mu,vr) = S.toPair cs
         in Point $ S.doubleton (mu / vr) (negate . recip $ 2 * vr)

instance Transition Natural Source Normal where
    {-# INLINE transition #-}
    transition (Point cs) =
        let (tht0,tht1) = S.toPair cs
         in Point $ S.doubleton (-0.5 * tht0 / tht1) (negate . recip $ 2 * tht1)

instance (Transition c Source Normal) => Generative c Normal where
    {-# INLINE samplePoint #-}
    samplePoint p =
        let (Point cs) = toSource p
            (mu,vr) = S.toPair cs
         in normal mu (sqrt vr)

instance AbsolutelyContinuous Source Normal where
    density (Point cs) x =
        let (mu,vr) = S.toPair cs
         in recip (sqrt $ vr*2*pi) * exp (negate $ (x - mu) ** 2 / (2*vr))

instance AbsolutelyContinuous Mean Normal where
    density = density . toSource

instance AbsolutelyContinuous Natural Normal where
    density = exponentialFamilyDensity

instance Transition Mean c Normal => MaximumLikelihood c Normal where
    mle = transition . sufficientStatisticT

-- MeanNormal Distribution --

instance Manifold (MeanNormal v) where
    type Dimension (MeanNormal v) = 1

instance Statistical (MeanNormal v) where
    type SamplePoint (MeanNormal v) = Double

instance (KnownNat n, KnownNat d) => ExponentialFamily (MeanNormal (n / d)) where
    {-# INLINE sufficientStatistic #-}
    sufficientStatistic = Point . S.singleton
    baseMeasure = meanNormalBaseMeasure0 Proxy

instance (KnownNat n, KnownNat d) => Legendre Natural (MeanNormal (n/d)) where
    {-# INLINE potential #-}
    potential p =
        let vr = meanNormalVariance p
            mu = S.head $ coordinates p
         in 0.5 * vr * square mu
    {-# INLINE potentialDifferential #-}
    potentialDifferential p =
        let vr = meanNormalVariance p
         in Point . S.singleton $ vr * S.head (coordinates p)


instance (KnownNat n, KnownNat d) => Legendre Mean (MeanNormal (n/d)) where
    {-# INLINE potential #-}
    potential p =
        let vr = meanNormalVariance p
            mu = S.head $ coordinates p
         in 0.5 / vr * square mu
    {-# INLINE potentialDifferential #-}
    potentialDifferential p =
        let vr = meanNormalVariance p
         in Point . S.singleton $ S.head (coordinates p) / vr

instance (KnownNat n, KnownNat d) => Transition Mean Natural (MeanNormal (n/d)) where
    {-# INLINE transition #-}
    transition = dualTransition

instance (KnownNat n, KnownNat d) => Transition Natural Mean (MeanNormal (n/d)) where
    {-# INLINE transition #-}
    transition = dualTransition

instance Transition Source Mean (MeanNormal v) where
    {-# INLINE transition #-}
    transition = breakPoint

instance Transition Mean Source (MeanNormal v) where
    {-# INLINE transition #-}
    transition = breakPoint

instance (KnownNat n, KnownNat d) => Transition Source Natural (MeanNormal (n/d)) where
    {-# INLINE transition #-}
    transition = dualTransition . toMean

instance (KnownNat n, KnownNat d) => Transition Natural Source (MeanNormal (n/d)) where
    {-# INLINE transition #-}
    transition = toSource . dualTransition

instance (KnownNat n, KnownNat d) => AbsolutelyContinuous Source (MeanNormal (n/d)) where
    density p =
        let vr = meanNormalVariance p
            mu = S.head $ coordinates p
            nrm :: Double -> Double -> Point Source Normal
            nrm x y = Point $ S.doubleton x y
         in density $ nrm mu vr

instance (KnownNat n, KnownNat d) => AbsolutelyContinuous Mean (MeanNormal (n/d)) where
    density = density . toSource

instance (KnownNat n, KnownNat d) => AbsolutelyContinuous Natural (MeanNormal (n/d)) where
    density = exponentialFamilyDensity

instance (KnownNat n, KnownNat d, Transition Mean c (MeanNormal (n/d))) => MaximumLikelihood c (MeanNormal (n/d)) where
    mle = transition . sufficientStatisticT

instance (KnownNat n, KnownNat d, Transition c Source (MeanNormal (n/d))) => Generative c (MeanNormal (n/d)) where
    samplePoint p =
        let (Point cs) = toSource p
            mu = S.head cs
            vr = meanNormalVariance p
         in normal mu (sqrt vr)

-- Multivariate Normal --

--instance KnownNat n => Manifold (MultivariateNormal n) where
--    type Dimension (MultivariateNormal n) = n + n * n
--
--instance KnownNat n => Statistical (MultivariateNormal n) where
--    type samplePoint (MultivariateNormal n) = S.Vector n Double
--
--instance KnownNat n => ExponentialFamily (MultivariateNormal n) where
--    {-# INLINE sufficientStatistic #-}
--    sufficientStatistic xs =
--        let Matrix cvrs = matrixMatrixMultiply (columnVector xs) (rowVector xs)
--         in fmap realToFrac . Point $ joinV xs cvrs
--    baseMeasure = multivariateNormalBaseMeasure0 Proxy

--instance Legendre Natural MultivariateNormal where
--    potential p =
--        let (tmu,tsgma) = splitMultivariateNormal p
--            invtsgma = matrixInverse tsgma
--         in -0.25 * dotProduct tmu (matrixVectorMultiply invtsgma tmu) - 0.5 * log(M.det $ M.scale (-2) tsgma)
--
--instance Legendre Mean MultivariateNormal where
--    potential p =
--        let (mmu,msgma) = splitMultivariateNormal p
--         in -0.5 * (1 + M.dot mmu (M.pinv msgma M.#> mmu)) - 0.5 * log (M.det msgma)
--
--instance Transition Source Natural MultivariateNormal where
--    transition p =
--        let (mu,sgma) = splitMultivariateNormal p
--            invsgma = M.pinv sgma
--         in fromCoordinates (manifold p) $ (invsgma M.#> mu) C.++ M.flatten (M.scale (-0.5) invsgma)
--
--instance Transition Natural Source MultivariateNormal where
--    transition p =
--        let (emu,esgma) = splitMultivariateNormal p
--            invesgma = M.scale (-0.5) $ M.pinv esgma
--         in fromCoordinates (manifold p) $ (invesgma M.#> emu) C.++ M.flatten invesgma
--
--instance Transition Source Mean MultivariateNormal where
--    transition p =
--        let (mu,sgma) = splitMultivariateNormal p
--         in fromCoordinates (manifold p) $ mu C.++ M.flatten (sgma + M.outer mu mu)
--
--instance Transition Mean Source MultivariateNormal where
--    transition p =
--        let (mmu,msgma) = splitMultivariateNormal p
--         in fromCoordinates (manifold p) $ mmu C.++ M.flatten (msgma -M.outer mmu mmu)
--
--instance Generative Source MultivariateNormal where
--    samplePoint p =
--        let n = sampleSpaceDimension $ manifold p
--            (mus,sds) = C.splitAt n $ coordinates p
--         in sampleMultivariateNormal mus $ M.reshape n sds
--
--instance AbsolutelyContinuous Source MultivariateNormal where
--    density p xs =
--        let n = sampleSpaceDimension $ manifold p
--            (mus,sgma) = splitMultivariateNormal p
--         in recip ((2*pi)**(fromIntegral n / 2) * sqrt (M.det sgma))
--            * exp (-0.5 * ((M.tr (M.pinv sgma) M.#> C.zipWith (-) xs mus) `M.dot` C.zipWith (-) xs mus))
--
--instance MaximumLikelihood Source MultivariateNormal where
--    mle _ xss =
--        let n = fromIntegral $ length xss
--            mus = recip (fromIntegral n) * sum xss
--            sgma = recip (fromIntegral $ n - 1)
--                * sum (map (\xs -> let xs' = xs - mus in M.outer xs' xs') xss)
--        in  joinMultivariateNormal mus sgma

-- VonMises --

instance Manifold VonMises where
    type Dimension VonMises = 2

instance Statistical VonMises where
    type SamplePoint VonMises = Double

instance Generative Source VonMises where
    {-# INLINE samplePoint #-}
    samplePoint p@(Point cs) = do
        let (mu,kap) = S.toPair cs
            tau = 1 + sqrt (1 + 4 * square kap)
            rho = (tau - sqrt (2*tau))/(2*kap)
            r = (1 + square rho) / (2 * rho)
        [u1,u2,u3] <- replicateM 3 uniform
        let z = cos (pi * u1)
            f = (1 + r * z)/(r + z)
            c = kap * (r - f)
        if log (c / u2) + 1 - c < 0
           then samplePoint p
           else return . toPi $ signum (u3 - 0.5) * acos f + mu

instance AbsolutelyContinuous Source VonMises where
    density p x =
        let (mu,kp) = S.toPair $ coordinates p
         in exp (kp * cos (x - mu)) / (2*pi * GSL.bessel_I0 kp)

instance Legendre Natural VonMises where
    {-# INLINE potential #-}
    potential p =
        let kp = snd . S.toPair . coordinates $ toSource p
         in log $ GSL.bessel_I0 kp
    potentialDifferential p =
        let kp = snd . S.toPair . coordinates $ toSource p
         in breakPoint $ (GSL.bessel_I1 kp / (GSL.bessel_I0 kp * kp)) .> p

instance AbsolutelyContinuous Natural VonMises where
    density = exponentialFamilyDensity


--    {-# INLINE potentialDifferential #-}
--    potentialDifferential p =
--        let vr = meanNormalVariance p
--         in Point . S.singleton $ vr * S.head (coordinates p)


instance Generative Natural VonMises where
    samplePoint = samplePoint . toSource

instance ExponentialFamily VonMises where
    {-# INLINE sufficientStatistic #-}
    sufficientStatistic tht = Point $ S.doubleton (cos tht) (sin tht)
    {-# INLINE baseMeasure #-}
    baseMeasure _ _ = recip $ 2 * pi

instance Transition Source Natural VonMises where
    {-# INLINE transition #-}
    transition (Point cs) =
        let (mu,kap) = S.toPair cs
         in Point $ S.doubleton (kap * cos mu) (kap * sin mu)

instance Transition Natural Source VonMises where
    {-# INLINE transition #-}
    transition (Point cs) =
        let (tht0,tht1) = S.toPair cs
         in Point $ S.doubleton (atan2 tht1 tht0) (sqrt $ square tht0 + square tht1)


-- LinearModel --

instance Manifold n => Manifold (LinearModel Normal n) where
    type Dimension (LinearModel Normal n) = Dimension Normal + Dimension n

instance Manifold n => Map Mean Source LinearModel Normal n where
    {-# INLINE (>$>) #-}
    (>$>) lm pxs =
        let (nrm0,f) = splitLinearModel lm
            (mu0,vr) = S.toPair $ coordinates nrm0
            ys = coordinates $ f >$> pxs
         in joinReplicated $ S.map (\y -> Point $ S.doubleton (mu0 + y) vr) ys

