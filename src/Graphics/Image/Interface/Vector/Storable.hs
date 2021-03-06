{-# LANGUAGE BangPatterns #-}
{-# LANGUAGE CPP #-}
{-# LANGUAGE ConstraintKinds #-}
{-# LANGUAGE DeriveDataTypeable #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE UndecidableInstances #-}
{-# LANGUAGE ViewPatterns #-}
-- |
-- Module      : Graphics.Image.Interface.Vector.Storable
-- Copyright   : (c) Alexey Kuleshevich 2017
-- License     : BSD3
-- Maintainer  : Alexey Kuleshevich <lehins@yandex.ru>
-- Stability   : experimental
-- Portability : non-portable
--
module Graphics.Image.Interface.Vector.Storable (
  VS(..), Image(..)
  ) where

import Prelude hiding (map, zipWith)
#if !MIN_VERSION_base(4,8,0)
import Data.Functor
#endif
import Data.Typeable (Typeable)
import qualified Data.Vector.Storable as VS
import Graphics.Image.Interface as I
import Graphics.Image.Interface.Vector.Generic



-- | Storable 'Vector' representation.
data VS = VS deriving Typeable

instance Show VS where
  show _ = "VectorStorable"

instance SuperClass VS cs e => BaseArray VS cs e where
  type SuperClass VS cs e =
    (ColorSpace cs e, VS.Storable (Pixel cs e))

  newtype Image VS cs e = VSImage (Image (G VS) cs e)

  dims (VSImage img) = dims img
  {-# INLINE dims #-}



instance (MArray VS cs e, BaseArray VS cs e) => Array VS cs e where

  type Manifest VS = VS
  
  type Vector VS = VS.Vector

  makeImage !sh = VSImage . makeImage sh
  {-# INLINE makeImage #-}

  makeImageWindowed !sh !window f g = VSImage $ makeImageWindowed sh window f g
  {-# INLINE makeImageWindowed #-}
  
  scalar = VSImage . scalar
  {-# INLINE scalar #-}

  index00 (VSImage img) = index00 img
  {-# INLINE index00 #-}
  
  map f (VSImage img) = VSImage $ I.map f img
  {-# INLINE map #-}

  imap f (VSImage img) = VSImage $ I.imap f img
  {-# INLINE imap #-}
  
  zipWith f (VSImage img1) (VSImage img2) = VSImage $ I.zipWith f img1 img2
  {-# INLINE zipWith #-}

  izipWith f (VSImage img1) (VSImage img2) = VSImage $ I.izipWith f img1 img2
  {-# INLINE izipWith #-}

  traverse (VSImage img) f g = VSImage $ I.traverse img f g
  {-# INLINE traverse #-}

  traverse2 (VSImage img1) (VSImage img2) f g = VSImage $ I.traverse2 img1 img2 f g
  {-# INLINE traverse2 #-}

  transpose (VSImage img) = VSImage $ I.transpose img
  {-# INLINE transpose #-}

  backpermute !sz f (VSImage img) = VSImage $ I.backpermute sz f img
  {-# INLINE backpermute #-}
  
  fromLists = VSImage . I.fromLists
  {-# INLINE fromLists #-}

  fold f !px0 (VSImage img) = fold f px0 img
  {-# INLINE fold #-}

  foldIx f !px0 (VSImage img) = foldIx f px0 img
  {-# INLINE foldIx #-}

  (|*|) (VSImage img1) (VSImage img2) = VSImage (img1 |*| img2)
  {-# INLINE (|*|) #-}

  eq (VSImage img1) (VSImage img2) = img1 == img2
  {-# INLINE eq #-}

  compute (VSImage img) = VSImage (compute img)
  {-# INLINE compute #-}

  toManifest = id
  {-# INLINE toManifest #-}

  toVector (VSImage (VImage _ _ v)) = v
  toVector (VSImage (VScalar px))   = VS.singleton px
  {-# INLINE toVector #-}

  fromVector !sz = VSImage . fromVector sz
  {-# INLINE fromVector #-}


instance BaseArray VS cs e => MArray VS cs e where
  
  newtype MImage s VS cs e = MVSImage (MImage s (G VS) cs e)
                              
  unsafeIndex (VSImage img) = unsafeIndex img
  {-# INLINE unsafeIndex #-}

  deepSeqImage (VSImage img) = deepSeqImage img
  {-# INLINE deepSeqImage #-}

  foldl f !px0 (VSImage img) = I.foldl f px0 img
  {-# INLINE foldl #-}

  foldr f !px0 (VSImage img) = I.foldr f px0 img
  {-# INLINE foldr #-}

  makeImageM !sh f = VSImage <$> makeImageM sh f
  {-# INLINE makeImageM #-}

  mapM f (VSImage img) = VSImage <$> I.mapM f img
  {-# INLINE mapM #-}

  mapM_ f (VSImage img) = I.mapM_ f img
  {-# INLINE mapM_ #-}

  foldM f !px0 (VSImage img) = I.foldM f px0 img
  {-# INLINE foldM #-}

  foldM_ f !px0 (VSImage img) = I.foldM_ f px0 img
  {-# INLINE foldM_ #-}

  mdims (MVSImage mimg) = mdims mimg
  {-# INLINE mdims #-}

  thaw (VSImage img) = MVSImage <$> I.thaw img
  {-# INLINE thaw #-}

  freeze (MVSImage img) = VSImage <$> I.freeze img
  {-# INLINE freeze #-}

  new !ix = MVSImage <$> I.new ix
  {-# INLINE new #-}

  read (MVSImage img) = I.read img
  {-# INLINE read #-}

  write (MVSImage img) = I.write img
  {-# INLINE write #-}

  swap (MVSImage img) = I.swap img
  {-# INLINE swap #-}
