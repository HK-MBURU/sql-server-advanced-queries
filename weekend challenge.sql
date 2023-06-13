CREATE DATABASE libraryManagementSystem
USE libraryManagementSystem
CREATE TABLE Books (
    BookID INT PRIMARY KEY,
    Title VARCHAR(255),
    Author VARCHAR(255),
    PublicationYear INT,
    Status VARCHAR(255)
);

CREATE TABLE Members (
    MemberID INT PRIMARY KEY,
    Name VARCHAR(255),
    Address VARCHAR(255),
    ContactNumber VARCHAR(255)
);

CREATE TABLE Loans (
    LoanID INT PRIMARY KEY,
    BookID INT,
    MemberID INT,
    LoanDate DATE,
    ReturnDate DATE
);


--trigger to update the status column in books table

CREATE OR ALTER TRIGGER update_book_status
ON Loans
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    
    UPDATE Books
    SET Status = 'Loaned'
    WHERE BookID IN (SELECT BookID FROM inserted);

    
    UPDATE Books
    SET Status = 'Available'
    WHERE BookID IN (SELECT BookID FROM deleted);
END;
GO

--cte to retrive the names of members who have borrowe atleast three books
WITH BorrowedBooks AS (
    SELECT MemberID, COUNT(*) AS NumBooksBorrowed
    FROM Loans
    GROUP BY MemberID
    HAVING COUNT(*) >= 3
)
SELECT M.Name
FROM Members M
INNER JOIN BorrowedBooks B ON M.MemberID = B.MemberID;

--userdefined function for calculating overdue days for a given loan
CREATE FUNCTION CalculateOverdueDays(@LoanID INT)
RETURNS INT
AS
BEGIN
    DECLARE @OverdueDays INT;
    DECLARE @ReturnDate DATE;

    SELECT @ReturnDate = ReturnDate
    FROM Loans
    WHERE LoanID = @LoanID;

    SET @OverdueDays = DATEDIFF(DAY, @ReturnDate, GETDATE());

    IF (@OverdueDays < 0)
        SET @OverdueDays = 0;

    RETURN @OverdueDays;
END;

--view to display details of all overdue loans
CREATE VIEW OverdueLoansView AS
SELECT B.Title, M.Name, DATEDIFF(DAY, L.ReturnDate, GETDATE()) AS OverdueDays
FROM Loans L
JOIN Books B ON L.BookID = B.BookID
JOIN Members M ON L.MemberID = M.MemberID
WHERE L.ReturnDate < GETDATE();


--Trigger to prevent a member from borrowing more than three books
CREATE OR ALTER TRIGGER prevent_exceeding_books_limit
ON Loans
INSTEAD OF INSERT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @MemberID INT;
    DECLARE @NumBooksBorrowed INT;

    SELECT @MemberID = MemberID
    FROM inserted;

    SELECT @NumBooksBorrowed = COUNT(*)
    FROM Loans
    WHERE MemberID = @MemberID;

    IF (@NumBooksBorrowed >= 3)
    BEGIN
        RAISERROR('Maximum borrowing limit exceeded for the member.', 16, 1);
        ROLLBACK TRANSACTION;
    END
    ELSE
    BEGIN
        INSERT INTO Loans (BookID, MemberID, LoanDate, ReturnDate)
        SELECT BookID, MemberID, LoanDate, ReturnDate
        FROM inserted;
    END
END;
GO


