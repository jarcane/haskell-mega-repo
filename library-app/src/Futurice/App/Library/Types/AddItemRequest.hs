{-# LANGUAGE DataKinds             #-}
{-# LANGUAGE InstanceSigs          #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE OverloadedStrings     #-}
{-# LANGUAGE TemplateHaskell       #-}
{-# LANGUAGE TypeFamilies          #-}
{-# LANGUAGE TypeOperators         #-}
module Futurice.App.Library.Types.AddItemRequest where

import Data.Char      (digitToInt, isDigit)
import Data.Text.Read (decimal)

import Futurice.Office   (offOther)
import Futurice.Prelude
import Prelude ()
import Servant.Multipart

import Futurice.App.Library.Types.BoardGameInformation
import Futurice.App.Library.Types.BookInformation
import Futurice.App.Library.Types.Library

import qualified Data.ByteString.Lazy as DBL
import qualified Data.Text            as T

data CoverData = CoverData (FileData Mem)
               | CoverUrl Text
               deriving Show

data AddBookInformation = AddBookInformation
    { _addBookTitle                  :: !Text
    , _addBookISBN                   :: !Text
    , _addBookAuthor                 :: !Text
    , _addBookPublisher              :: !Text
    , _addBookPublished              :: !Int
    , _addBookAmazonLink             :: !Text
    , _addBookLibraries              :: ![(Library, Int)]
    , _addBookCover                  :: !CoverData
    , _addBookInformationId          :: !(Maybe BookInformationId)
    } deriving Show

data AddBoardGameInformation = AddBoardGameInformation
    { _addBoardgameName           :: !Text
    , _addBoardgamePublisher      :: !(Maybe Text)
    , _addBoardgamePublished      :: !(Maybe Int)
    , _addBoardgameDesigner       :: !(Maybe Text)
    , _addBoardgameArtist         :: !(Maybe Text)
    , _addBoardgameLibrary        :: ![(Library, Int)]
    }
    deriving Show

data AddItemRequest = AddItemRequest
    { _addItemLibrary                :: !Library
    , _addItemBookInformationId      :: !(Maybe BookInformationId)
    , _addItemBoardGameInformationId :: !(Maybe BoardGameInformationId)
    }
    deriving (Show, Generic)

-- Order alphabetically, but make sure Elibrary is last
librarySelectSortOrder :: Library -> Library -> Ordering
librarySelectSortOrder a b = case (a,b) of
                        (Elibrary, Elibrary) -> EQ
                        (Elibrary, _) -> GT
                        (_, Elibrary) -> LT
                        _ -> compare (libraryToText a) (libraryToText b)

usedLibraries :: [Library]
usedLibraries = let isKnownLibrary lib = (lib /= OfficeLibrary offOther) && (lib /= UnknownLibrary)
                    usedLibs = filter isKnownLibrary allLibraries
                in sortBy librarySelectSortOrder usedLibs

fromtextToInt :: Text -> Maybe Int
fromtextToInt t = case decimal t of
    Left _ -> Nothing
    Right (num,_) -> Just num

lookupInputAndClean :: Text -> MultipartData a -> Maybe Text
lookupInputAndClean a b = T.strip <$> lookupInput a b

booksPerLibrary :: MultipartData a -> [(Library, Int)]
booksPerLibrary dt = catMaybes $ map (\l -> sequence (l, lookupInputAndClean ("amount-" <> libraryToText l) dt >>= fromtextToInt)) $ usedLibraries

validateISBN :: Text -> Maybe Text
validateISBN isbn = if all isDigit isbnString && isbncheck then Just isbn else Nothing
  where
    isbnString = T.unpack isbn
    isbncheck | length isbnString == 10 = isbn10check
              | length isbnString == 13 = isbn13check
              | otherwise = False
    isbn10check = mod (sum $ zipWith (\letter number -> digitToInt letter * number) isbnString (reverse [1..10])) 11 == 0
    isbn13check = mod (sum $ zipWith (\letter number -> digitToInt letter * number) isbnString (cycle [1,3])) 10 == 0

instance FromMultipart Mem AddBookInformation where
    fromMultipart multipartData = AddBookInformation
        <$> lookupInputAndClean "title" multipartData
        <*> (lookupInputAndClean "isbn" multipartData >>= (validateISBN . T.filter (/= '-')))
        <*> lookupInputAndClean "author" multipartData
        <*> lookupInputAndClean "publisher" multipartData
        <*> (lookupInputAndClean "published" multipartData >>= readMaybe . T.unpack)
        <*> lookupInputAndClean "amazon-link" multipartData
        <*> pure (booksPerLibrary multipartData)
        <*> cover
        <*> pure (BookInformationId <$> fromIntegral <$> (lookupInputAndClean "bookinformationid" multipartData >>= fromtextToInt))
      where
        isEmptyT t | T.null t = Nothing
                   | otherwise = Just t
        isEmptyB b | DBL.null (fdPayload b) = Nothing
                   | otherwise = Just b
        cover = (CoverUrl <$> (lookupInput "cover-url" multipartData >>= isEmptyT)) <|> (CoverData <$> (lookupFile "cover-file" multipartData >>= isEmptyB))

instance FromMultipart Mem AddBoardGameInformation where
    fromMultipart multipartData = AddBoardGameInformation
        <$> lookupInputAndClean "name" multipartData
        <*> pure (lookupInputAndClean "publisher" multipartData)
        <*> pure (lookupInputAndClean "published" multipartData >>= fromtextToInt)
        <*> pure (lookupInputAndClean "designer" multipartData)
        <*> pure (lookupInputAndClean "artist" multipartData)
        <*> pure (booksPerLibrary multipartData)

instance FromMultipart Mem AddItemRequest where
    fromMultipart multipartData = AddItemRequest
        <$> (libraryFromText <$> lookupInputAndClean "library" multipartData)
        <*> pure (lookupInputAndClean "bookinformationid" multipartData >>= readMaybe . T.unpack)
        <*> pure (lookupInputAndClean "boardgameinformationid" multipartData >>= readMaybe . T.unpack)
