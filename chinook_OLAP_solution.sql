DROP SCHEMA IF EXISTS `chinook_olap`;

CREATE SCHEMA `chinook_olap`;

USE `chinook_olap`;

DELIMITER //

DROP PROCEDURE IF EXISTS `chinook_olap`.`create_dim_customers` //
CREATE PROCEDURE `chinook_olap`.`create_dim_customers`()
BEGIN
    DROP TABLE IF EXISTS `chinook_olap`.`Customer_Dim`;
    CREATE TABLE `chinook_olap`.`Customer_Dim` (
        `CustomerID` INT NOT NULL,
        `FirstName` VARCHAR(40) NOT NULL,
        `LastName` VARCHAR(20) NOT NULL,
        `Company` VARCHAR(80),
        `Address` VARCHAR(70),
        `City` VARCHAR(40),
        `State` VARCHAR(40),
        `Country` VARCHAR(40),
        `PostalCode` VARCHAR(10),
        `Phone` VARCHAR(24),
        `Fax` VARCHAR(24),
        `Email` VARCHAR(60) NOT NULL,
        PRIMARY KEY (`CustomerID`)
    );
    ALTER TABLE `chinook_olap`.`Customer_Dim`
        ADD COLUMN `CreateDate` DATETIME NULL DEFAULT CURRENT_TIMESTAMP,
        ADD COLUMN `UpdateDate` DATETIME NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP;

    INSERT INTO `chinook_olap`.`Customer_Dim`
        (`CustomerID`, `FirstName`, `LastName`, `Company`, `Address`, `City`, `State`, `Country`, `PostalCode`, `Phone`, `Fax`, `Email`)
    SELECT 
        `CustomerId`, `FirstName`, `LastName`, `Company`, `Address`, `City`, `State`, `Country`, `PostalCode`, `Phone`, `Fax`, `Email`
    FROM `Chinook_oltp`.`Customer`;
END //
DELIMITER ;


DELIMITER //
DROP PROCEDURE IF EXISTS `chinook_olap`.`create_dim_tracks` //
CREATE PROCEDURE `chinook_olap`.`create_dim_tracks`()
BEGIN
    DROP TABLE IF EXISTS `chinook_olap`.`Track_Dim`;

    CREATE TABLE `chinook_olap`.`Track_Dim` (
        `TrackID` INT NOT NULL,
        `TrackName` VARCHAR(200) NOT NULL,
        `AlbumTitle` VARCHAR(160),
        `ArtistName` VARCHAR(120),
        `GenreName` VARCHAR(120),
        `Composer` VARCHAR(220),
        `Milliseconds` INT,
        `Bytes` INT,
        `UnitPrice` DECIMAL(10,2),
        PRIMARY KEY (`TrackID`)
    );

    ALTER TABLE `chinook_olap`.`Track_Dim`
        ADD COLUMN `CreateDate` DATETIME NULL DEFAULT CURRENT_TIMESTAMP,
        ADD COLUMN `UpdateDate` DATETIME NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP;

    INSERT INTO `chinook_olap`.`Track_Dim`
        (`TrackID`, `TrackName`, `AlbumTitle`, `ArtistName`, `GenreName`, `Composer`, `Milliseconds`, `Bytes`, `UnitPrice`)
    SELECT 
        t.`TrackId`,
        t.`Name` AS `TrackName`,
        al.`Title` AS `AlbumTitle`,
        ar.`Name` AS `ArtistName`,
        g.`Name` AS `GenreName`,
        t.`Composer`,
        t.`Milliseconds`,
        t.`Bytes`,
        t.`UnitPrice`
    FROM `Chinook_oltp`.`Track` t
    LEFT JOIN `Chinook_oltp`.`Album` al ON t.`AlbumId` = al.`AlbumId`
    LEFT JOIN `Chinook_oltp`.`Artist` ar ON al.`ArtistId` = ar.`ArtistId`
    LEFT JOIN `Chinook_oltp`.`Genre` g ON t.`GenreId` = g.`GenreId`;
END //
DELIMITER ;

DELIMITER //
DROP PROCEDURE IF EXISTS `chinook_olap`.`create_dim_date` //
CREATE PROCEDURE `chinook_olap`.`create_dim_date`(IN start_year INT, IN end_year INT)
BEGIN
    DECLARE current_dt DATE;
    DECLARE end_dt DATE;

    DROP TABLE IF EXISTS `chinook_olap`.`Date_Dim`;
    CREATE TABLE `chinook_olap`.`Date_Dim` (
        `DateID` BIGINT NOT NULL,          -- Formatted YYYYMMDD
        `Date` DATE NOT NULL,
        `Year` INT NOT NULL,
        `Quarter` INT NOT NULL,
        `Month` INT NOT NULL,
        `MonthName` VARCHAR(20) NOT NULL,
        `Day` INT NOT NULL,
        `DayOfWeekName` VARCHAR(20) NOT NULL,
        `WeekendIndicator` VARCHAR(10) NOT NULL DEFAULT 'Weekday',
        PRIMARY KEY (`DateID`),
        UNIQUE KEY `UK_Date` (`Date`)
    );

    SET current_dt = MAKEDATE(start_year, 1);
    SET end_dt = MAKEDATE(end_year + 1, 1) - INTERVAL 1 DAY;

    WHILE current_dt <= end_dt DO
        INSERT INTO `chinook_olap`.`Date_Dim` (
            `DateID`, `Date`, `Year`, `Quarter`, `Month`, `MonthName`, `Day`, `DayOfWeekName`, `WeekendIndicator`
        ) VALUES (
            CAST(DATE_FORMAT(current_dt, '%Y%m%d') AS UNSIGNED),
            current_dt,
            YEAR(current_dt),
            QUARTER(current_dt),
            MONTH(current_dt),
            MONTHNAME(current_dt),
            DAY(current_dt),
            DAYNAME(current_dt),
            IF(DAYOFWEEK(current_dt) IN (1, 7), 'Weekend', 'Weekday')
        );
        SET current_dt = current_dt + INTERVAL 1 DAY;
    END WHILE;
END //
DELIMITER ;

DELIMITER //
DROP PROCEDURE IF EXISTS `chinook_olap`.`create_fact_invoice` //
CREATE PROCEDURE `chinook_olap`.`create_fact_invoice`()
BEGIN
    DROP TABLE IF EXISTS `chinook_olap`.`Invoice_Fact`;

    CREATE TABLE `chinook_olap`.`Invoice_Fact` (
        `InvoiceID` INT NOT NULL,
        `TrackID` INT NOT NULL,
        `CustomerID` INT NOT NULL,
        `SaleDateID` BIGINT NOT NULL,
        `TotalQuantity` INT NOT NULL,
        `TotalAmount` DECIMAL(10,2) NOT NULL,
        PRIMARY KEY (`InvoiceID`, `TrackID`),
        CONSTRAINT `FK_Fact_Customer` FOREIGN KEY (`CustomerID`) REFERENCES `chinook_olap`.`Customer_Dim`(`CustomerID`) ON DELETE NO ACTION,
        CONSTRAINT `FK_Fact_Track` FOREIGN KEY (`TrackID`) REFERENCES `chinook_olap`.`Track_Dim`(`TrackID`) ON DELETE NO ACTION,
        CONSTRAINT `FK_Fact_Date` FOREIGN KEY (`SaleDateID`) REFERENCES `chinook_olap`.`Date_Dim`(`DateID`) ON DELETE NO ACTION
    );

    INSERT INTO `chinook_olap`.`Invoice_Fact`
        (`InvoiceID`, `TrackID`, `CustomerID`, `SaleDateID`, `TotalQuantity`, `TotalAmount`)
    SELECT 
        il.`InvoiceId`,
        il.`TrackId`,
        i.`CustomerId`,
        CAST(DATE_FORMAT(i.`InvoiceDate`, '%Y%m%d') AS UNSIGNED) AS `SaleDateID`,
        SUM(il.`Quantity`) AS `TotalQuantity`,
        SUM(il.`UnitPrice` * il.`Quantity`) AS `TotalAmount`
    FROM `Chinook_oltp`.`InvoiceLine` il
    JOIN `Chinook_oltp`.`Invoice` i ON il.`InvoiceId` = i.`InvoiceId`
    GROUP BY 
        il.`InvoiceId`,
        il.`TrackId`,
        i.`CustomerId`,
        CAST(DATE_FORMAT(i.`InvoiceDate`, '%Y%m%d') AS UNSIGNED);
END //
DELIMITER ;

CALL `chinook_olap`.`create_dim_customers`();
CALL `chinook_olap`.`create_dim_tracks`();
CALL `chinook_olap`.`create_dim_date`(2009, 2013);
CALL `chinook_olap`.`create_fact_invoice`();

DROP VIEW IF EXISTS `chinook_olap`.`Chinook_Datamart`;
CREATE VIEW `chinook_olap`.`Chinook_Datamart` AS
SELECT 
    f.`InvoiceID`,
    f.`TotalQuantity`,
    f.`TotalAmount`,
    d.`DateID` AS `DateKey`,
    d.`Date` AS `InvoiceDate`,
    d.`Year` AS `InvoiceYear`,
    d.`Quarter` AS `InvoiceQuarter`,
    d.`Month` AS `InvoiceMonth`,
    d.`MonthName` AS `InvoiceMonthName`,
    d.`Day` AS `InvoiceDay`,
    d.`DayOfWeekName`,
    d.`WeekendIndicator`,
    c.`CustomerID`,
    c.`FirstName` AS `CustomerFirstName`,
    c.`LastName` AS `CustomerLastName`,
    c.`Company` AS `CustomerCompany`,
    c.`City` AS `CustomerCity`,
    c.`State` AS `CustomerState`,
    c.`Country` AS `CustomerCountry`,
    c.`PostalCode` AS `CustomerPostalCode`,
    c.`Phone` AS `CustomerPhone`,
    c.`Email` AS `CustomerEmail`,
    t.`TrackID`,
    t.`TrackName`,
    t.`Composer`,
    t.`AlbumTitle`,
    t.`ArtistName`,
    t.`GenreName`,
    t.`UnitPrice` AS `TrackUnitPrice`,
    t.`Milliseconds` AS `TrackMilliseconds`,
    t.`Bytes` AS `TrackBytes`
FROM `chinook_olap`.`Invoice_Fact` f
LEFT JOIN `chinook_olap`.`Customer_Dim` c ON f.`CustomerID` = c.`CustomerID`
LEFT JOIN `chinook_olap`.`Track_Dim` t ON f.`TrackID` = t.`TrackID`
LEFT JOIN `chinook_olap`.`Date_Dim` d ON f.`SaleDateID` = d.`DateID`;

-- Verification Queries (Optional checks for yourself)

SELECT COUNT(*) AS CustomerCount FROM `chinook_olap`.`Customer_Dim`;
SELECT COUNT(*) AS TrackCount FROM `chinook_olap`.`Track_Dim`;
SELECT COUNT(*) AS DateDaysCount FROM `chinook_olap`.`Date_Dim`;
SELECT COUNT(*) AS FactRowCount FROM `chinook_olap`.`Invoice_Fact`;
SELECT SUM(TotalAmount) AS OLAP_Total FROM `chinook_olap`.`Invoice_Fact`;
SELECT SUM(Total) AS OLTP_Total FROM `Chinook_oltp`.`Invoice`;
SELECT * FROM `chinook_olap`.`Chinook_Datamart` LIMIT 10;