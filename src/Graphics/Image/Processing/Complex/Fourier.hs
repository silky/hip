{-# LANGUAGE BangPatterns #-}
{-# LANGUAGE CPP #-}
{-# LANGUAGE ConstraintKinds #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE ScopedTypeVariables #-}
-- |
-- Module      : Graphics.Image.Processing.Complex.Fourier
-- Copyright   : (c) Alexey Kuleshevich 2016
-- License     : BSD3
-- Maintainer  : Alexey Kuleshevich <lehins@yandex.ru>
-- Stability   : experimental
-- Portability : non-portable
--
module Graphics.Image.Processing.Complex.Fourier (
  fft, ifft, isPowerOfTwo
  ) where

#if MIN_VERSION_base(4,8,0)
import Prelude hiding (map, traverse)
#else
import Prelude hiding (map)
#endif
import Data.Bits ((.&.))
import Graphics.Image.Interface
import Graphics.Image.ColorSpace.Complex
import Graphics.Image.Processing.Geometric (leftToRight)


data Mode = Forward
          | Inverse

-- | Fast Fourier Transform
fft :: (Applicative (Pixel cs),
        Array arr cs (Complex e), ColorSpace cs e,
        Fractional (Pixel cs (Complex e)), Floating (Pixel cs e), RealFloat e) =>
       Image arr cs (Complex e)
    -> Image arr cs (Complex e)
fft = fft2d Forward
{-# INLINE fft #-}


-- | Inverse Fast Fourier Transform
ifft :: (Applicative (Pixel cs),
         Array arr cs (Complex e), ColorSpace cs e,
         Fractional (Pixel cs (Complex e)), Floating (Pixel cs e), RealFloat e) =>
        Image arr cs (Complex e)
     -> Image arr cs (Complex e)
ifft = fft2d Inverse
{-# INLINE ifft #-}


signOfMode :: Num a => Mode -> a
signOfMode Forward = -1
signOfMode Inverse = 1
{-# INLINE signOfMode #-}


-- | Check if `Int` is a power of two.
isPowerOfTwo :: Int -> Bool
isPowerOfTwo n = n /= 0 && (n .&. (n-1)) == 0
{-# INLINE isPowerOfTwo #-}


-- | Compute the DFT of a matrix. Array dimensions must be powers of two else `error`.
fft2d :: (Applicative (Pixel cs),
          Array arr cs (Complex e), ColorSpace cs e,
          Fractional (Pixel cs (Complex e)), Floating (Pixel cs e), RealFloat e) =>
         Mode
      -> Image arr cs (Complex e)
      -> Image arr cs (Complex e)
fft2d mode img =
  let !(m, n) = dims img
      !sign   = signOfMode mode
      !scale  = fromIntegral (m * n) 
  in if not (isPowerOfTwo m && isPowerOfTwo n)
     then error $ unlines
          [ "fft"
          , "  Array dimensions must be powers of two,"
          , "  but the provided image is " ++ show img ++ "." ]
     else case mode of
       Forward -> fftGeneral sign $ fftGeneral sign img
       Inverse -> map (/ scale) $ fftGeneral sign $ fftGeneral sign img
{-# INLINE fft2d #-}


fftGeneral :: (Applicative (Pixel cs),
               Array arr cs (Complex e), ColorSpace cs e, 
               Floating (Pixel cs e), RealFloat e) =>
              Pixel cs e
           -> Image arr cs (Complex e)
           -> Image arr cs (Complex e)
fftGeneral !sign !img = transpose $ go n 0 1 where
  imgM = toManifest img
  !(m, n) = dims img
  go !len !offset !stride
    | len == 2 = makeImage (m, 2) swivel
    | otherwise = combine len 
                  (go (len `div` 2) offset            (stride * 2))
                  (go (len `div` 2) (offset + stride) (stride * 2))
    where
      swivel (m', j) = case j of
        0 -> index imgM (m', offset) + index imgM (m', offset + stride)
        1 -> index imgM (m', offset) - index imgM (m', offset + stride)
        _ -> error "FFT: Image must have exactly 2 columns. Please, report this bug."
      combine !len' evens odds =  
        let odds' = traverse odds id
                    (\getPx (i, j) -> twiddle sign j len' * getPx (i, j)) 
        in leftToRight (evens + odds') (evens - odds')


-- Compute a twiddle factor.
twiddle :: (Applicative (Pixel cs), Floating (Pixel cs e)) =>
           Pixel cs e
        -> Int                  -- index
        -> Int                  -- length
        -> Pixel cs (Complex e)
twiddle sign k n = cos alpha +: sign * sin alpha where
  !alpha = 2 * pi * fromIntegral k / fromIntegral n
{-# INLINE twiddle #-}

