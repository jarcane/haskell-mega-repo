{-# LANGUAGE DataKinds       #-}
{-# LANGUAGE InstanceSigs    #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE TypeFamilies    #-}
{-# LANGUAGE TypeOperators   #-}
module Futurice.App.Library.Types (
    AddBookInformation (..),
    AddBoardGameInformation (..),
    CoverData (..),
    boardgameName,
    boardgamePublisher,
    boardgamePublished,
    boardgameDesigner,
    boardgameArtist,
    boardgameInformationId,
    BoardGameInformation (..),
    BoardGameInformationResponse (..),
    BoardGames (..),
    boardgameResponseInformationId,
    boardgameResponseName,
    boardgameResponsePublisher,
    boardgameResponsePublished,
    boardgameResponseDesigner,
    boardgameResponseArtist,
    boardgameResponseGames,
    bookInformationId,
    bookTitle,
    bookISBN,
    bookAuthor,
    bookPublisher,
    bookPublished,
    bookCover,
    bookAmazonLink,
    BoardGameInformationId,
    BookInformation (..),
    BookInformationId,
    BookInformationResponse (..),
    BookInformationByISBNResponse (..),
    DataSource (..),
    EditBookInformation,
    editBookInformationId,
    editBookTitle,
    editBookISBN,
    editBookAuthor,
    editBookPublisher,
    editBookPublished,
    editBookAmazonLink,
    EditBoardGameInformation,
    editBoardGameInformationId,
    editBoardGameName,
    editBoardGamePublisher,
    editBoardGamePublished,
    editBoardGameDesigner,
    editBoardGameArtist,
    Books (..),
    BorrowRequest (..),
    Loan (..),
    loanId,
    loanInformation,
    Item (..),
    itemInfo,
    ItemId,
    ItemInfo (..),
    LoanId,
    Library (..),
    allLibraries,
    libraryToText,
    usedLibraries,
    BookSortCriteria (..),
    BoardGameSortCriteria (..),
    CriteriaAndData (..),
    SortCriteria (..),
    SortCriteriaAndStart (..),
    SortDirection (..)
    ) where

import Futurice.App.Library.Types.AddItemRequest
import Futurice.App.Library.Types.BoardGameInformation
import Futurice.App.Library.Types.BoardGameInformationResponse
import Futurice.App.Library.Types.BookInformation
import Futurice.App.Library.Types.BookInformationByISBNResponse
import Futurice.App.Library.Types.BookInformationResponse
import Futurice.App.Library.Types.BorrowRequest
import Futurice.App.Library.Types.EditItemRequest
import Futurice.App.Library.Types.Item
import Futurice.App.Library.Types.Library
import Futurice.App.Library.Types.Loan
import Futurice.App.Library.Types.Search
