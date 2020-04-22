SELECT
  Property.LOCID                                                                         AS Location_ID,
  Property.LOCNUM                                                                        AS Location_Number,
  Property.LOCNAME                                                                       AS Location_Name,
  Property.NUMBLDGS                                                                      AS Number_of_Buildings,
  Property.BLDGSCHEME                                                                    AS Temp_RiskModelDB_BLDGSCHEME,
  Property.BLDGCLASS                                                                     AS Temp_RiskModelDB_BLDGCLASS,
  ''                                                                                   AS Construction_Type,
  Property.OCCSCHEME                                                                     AS Temp_RiskModelDB_OCCSCHEME,
  Property.OCCTYPE                                                                       AS Temp_RiskModelDB_OCCTYPE,
  ''                                                                                   AS Occupancy_Type,
  Property.NUMSTORIES                                                                    AS Number_of_Stories,
  cast(Month(Property.YEARBUILT) AS VARCHAR) + '/' + cast(Day(Property.YEARBUILT) AS VARCHAR) + '/' +
  cast(YEAR(Property.YEARBUILT) AS VARCHAR)                                              AS Year_Built,
  Property.FLOORAREA                                                                     AS Floor_Area,
  CASE property.AREAUNIT
  WHEN 2
    THEN 'Square Feet'
  WHEN 4
    THEN 'Square Meters'
  ELSE 'n/a' END                                                                       AS Floor_Area_Unit,
  cast(Month(Property.INCEPTDATE) AS VARCHAR) + '/' + cast(Day(Property.INCEPTDATE) AS VARCHAR) + '/' +
  cast(YEAR(Property.INCEPTDATE) AS VARCHAR)                                             AS Location_Inception_Date,
  cast(Month(Property.EXPIREDATE) AS VARCHAR) + '/' + cast(Day(Property.EXPIREDATE) AS VARCHAR) + '/' +
  cast(YEAR(Property.EXPIREDATE) AS VARCHAR)                                             AS Location_Expiration_Date,
  Property.PRIMARYLOCID                                                                  AS Primary_Location_ID,
  Property.SITENAME                                                                      AS Site_Name,
  Property.USERID1                                                                       AS User_ID_1,
  Property.USERID2                                                                       AS User_ID_2,
  Property.USERTXT1                                                                      AS User_Text_1,
  Property.USERTXT2                                                                      AS User_Text_2,
  Address.CountryScheme                                                                  AS Temp_RiskModelDB_CountryScheme,
  Address.CountryCode                                                                    AS Temp_RiskModelDB_CountryCode,
  ''                                                                                   AS Country_Code_FIPS,
  ''                                                                                   AS Country_Name,
  COALESCE(NULLIF(Address.Admin1Name,''), Address.Admin1Code)                          AS State,
  Address.Admin2Name                                                                     AS County,
  Address.CityName                                                                       AS City,
  Address.PostalCode                                                                     AS Postal_Code,
  Replace(Replace(Address.StreetAddress, ',', ''), '"', '')                      AS Street,
  Address.Latitude,
  Address.Longitude,
  Address.GeoResolutionCode                                                              AS RiskModelDB_Geocode_Resolution,
  CASE address.georesolutioncode
  WHEN 0
    THEN -80
  WHEN 1
    THEN -1
  WHEN 2
    THEN -10
  WHEN 3
    THEN 31
  WHEN 4
    THEN 1
  WHEN 5
    THEN 4
  WHEN 6
    THEN 5
  WHEN 7
    THEN 5
  WHEN 8
    THEN 5
  WHEN 9
    THEN 6
  WHEN 10
    THEN 7
  WHEN 11
    THEN 10
  WHEN 12
    THEN 0
  WHEN 13
    THEN 0
  WHEN 14
    THEN 9
  ELSE 0 END                                                                             AS Geocode_Resolution,
  neweqdet.Soil_Type_Description,
  accgrp.ACCGRPNUM                                                                       AS Account_Number,
  accgrp.ACCGRPID                                                                        AS Account_ID,
  accgrp.ACCGRPNAME                                                                      AS Account_Name,
  newfldet.FLZONE                                                                        AS RiskModelDB_FL_Zone,
  newfldet.BFE                                                                           AS RiskModelDB_BFE,
  newfldet.SFHA                                                                          AS RiskModelDB_SFHA,
  newfldet.ANNPROB                                                                       AS RiskModelDB_Annual_FL_Probability,
  newfldet.OTHERZONES                                                                    AS RiskModelDB_FL_Other_Zones,
  newhudet.DISTCOAST                                                                     AS Distance_to_Coast,
  dbo.ufnCurrencyConversion(neweqdet.SITELIMAMT, neweqdet.SITELIMCUR, @CurrencyTo, @IsCurrencyConvert, 0) AS EQ_Site_Limit,
  dbo.ufnCurrencyConversion(neweqdet.SITEDEDAMT, neweqdet.SITEDEDCUR, @CurrencyTo, @IsCurrencyConvert, 1) AS EQ_Site_Deductible,
  dbo.ufnCurrencyConversion(newfldet.SITELIMAMT, newfldet.SITELIMCUR, @CurrencyTo, @IsCurrencyConvert, 0) AS FL_Site_Limit,
  dbo.ufnCurrencyConversion(newfldet.SITEDEDAMT, newfldet.SITEDEDCUR, @CurrencyTo, @IsCurrencyConvert, 1) AS FL_Site_Deductible,
  dbo.ufnCurrencyConversion(newfrdet.SITELIMAMT, newfrdet.SITELIMCUR, @CurrencyTo, @IsCurrencyConvert, 0) AS FR_Site_Limit,
  dbo.ufnCurrencyConversion(newfrdet.SITEDEDAMT, newfrdet.SITEDEDCUR, @CurrencyTo, @IsCurrencyConvert, 1) AS FR_Site_Deductible,
  dbo.ufnCurrencyConversion(newhudet.SITELIMAMT, newhudet.SITELIMCUR, @CurrencyTo, @IsCurrencyConvert, 0) AS HU_Site_Limit,
  dbo.ufnCurrencyConversion(newhudet.SITEDEDAMT, newhudet.SITEDEDCUR, @CurrencyTo, @IsCurrencyConvert, 1) AS HU_Site_Deductible,
  dbo.ufnCurrencyConversion(newtodet.SITELIMAMT, newtodet.SITELIMCUR, @CurrencyTo, @IsCurrencyConvert, 0) AS TO_Site_Limit,
  dbo.ufnCurrencyConversion(newtodet.SITEDEDAMT, newtodet.SITEDEDCUR, @CurrencyTo, @IsCurrencyConvert, 1) AS TO_Site_Deductible,
  dbo.ufnCurrencyConversion(newtrdet.SITELIMAMT, newtrdet.SITELIMCUR, @CurrencyTo, @IsCurrencyConvert, 0) AS TR_Site_Limit,
  dbo.ufnCurrencyConversion(newtrdet.SITEDEDAMT, newtrdet.SITEDEDCUR, @CurrencyTo, @IsCurrencyConvert, 1) AS TR_Site_Deductible,
  NEWLOCCVG.EQ_Building_Value,
  NEWLOCCVG.EQ_Other_Structures_Value,
  NEWLOCCVG.EQ_Contents_Value,
  NEWLOCCVG.EQ_Business_Interruption_Value,
  NEWLOCCVG.EQ_Combined_Value,
  NEWLOCCVG.WS_Building_Value,
  NEWLOCCVG.WS_Other_Structures_Value,
  NEWLOCCVG.WS_Contents_Value,
  NEWLOCCVG.WS_Business_Interruption_Value,
  NEWLOCCVG.WS_Combined_Value,
  NEWLOCCVG.TO_Building_Value,
  NEWLOCCVG.TO_Contents_Value,
  NEWLOCCVG.TO_Other_Structures_Value,
  NEWLOCCVG.TO_Combined_Value,
  NEWLOCCVG.TO_Business_Interruption_Value,
  NEWLOCCVG.FL_Building_Value,
  NEWLOCCVG.FL_Other_Structures_Value,
  NEWLOCCVG.FL_Contents_Value,
  NEWLOCCVG.FL_Business_Interruption_Value,
  NEWLOCCVG.FL_Combined_Value,
  NEWLOCCVG.FR_Building_Value,
  NEWLOCCVG.FR_Other_Structures_Value,
  NEWLOCCVG.FR_Contents_Value,
  NEWLOCCVG.FR_Business_Interruption_Value,
  NEWLOCCVG.FR_Combined_Value,
  NEWLOCCVG.TR_Building_Value,
  NEWLOCCVG.TR_Other_Structures_Value,
  NEWLOCCVG.TR_Contents_Value,
  NEWLOCCVG.TR_Business_Interruption_Value,
  NEWLOCCVG.TR_Combined_Value,
  (SELECT max(v)
   FROM (VALUES (EQ_TIV), (WS_TIV), (TO_TIV), (FL_TIV), (FR_TIV), (TR_TIV)) AS value(v)) AS Total_Insured_Value,
  ''									   AS Special_Conditions,
  ''									   AS Special_Conditions_Count
FROM Property
  INNER JOIN Address ON Property.AddressID = Address.AddressID
  INNER JOIN accgrp ON Property.ACCGRPID = accgrp.ACCGRPID
  INNER JOIN portacct ON accgrp.ACCGRPID = portacct.ACCGRPID
  INNER JOIN portinfo ON portacct.PORTINFOID = portinfo.PORTINFOID
  LEFT OUTER JOIN (SELECT
                     locid,
                     sitelimamt,sitelimcur,
                     sitededamt,sitededcur
                   FROM todet
                   WHERE ISVALID = 1) AS NEWTODET ON Property.LOCID = newtodet.LOCID
  LEFT OUTER JOIN (SELECT
                     locid,
                     sitelimamt,sitelimcur,
                     sitededamt,sitededcur
                   FROM trdet
                   WHERE ISVALID = 1) AS NEWTRDET ON Property.LOCID = newtrdet.LOCID
  LEFT OUTER JOIN (SELECT
                     locid,
                     sitelimamt,sitelimcur,
                     sitededamt,sitededcur,
                     DISTCOAST
                   FROM hudet
                   WHERE ISVALID = 1) AS NEWHUDET ON Property.LOCID = newhudet.LOCID
  LEFT OUTER JOIN (SELECT
                     locid,
                     sitelimamt,sitelimcur,
                     sitededamt,sitededcur
                   FROM frdet
                   WHERE ISVALID = 1) AS NEWFRDET ON Property.LOCID = newfrdet.locid
  LEFT OUTER JOIN (SELECT
                     locid,
                     sitelimamt,sitelimcur,
                     sitededamt,sitededcur,
                     FLZONE,
                     bfe,
                     sfha,
                     ANNPROB,
                     OTHERZONES
                   FROM fldet
                   WHERE ISVALID = 1) AS NEWFLDET ON Property.LOCID = newfldet.locid
  LEFT OUTER JOIN (SELECT
                     locid,
                     sitelimamt,sitelimcur,
                     sitededamt,sitededcur,
                     CASE WHEN soiltype >= 1 AND soiltype <= 1.25
                       THEN 'Rock'
                     WHEN soiltype > 1.25 AND soiltype <= 1.75
                       THEN 'Rock to Soft Rock'
                     WHEN soiltype > 1.75 AND soiltype <= 2.25
                       THEN 'Soft Rock'
                     WHEN soiltype > 2.25 AND soiltype <= 2.75
                       THEN 'Soft Rock to Stiff Soil'
                     WHEN soiltype > 2.75 AND soiltype <= 3.25
                       THEN 'Stiff Soil'
                     WHEN soiltype > 3.25 AND soiltype <= 3.75
                       THEN 'Stiff to Soft Soil'
                     WHEN soiltype > 3.75 AND soiltype <= 4
                       THEN 'Soft Soil'
                     ELSE '' END AS Soil_Type_Description
                   FROM eqdet
                   WHERE ISVALID = 1) AS NEWEQDET ON Property.LOCID = neweqdet.LOCID
  LEFT OUTER JOIN (SELECT
                     LOCID,
                     SUM(CASE WHEN LabelID IN (7, 8, 9, 28, 29, 30, 31, 50)
                       THEN dbo.ufnCurrencyConversion(VALUEAMT, VALUECUR, @CurrencyTo, @IsCurrencyConvert, 0)
                         ELSE 0 END) AS EQ_TIV,
                     SUM(CASE WHEN LabelID IN (14, 15, 16, 24, 25, 26, 27, 51)
                       THEN dbo.ufnCurrencyConversion(VALUEAMT, VALUECUR, @CurrencyTo, @IsCurrencyConvert, 0)
                         ELSE 0 END) AS WS_TIV,
                     SUM(CASE WHEN LabelID IN (1, 2, 3, 32, 33, 34, 35, 52)
                       THEN dbo.ufnCurrencyConversion(VALUEAMT, VALUECUR, @CurrencyTo, @IsCurrencyConvert, 0)
                         ELSE 0 END) AS TO_TIV,
                     SUM(CASE WHEN LabelID IN (20, 21, 22, 36, 37, 38, 39, 53)
                       THEN dbo.ufnCurrencyConversion(VALUEAMT, VALUECUR, @CurrencyTo, @IsCurrencyConvert, 0)
                         ELSE 0 END) AS FL_TIV,
                     SUM(CASE WHEN LabelID IN (4, 5, 6, 40, 41, 42, 43, 54)
                       THEN dbo.ufnCurrencyConversion(VALUEAMT, VALUECUR, @CurrencyTo, @IsCurrencyConvert, 0)
                         ELSE 0 END) AS FR_TIV,
                     SUM(CASE WHEN LabelID IN (10, 11, 12, 44, 45, 46, 47, 55)
                       THEN dbo.ufnCurrencyConversion(VALUEAMT, VALUECUR, @CurrencyTo, @IsCurrencyConvert, 0)
                         ELSE 0 END) AS TR_TIV,
                     SUM(CASE WHEN LossType = 1 AND LabelID IN (7, 28)
                       THEN dbo.ufnCurrencyConversion(VALUEAMT, VALUECUR, @CurrencyTo, @IsCurrencyConvert, 0)
                         ELSE 0 END) AS EQ_Building_Value,
                     SUM(CASE WHEN LossType = 1 AND LabelID IN (29)
                       THEN dbo.ufnCurrencyConversion(VALUEAMT, VALUECUR, @CurrencyTo, @IsCurrencyConvert, 0)
                         ELSE 0 END) AS EQ_Other_Structures_Value,
                     SUM(CASE WHEN LossType = 2 AND LabelID IN (8, 30)
                       THEN dbo.ufnCurrencyConversion(VALUEAMT, VALUECUR, @CurrencyTo, @IsCurrencyConvert, 0)
                         ELSE 0 END) AS EQ_Contents_Value,
                     SUM(CASE WHEN LossType = 3 AND LabelID IN (9, 31)
                       THEN dbo.ufnCurrencyConversion(VALUEAMT, VALUECUR, @CurrencyTo, @IsCurrencyConvert, 0)
                         ELSE 0 END) AS EQ_Business_Interruption_Value,
                     SUM(CASE WHEN LossType = 4 AND LabelID IN (50)
                       THEN dbo.ufnCurrencyConversion(VALUEAMT, VALUECUR, @CurrencyTo, @IsCurrencyConvert, 0)
                         ELSE 0 END) AS EQ_Combined_Value,
                     SUM(CASE WHEN LossType = 1 AND LabelID IN (14, 24)
                       THEN dbo.ufnCurrencyConversion(VALUEAMT, VALUECUR, @CurrencyTo, @IsCurrencyConvert, 0)
                         ELSE 0 END) AS WS_Building_Value,
                     SUM(CASE WHEN LossType = 1 AND LabelID IN (25)
                       THEN dbo.ufnCurrencyConversion(VALUEAMT, VALUECUR, @CurrencyTo, @IsCurrencyConvert, 0)
                         ELSE 0 END) AS WS_Other_Structures_Value,
                     SUM(CASE WHEN LossType = 2 AND LabelID IN (15, 26)
                       THEN dbo.ufnCurrencyConversion(VALUEAMT, VALUECUR, @CurrencyTo, @IsCurrencyConvert, 0)
                         ELSE 0 END) AS WS_Contents_Value,
                     SUM(CASE WHEN LossType = 3 AND LabelID IN (16, 27)
                       THEN dbo.ufnCurrencyConversion(VALUEAMT, VALUECUR, @CurrencyTo, @IsCurrencyConvert, 0)
                         ELSE 0 END) AS WS_Business_Interruption_Value,
                     SUM(CASE WHEN LossType = 4 AND LabelID IN (51)
                       THEN dbo.ufnCurrencyConversion(VALUEAMT, VALUECUR, @CurrencyTo, @IsCurrencyConvert, 0)
                         ELSE 0 END) AS WS_Combined_Value,
                     SUM(CASE WHEN LossType = 1 AND LabelID IN (1, 32)
                       THEN dbo.ufnCurrencyConversion(VALUEAMT, VALUECUR, @CurrencyTo, @IsCurrencyConvert, 0)
                         ELSE 0 END) AS TO_Building_Value,
                     SUM(CASE WHEN LossType = 1 AND LabelID IN (33)
                       THEN dbo.ufnCurrencyConversion(VALUEAMT, VALUECUR, @CurrencyTo, @IsCurrencyConvert, 0)
                         ELSE 0 END) AS TO_Other_Structures_Value,
                     SUM(CASE WHEN LossType = 2 AND LabelID IN (2, 34)
                       THEN dbo.ufnCurrencyConversion(VALUEAMT, VALUECUR, @CurrencyTo, @IsCurrencyConvert, 0)
                         ELSE 0 END) AS TO_Contents_Value,
                     SUM(CASE WHEN LossType = 3 AND LabelID IN (3, 35)
                       THEN dbo.ufnCurrencyConversion(VALUEAMT, VALUECUR, @CurrencyTo, @IsCurrencyConvert, 0)
                         ELSE 0 END) AS TO_Business_Interruption_Value,
                     SUM(CASE WHEN LossType = 4 AND LabelID IN (52)
                       THEN dbo.ufnCurrencyConversion(VALUEAMT, VALUECUR, @CurrencyTo, @IsCurrencyConvert, 0)
                         ELSE 0 END) AS TO_Combined_Value,
                     SUM(CASE WHEN LossType = 1 AND LabelID IN (20, 36)
                       THEN dbo.ufnCurrencyConversion(VALUEAMT, VALUECUR, @CurrencyTo, @IsCurrencyConvert, 0)
                         ELSE 0 END) AS FL_Building_Value,
                     SUM(CASE WHEN LossType = 1 AND LabelID IN (37)
                       THEN dbo.ufnCurrencyConversion(VALUEAMT, VALUECUR, @CurrencyTo, @IsCurrencyConvert, 0)
                         ELSE 0 END) AS FL_Other_Structures_Value,
                     SUM(CASE WHEN LossType = 2 AND LabelID IN (21, 38)
                       THEN dbo.ufnCurrencyConversion(VALUEAMT, VALUECUR, @CurrencyTo, @IsCurrencyConvert, 0)
                         ELSE 0 END) AS FL_Contents_Value,
                     SUM(CASE WHEN LossType = 3 AND LabelID IN (22, 39)
                       THEN dbo.ufnCurrencyConversion(VALUEAMT, VALUECUR, @CurrencyTo, @IsCurrencyConvert, 0)
                         ELSE 0 END) AS FL_Business_Interruption_Value,
                     SUM(CASE WHEN LossType = 4 AND LabelID IN (53)
                       THEN dbo.ufnCurrencyConversion(VALUEAMT, VALUECUR, @CurrencyTo, @IsCurrencyConvert, 0)
                         ELSE 0 END) AS FL_Combined_Value,
                     SUM(CASE WHEN LossType = 1 AND LabelID IN (4, 40)
                       THEN dbo.ufnCurrencyConversion(VALUEAMT, VALUECUR, @CurrencyTo, @IsCurrencyConvert, 0)
                         ELSE 0 END) AS FR_Building_Value,
                     SUM(CASE WHEN LossType = 1 AND LabelID IN (41)
                       THEN dbo.ufnCurrencyConversion(VALUEAMT, VALUECUR, @CurrencyTo, @IsCurrencyConvert, 0)
                         ELSE 0 END) AS FR_Other_Structures_Value,
                     SUM(CASE WHEN LossType = 2 AND LabelID IN (5, 42)
                       THEN dbo.ufnCurrencyConversion(VALUEAMT, VALUECUR, @CurrencyTo, @IsCurrencyConvert, 0)
                         ELSE 0 END) AS FR_Contents_Value,
                     SUM(CASE WHEN LossType = 3 AND LabelID IN (6, 43)
                       THEN dbo.ufnCurrencyConversion(VALUEAMT, VALUECUR, @CurrencyTo, @IsCurrencyConvert, 0)
                         ELSE 0 END) AS FR_Business_Interruption_Value,
                     SUM(CASE WHEN LossType = 4 AND LabelID IN (54)
                       THEN dbo.ufnCurrencyConversion(VALUEAMT, VALUECUR, @CurrencyTo, @IsCurrencyConvert, 0)
                         ELSE 0 END) AS FR_Combined_Value,
                     SUM(CASE WHEN LossType = 1 AND LabelID IN (10, 44)
                       THEN dbo.ufnCurrencyConversion(VALUEAMT, VALUECUR, @CurrencyTo, @IsCurrencyConvert, 0)
                         ELSE 0 END) AS TR_Building_Value,
                     SUM(CASE WHEN LossType = 1 AND LabelID IN (45)
                       THEN dbo.ufnCurrencyConversion(VALUEAMT, VALUECUR, @CurrencyTo, @IsCurrencyConvert, 0)
                         ELSE 0 END) AS TR_Other_Structures_Value,
                     SUM(CASE WHEN LossType = 2 AND LabelID IN (11, 46)
                       THEN dbo.ufnCurrencyConversion(VALUEAMT, VALUECUR, @CurrencyTo, @IsCurrencyConvert, 0)
                         ELSE 0 END) AS TR_Contents_Value,
                     SUM(CASE WHEN LossType = 3 AND LabelID IN (12, 47)
                       THEN dbo.ufnCurrencyConversion(VALUEAMT, VALUECUR, @CurrencyTo, @IsCurrencyConvert, 0)
                         ELSE 0 END) AS TR_Business_Interruption_Value,
                     SUM(CASE WHEN LossType = 4 AND LabelID IN (55)
                       THEN dbo.ufnCurrencyConversion(VALUEAMT, VALUECUR, @CurrencyTo, @IsCurrencyConvert, 0)
                         ELSE 0 END) AS TR_Combined_Value,
                     SUM(dbo.ufnCurrencyConversion(VALUEAMT, VALUECUR, @CurrencyTo, @IsCurrencyConvert, 0)) AS TIV
                   FROM loccvg
                   WHERE isvalid = 1
                   GROUP BY LOCID) AS NEWLOCCVG ON NEWLOCCVG.LOCID = Property.LOCID
WHERE Property.ISVALID = 1 AND Accgrp.ISVALID = 1 AND portinfo.PORTINFOID = @PortfolioId AND
      portacct.PORTINFOID = @PortfolioId
