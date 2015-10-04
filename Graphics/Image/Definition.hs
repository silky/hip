{-# LANGUAGE FunctionalDependencies, MultiParamTypeClasses, ViewPatterns, BangPatterns #-}

module Graphics.Image.Definition (
  Convertable(..),
  Pixel(..),
  Strategy(..),
  Image(..)
  ) where


import Prelude hiding ((++), map, minimum, maximum)
import qualified Prelude as P (floor)
import Data.Array.Repa.Eval
import qualified Data.Vector.Unboxed as V
import Data.Array.Repa as R hiding (map)


class Convertable a b where
  convert :: a -> b


class (Elt px, V.Unbox px, Floating px, Fractional px, Num px, Eq px, Show px) =>
      Pixel px where
  pixel :: Double -> px
       
  pxOp :: (Double -> Double) -> px -> px

  pxOp2 :: (Double -> Double -> Double) -> px -> px -> px

  strongest :: px -> px

  weakest :: px -> px


class (Image img px, Pixel px) => Strategy strat img px where
  
  -- | Make sure an Image is in a computed form.
  compute :: strat img px
             -> img px
             -> img px

  -- | Fold an Image.
  fold :: strat img px
          -> (px -> px -> px)
          -> px
          -> img px
          -> px


class (Num (img px), Pixel px) => Image img px | px -> img where

  -- | Get dimensions of the image. (rows, cols)
  dims :: Pixel px => img px -> (Int, Int)

  -- | Get the number of rows in the image 
  rows :: Pixel px => img px -> Int
  rows = fst . dims

  -- | Get the number of columns in the image
  cols :: Pixel px => img px -> Int
  cols = snd . dims

  -- | O(1) Convert an Unboxed Vector to an Image by supplying rows, columns and
  -- a vector
  fromVector :: Pixel px => Int -> Int -> V.Vector px -> img px

  -- | Convert a nested List of Pixels to an Image.
  fromLists :: Pixel px => [[px]] -> img px
  fromLists ls =
    (fromVector (length ls) (length $ head ls)) . V.fromList . concat $ ls

  -- | Make an Image by supplying number of rows, columns and a function that
  -- returns a pixel value at the m n location which are provided as arguments.
  make :: Pixel px => Int -> Int -> (Int -> Int -> px) -> img px

  {-| Map a function over an image with a function. -}
  map :: (Pixel px, Pixel px1) => (px -> px1) -> img px -> img px1

  -- | Zip two Images with a function. Images do not have to hold the same type
  -- of pixels.
  zipWith :: (Pixel px, Pixel px2, Pixel px3) =>
                  (px -> px2 -> px3) -> img px -> img px2 -> img px3

  -- | Traverse the image.
  traverse :: Pixel px =>
              img px ->
              (Int -> Int -> (Int, Int)) ->
              ((Int -> Int -> px) -> Int -> Int -> px1) ->
              img px1
              
  -- | Get a pixel at i-th row and j-th column
  ref :: Pixel px => img px -> Int -> Int -> px

  -- | Get a pixel at i j location with a default pixel. If i or j are out of
  -- bounds, default pixel will be used
  refd :: Pixel px => img px -> px -> Int -> Int -> px
  refd img def i j = maybe def id $ refm img i j
    
  -- | Get Maybe pixel at i j location. If i or j are out of bounds will return
  -- Nothing
  refm :: Pixel px => img px -> Int -> Int -> Maybe px
  refm img@(dims -> (m, n)) i j = if i >= 0 && j >= 0 && i < m && j < n
                                  then Just $ ref img i j
                                  else Nothing

  -- | Bilinear or first order interpolation at given location.
  ref1 :: Pixel px => img px -> Double -> Double -> px
  ref1 img x y = fx0 + y'*(fx1-fx0) where
    !(!x0, !y0) = (floor x, floor y)
    !(!x1, !y1) = (x0 + 1, y0 + 1)
    !x' = pixel (x - (fromIntegral x0))
    !y' = pixel (y - (fromIntegral y0))
    !f00 = refd img (pixel 0) x0 y0
    !f10 = refd img (pixel 0) x1 y0
    !f01 = refd img (pixel 0) x0 y1 
    !f11 = refd img (pixel 0) x1 y1 
    !fx0 = f00 + x'*(f10-f00)
    !fx1 = f01 + x'*(f11-f01)
  
  -- | Convert an Image to a nested List of Pixels.
  toLists :: (Strategy strat img px, Pixel px) =>
             strat img px
             -> img px
             -> [[px]]
  toLists strat img =
    [[ref img' m n | n <- [0..cols img - 1]] | m <- [0..rows img - 1]] where
      img' = compute strat img

  fromArray :: Pixel px =>
               Array D DIM2 px
               -> img px
             
  toArray :: (Strategy strat img px, Pixel px) =>
             strat img px
             -> img px
             -> Array U DIM2 px

  -- | O(1) Convert an Image to a Vector of length: rows*cols
  toVector :: (Strategy strat img px, Pixel px) =>
              strat img px
              -> img px
              -> V.Vector px
  toVector strat = toUnboxed . toArray strat

  maximum :: (Strategy strat img px, Pixel px, Ord px) =>
             strat img px
             -> img px
             -> px
  maximum strat img = fold strat (pxOp2 max) (ref img 0 0) img
  {-# INLINE maximum #-}

  minimum :: (Strategy strat img px, Pixel px, Ord px) =>
             strat img px
             -> img px
             -> px
  minimum strat img = fold strat (pxOp2 min) (ref img 0 0) img
  {-# INLINE minimum #-}
  
  normalize :: (Strategy strat img px, Pixel px, Ord px) =>
               strat img px
               -> img px
               -> img px
  normalize strat img = compute strat $ if s == w
                  then img * 0
                  else map normalizer img where
                    !(!s, !w) = (strongest $ maximum strat img,
                                 weakest $ minimum strat img)
                    normalizer px = (px - w)/(s - w)
                    {-# INLINE normalizer #-}
  --{-# INLINE normalize #-}