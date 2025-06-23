USE learning;
GO

DROP TABLE IF EXISTS house_star.fact_house_sales;
DROP TABLE IF EXISTS house_star.dim_time;
DROP TABLE IF EXISTS house_star.dim_location;
DROP TABLE IF EXISTS house_star.dim_house;
GO
-- 1.1 Tạo bảng dim_location với ID tự tăng
CREATE TABLE house_star.dim_location (
    location_id INT IDENTITY(1,1) PRIMARY KEY,
    zipcode BIGINT,
    lat FLOAT,
    long FLOAT
);
GO

-- 1.2 Insert giá trị duy nhất
INSERT INTO house_star.dim_location(zipcode, lat, long)
SELECT DISTINCT zipcode, lat, long
FROM staging.sales;
GO

CREATE TABLE house_star.dim_house (
    house_id INT IDENTITY(1,1) PRIMARY KEY,
    bedrooms INT,
    bathrooms FLOAT,
    floors FLOAT,
    sqft_living INT,
    sqft_lot INT,
    sqft_above INT,
    sqft_basement INT,
    waterfront BIT,
    [view] INT,
    [condition] INT,
    grade INT,
    sqft_living15 INT,
    sqft_lot15 INT
);
GO

INSERT INTO house_star.dim_house(
    bedrooms, bathrooms, floors, sqft_living, sqft_lot, 
    sqft_above, sqft_basement, waterfront, [view], [condition], 
    grade, sqft_living15, sqft_lot15
)
SELECT DISTINCT
    bedrooms, bathrooms, floors, sqft_living, sqft_lot, 
    sqft_above, sqft_basement, waterfront, [view], [condition], 
    grade, sqft_living15, sqft_lot15
FROM staging.sales;
GO

CREATE TABLE house_star.dim_time (
    date_id INT IDENTITY(1,1) PRIMARY KEY,
    sold_date DATETIME,
    yr_built INT,
    yr_renovated INT
);
INSERT INTO house_star.dim_time(sold_date, yr_built, yr_renovated)
SELECT DISTINCT 
    CONVERT(DATETIME, 
        STUFF(
            STUFF(
                STUFF([date], 9, 0, ' '),     -- 20141107T -> 20141107 T
                12, 0, ':'),                 -- ...000000 -> ...00:00:00
            15, 0, ':'), 120),              -- kết quả: 2014-11-07 00:00:00
    yr_built,
    yr_renovated
FROM staging.sales
WHERE ISDATE(
    STUFF(STUFF(STUFF([date], 9, 0, ' '), 12, 0, ':'), 15, 0, ':')
) = 1;
GO


CREATE TABLE house_star.fact_house_sales (
    sale_id INT PRIMARY KEY,
    house_id INT FOREIGN KEY REFERENCES house_star.dim_house(house_id),
    location_id INT FOREIGN KEY REFERENCES house_star.dim_location(location_id),
    date_id INT FOREIGN KEY REFERENCES house_star.dim_time(date_id),
    price FLOAT
);
GO

-- Giả sử staging.sales có cột `id` là khóa chính gốc
INSERT INTO house_star.fact_house_sales(sale_id, house_id, location_id, date_id, price)
SELECT 
    s.id,
    h.house_id,
    l.location_id,
    t.date_id,
    s.price
FROM staging.sales s
JOIN house_star.dim_house h
    ON s.bedrooms = h.bedrooms AND s.bathrooms = h.bathrooms AND s.floors = h.floors
       AND s.sqft_living = h.sqft_living AND s.sqft_lot = h.sqft_lot
       AND s.sqft_above = h.sqft_above AND s.sqft_basement = h.sqft_basement
       AND s.waterfront = h.waterfront AND s.[view] = h.[view] AND s.[condition] = h.[condition]
       AND s.grade = h.grade AND s.sqft_living15 = h.sqft_living15 AND s.sqft_lot15 = h.sqft_lot15
JOIN house_star.dim_location l
    ON s.zipcode = l.zipcode AND s.lat = l.lat AND s.long = l.long
JOIN house_star.dim_time t
    ON s.[date] = t.sold_date AND s.yr_built = t.yr_built AND s.yr_renovated = t.yr_renovated;
GO


