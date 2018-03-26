{-# LANGUAGE GeneralizedNewtypeDeriving #-}

-- | Vectors and Matrices with statically typed dimensions. The 'Vector' and 'Matrix' types are
-- newtypes built on 'Data.Vector', so that GHC reduces all incumbent computations to computations
-- on the highly optimized @vector@ library.
--
-- In my provided benchmarks, my implementation of matrix x matrix multiplication performs about 20%
-- faster than the native implementation provided by the @matrix@ library, and performs within a
-- factor of 2-10 of @hmatrix@. This performance can likely be further improved by compiling with
-- the LLVM backend. Moreover, because the provided 'Vector' and 'Matrix' types are 'Traversable',
-- they may support automatic differentiation with the @ad@ library.
module Goal.Core.Vector.Generic
    ( -- * Vector
      module Data.Vector.Generic.Sized
    , CVector
    , concat
    , doubleton
    , breakEvery
    , range
    -- * Matrix
    , Matrix (Matrix,toVector)
    -- ** Construction
    , fromRows
    , fromColumns
    -- ** Deconstruction
    , toPair
    , toRows
    , toColumns
    , nRows
    , nColumns
    -- ** Manipulation
    , columnVector
    , rowVector
    -- ** BLAS
    , transpose
    , dotProduct
    , outerProduct
    , matrixVectorMultiply
    , matrixMatrixMultiply
    ) where


--- Imports ---


import GHC.TypeLits
import Data.Proxy
import Control.DeepSeq
import Goal.Core.Vector.TypeLits
import Data.Vector.Generic.Sized
import Data.Vector.Generic.Sized.Internal

import qualified Data.Vector.Generic as G
import qualified Data.Vector.Storable as S

import Prelude hiding (concatMap,concat,map)


--- Vector ---

type CVector v n x = (G.Vector v x, G.Vector v (Vector v n x))

-- | Create a 'Matrix' from a 'Vector' of 'Vector's which represent the rows.
concat :: (KnownNat n, CVector v n x) => Vector v m (Vector v n x) -> Vector v (m*n) x
{-# INLINE concat #-}
concat = concatMap id

doubleton :: CVector v 2 x => x -> x -> Vector v 2 x
{-# INLINE doubleton #-}
doubleton x1 x2 = cons x1 $ singleton x2

-- | Matrices with static dimensions.
newtype Matrix v (m :: Nat) (n :: Nat) a = Matrix { toVector :: Vector v (m*n) a }
    deriving (Eq,Show,NFData)

-- | Turn a 'Vector' into a single column 'Matrix'.
columnVector :: Vector v n a -> Matrix v n 1 a
{-# INLINE columnVector #-}
columnVector = Matrix

-- | Turn a 'Vector' into a single row 'Matrix'.
rowVector :: Vector v n a -> Matrix v 1 n a
{-# INLINE rowVector #-}
rowVector = Matrix

-- | Create a 'Matrix' from a 'Vector' of 'Vector's which represent the rows.
fromRows :: (CVector v n x, KnownNat n) => Vector v m (Vector v n x) -> Matrix v m n x
{-# INLINE fromRows #-}
fromRows = Matrix . concat

-- | Create a 'Matrix' from a 'Vector' of 'Vector's which represent the columns.
fromColumns
    :: (CVector v n x, CVector v m x, CVector v m Int, KnownNat n, KnownNat m)
    => Vector v n (Vector v m x) -> Matrix v m n x
{-# INLINE fromColumns #-}
fromColumns = transpose . fromRows

breakEvery
    :: forall v n k a . (CVector v n a, CVector v k a, KnownNat n, KnownNat k)
    => Vector v (n*k) a -> Vector v n (Vector v k a)
{-# INLINE breakEvery #-}
breakEvery v0 =
    let k = natValInt (Proxy :: Proxy k)
        v = fromSized v0
     in generate (\i -> Vector $ G.unsafeSlice (finiteInt i*k) k v)

-- | The number of rows in the 'Matrix'.
nRows :: forall v m n a . KnownNat m => Matrix v m n a -> Int
{-# INLINE nRows #-}
nRows _ = natValInt (Proxy :: Proxy m)

-- | The columns of rows in the 'Matrix'.
nColumns :: forall v m n a . KnownNat n => Matrix v m n a -> Int
{-# INLINE nColumns #-}
nColumns _ = natValInt (Proxy :: Proxy n)

toPair :: CVector v 2 a => Vector v 2 a -> (a,a)
toPair v = (unsafeIndex v 0, unsafeIndex v 1)

-- | Convert a 'Matrix' into a 'Vector' of 'Vector's of rows.
toRows :: (CVector v n a, CVector v m a, KnownNat n, KnownNat m)
       => Matrix v m n a -> Vector v m (Vector v n a)
{-# INLINE toRows #-}
toRows (Matrix v) = breakEvery v

-- | Convert a 'Matrix' into a 'Vector' of 'Vector's of columns.
toColumns
    :: (CVector v n a, CVector v m a, KnownNat m, KnownNat n, CVector v n Int)
    => Matrix v m n a -> Vector v n (Vector v m a)
{-# INLINE toColumns #-}
toColumns = toRows . transpose

-- | Range function
range
    :: forall v n x. (CVector v n x, KnownNat n, Fractional x)
    => x -> x -> Vector v n x
{-# INLINE range #-}
range mn mx =
    let n = natValInt (Proxy :: Proxy n)
        stp = (mx - mn)/fromIntegral (n-1)
     in enumFromStepN mn stp


--- BLAS ---


transpose
    :: forall v m n a . (KnownNat m, KnownNat n, CVector v n Int, CVector v m a)
    => Matrix v m n a -> Matrix v n m a
{-# INLINE transpose #-}
transpose (Matrix v) =
    let n = natValInt (Proxy :: Proxy n)
     in fromRows $ generate (\j -> generate (\i -> unsafeIndex v $ finiteInt j + finiteInt i*n) :: Vector v m a)

dotProduct :: (CVector v n x, Num x) => Vector v n x -> Vector v n x -> x
{-# INLINE dotProduct #-}
dotProduct v1 v2 = weakDotProduct (fromSized v1) (fromSized v2)

outerProduct
    :: ( KnownNat m, KnownNat n, Num x
       , CVector v n Int, CVector v m Int, CVector v n x, CVector v m x, CVector v 1 x )
     => Vector v n x -> Vector v m x -> Matrix v n m x
{-# INLINE outerProduct #-}
outerProduct v1 v2 = matrixMatrixMultiply (columnVector v1) (rowVector v2)

weakDotProduct :: (G.Vector v x, Num x) => v x -> v x -> x
{-# INLINE weakDotProduct #-}
weakDotProduct v1 v2 = G.foldl foldFun 0 (G.enumFromN 0 (G.length v1) :: S.Vector Int)
    where foldFun d i = d + G.unsafeIndex v1 i * G.unsafeIndex v2 i

matrixVectorMultiply
    :: (KnownNat m, KnownNat n, CVector v n x, CVector v m x, Num x)
    => Matrix v m n x
    -> Vector v n x
    -> Vector v m x
{-# INLINE matrixVectorMultiply #-}
matrixVectorMultiply mtx v =
    map (dotProduct v) $ toRows mtx

matrixMatrixMultiply
    :: ( KnownNat m, KnownNat n, KnownNat o, Num x
       , CVector v m Int, CVector v o Int, CVector v m x, CVector v n x, CVector v o x )
    => Matrix v m n x
    -> Matrix v n o x
    -> Matrix v m o x
{-# INLINE matrixMatrixMultiply #-}
matrixMatrixMultiply mtx1 mtx2 =
    fromColumns . map (matrixVectorMultiply mtx1) $ toColumns mtx2

