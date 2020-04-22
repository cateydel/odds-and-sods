/*
a. Declare variables for a SQL command string, a time stamp,
   and the user's chosen database name, portfolio ID, option to convert currency,
   and currency targeted for conversion (if that option's chosen)
*/

declare
  @sql nvarchar(max)
, @@ts nvarchar(127)
, @@dbname nvarchar(255)
, @@PortfolioID bigint
, @@IsCurrencyConvert bigint
, @@CurrencyTo nvarchar(3);



/*
b. Set the database name, portfolio ID, currency conversion option selection, and currency conversion target selection
*/

set @@dbname=db_name();

set @@PortfolioID=@PortfolioID;
set @@IsCurrencyConvert=@IsCurrencyConvert;
set @@CurrencyTo=@CurrencyTo;



/*
c. Define the currency conversion function
*/

if object_id('ufncurrencyconversion', 'FN') is not null DROP FUNCTION ufnCurrencyConversion;

SET @sql = N'CREATE FUNCTION dbo.ufnCurrencyConversion(@Value float, @CurrencyFrom varchar(255), @@CurrencyTo varchar(255), @@IsCurrencyConvert bit, @IsFieldPercent bit)
RETURNS float
AS
BEGIN
    DECLARE @ret float;
    DECLARE @CurrencyFromFactor float;
    DECLARE @@CurrencyToFactor float;

    IF @IsFieldPercent = 1 AND @Value <= 1 AND @Value > 0 RETURN @value

    IF @CurrencyFrom <> @@CurrencyTo AND @@IsCurrencyConvert = 1 BEGIN
        SET @CurrencyFromFactor = CAST((SELECT XFACTOR FROM [RiskModelDB_USERCONFIG].[dbo].[currfx] WHERE CODE = @CurrencyFrom) AS float);
        SET @@CurrencyToFactor = CAST((SELECT XFACTOR FROM [RiskModelDB_USERCONFIG].[dbo].[currfx] WHERE CODE = @@CurrencyTo) AS float);
        SET @ret = ((@Value * @@CurrencyToFactor)/@CurrencyFromFactor);
    END

    ELSE BEGIN
        SET @ret = @Value;
    END

    RETURN @ret;
END;
';

EXECUTE sp_executesql @sql;



/*
d. Define the 'string sweep' function, which replaces nonalphanumeric characters with bracketed hexadecimal code equivalents
*/

if object_id('stringSweep', 'FN') is not null DROP FUNCTION stringSweep;

SET @sql = N'
create function [dbo].[stringSweep] (@str nvarchar(255))
returns nvarchar(255)
as
begin
  declare @strNonStdWDups nvarchar(255);
  declare @strNonStdXDups nvarchar(255);
  declare @strStd nvarchar(max);

  set @strNonStdXDups
  = char(0) + char(1) + char(2) + char(3) + char(4) + char(5) + char(6) + char(7) + char(8) + char(9) + char(10) + char(11) + char(12)
  + char(13) + char(14) + char(15) + char(16) + char(17) + char(18) + char(19) + char(20) + char(21) + char(22) + char(23) + char(24)
  + char(25) + char(26) + char(27) + char(28) + char(29) + char(30) + char(31) + char(127) + char(129) + char(141) + char(143) + char(144)

  set @strStd=@str;

  while @strNonStdXDups<>'''' begin
    set @strStd = replace(@strStd,
    left(@strNonStdXDups, 1)
    , ''[%'' + substring(''0123456789ABCDEF'', 1+convert(bigint, floor(convert(float, ascii(left(@strNonStdXDups, 1)))/16)), 1)
    + substring(''0123456789ABCDEF'', 1+(ascii(left(@strNonStdXDups, 1)) & 15), 1) + '']'')
    set @strNonStdXDups = right(@StrNonStdXDups, len(@StrNonStdXDups)-1)
  end

  return convert(nvarchar(255), left(@strStd, 255));
end;
';

EXECUTE sp_executesql @sql;



/*
e. Retrieve the timestamp recorded by the policy script, Solution - Query 1 - Policy Script.sql
*/

if object_id('currenttimestamp', 'U') is not null drop table currentTimestamp;
create table currentTimestamp (ts nvarchar(max));
set @sql = 'select ts from ' + @@dbname + '_' + right('000' + LTrim(Str(@@PortfolioID)), 4) + '_timestamp';
insert into currentTimestamp exec sp_executesql @sql;
select @@ts=ts from currentTimestamp;

set @sql
  = 'if object_id(''' + @@dbname + '_' + right('000' + LTrim(Str(@@PortfolioID)), 4) + '_timestamp' + ''', ''U'') is not null'
  + ' drop table '
  + @@dbname + '_' + right('000' + LTrim(Str(@@PortfolioID)), 4) + '_timestamp';
exec sp_executesql @sql;




/*
f. Drop any location extraction procedures previously set up
*/

set @sql = N'
if object_id(''[dbo].[locationextraction_s01]'', ''P'') is not null drop procedure [dbo].[LocationExtraction_s01]
if object_id(''[dbo].[locationextraction_s02]'', ''P'') is not null drop procedure [dbo].[LocationExtraction_s02]
if object_id(''[dbo].[locationextraction_s03]'', ''P'') is not null drop procedure [dbo].[LocationExtraction_s03]
if object_id(''[dbo].[locationextraction_s04]'', ''P'') is not null drop procedure [dbo].[LocationExtraction_s04]
if object_id(''[dbo].[locationextraction_s05]'', ''P'') is not null drop procedure [dbo].[LocationExtraction_s05]
if object_id(''[dbo].[locationextraction_s06]'', ''P'') is not null drop procedure [dbo].[LocationExtraction_s06]
if object_id(''[dbo].[locationextraction_s07]'', ''P'') is not null drop procedure [dbo].[LocationExtraction_s07]
if object_id(''[dbo].[locationextraction_s08]'', ''P'') is not null drop procedure [dbo].[LocationExtraction_s08]
';
exec (@sql);



/*
g. Set up for the location extraction
*/
/*
g.1. Create extraction procedure #1 to do the following in step h.:

· Delete any previously-existing global temporary tables that may currently reside in TempDB,
  as catalogued by a table called ##zamboni0

· Import an appropriate currency conversion factor from the risk model database,
  into a table called ##L_currency

· Create ##L_locCvgValueMap, a mapping table of property insurance peril label IDs (1 through 55)
  to pairings
    of property insurance perils
     (EQ, earthquakes;
      WS, hurricanes, tropical storms, and cyclones;
      TO, severe convective storms;
      FL, floods;
      FR, fires;
      TR, terrorist incidents)
    and insurance coverage types
     (1, buildings;
      2, contents;
      3, business interruption exposures;
      4, buildings and contents combined)

· Create mapping tables for each of the following:
    Floor area measurement units (##l_floorareaunit)
    Geocoding resolution (##l_geocoderesolution)
    Soil type descriptions (##l_soiltypedescription)
    Mappings of location identifiers to policyholder account identifiers (##l_property)
*/

set @sql = N'
CREATE PROCEDURE [dbo].[LocationExtraction_s01]
  @k_dbname nvarchar(255)
, @k_portinfoid bigint
, @k_convertCurrency bigint
, @k_targetCurrency nvarchar(3)
, @k_outputTable nvarchar(255)
AS

declare
  @dbname nvarchar(255)
, @PortfolioID bigint
, @IsCurrencyConvert bigint
, @CurrencyTo nvarchar(3)
, @outputTable nvarchar(255)
, @counter bigint
, @count bigint
, @count_LCQ bigint
, @commandstring01 nvarchar(max)
, @sql nvarchar(max)
, @sqlString nvarchar(max);

set @dbname=@k_dbname;
set @PortfolioID=@k_portinfoid;
set @IsCurrencyConvert=@k_convertCurrency;
set @CurrencyTo=@k_targetCurrency;
set @outputTable=@k_outputTable;

if object_id(''##zamboni0'') is not null drop table ##zamboni0;

select name, row_number() over (order by name) i
into ##zamboni0
from tempdb.sys.tables
where (left(name, 3)=''##K'' and substring(name, 4, 8)<=
  convert(nvarchar(32), convert(datetime, convert(bigint, convert(datetime, getdate(), 112))-2), 112)
) or name=''##zamboni''

select @count=max(i) from ##zamboni0
set @counter=1

while @counter<=@count begin
  select @commandstring01 = ''drop table '' + name from ##zamboni0 where i=@counter;
  exec (@commandString01)
  set @counter=@counter+1
end

drop table ##zamboni0

if object_id(''##l_currency'', ''U'') is not null drop table ##L_currency;
  SELECT C0.CODE, case when @IsCurrencyConvert=0 then 1.0 else CONVERT(float, C0.XFACTOR) / CONVERT(float, C1.XFACTOR) end XFACTOR
  INTO ##L_currency
  FROM RiskModelDB_USERCONFIG.dbo.currfx C0, RiskModelDB_USERCONFIG.dbo.currfx C1
  WHERE C1.CODE = @CurrencyTo

  alter table ##L_currency add constraint PK_##L_BT_CUR primary key clustered (CODE);

if object_id(''##l_loccvgvaluemap'', ''U'') is not null drop table ##L_locCvgValueMap;
  SELECT * into ##L_locCvgValueMap FROM (VALUES
   (1,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)
  ,(2,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)
  ,(3,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)
  ,(4,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0)
  ,(5,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0)
  ,(6,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0)
  ,(7,1,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)
  ,(8,1,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)
  ,(9,1,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)
  ,(10,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0)
  ,(11,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0)
  ,(12,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0)
  ,(14,0,1,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)
  ,(15,0,1,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)
  ,(16,0,1,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)
  ,(20,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0)
  ,(21,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0)
  ,(22,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0)
  ,(24,0,1,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)
  ,(25,0,1,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)
  ,(26,0,1,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)
  ,(27,0,1,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)
  ,(28,1,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)
  ,(29,1,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)
  ,(30,1,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)
  ,(31,1,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)
  ,(32,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)
  ,(33,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)
  ,(34,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)
  ,(35,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)
  ,(36,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0)
  ,(37,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0)
  ,(38,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0)
  ,(39,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0)
  ,(40,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0)
  ,(41,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0)
  ,(42,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0)
  ,(43,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0)
  ,(44,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0)
  ,(45,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0)
  ,(46,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0)
  ,(47,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0)
  ,(50,1,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)
  ,(51,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)
  ,(52,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)
  ,(53,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0)
  ,(54,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0)
  ,(55,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1)
  ) t (
   LABELID,EQ0,WS0,TO0,FL0,FR0,TR0,EQ4,EQ5,EQ6,EQ7,EQ8,WS4,WS5,WS6,WS7,WS8,TO4,TO5,TO6,TO7,TO8,FL4,FL5,FL6,FL7,FL8,FR4,FR5,FR6,FR7,FR8,TR4,TR5,TR6,TR7,TR8
  )

  alter table ##L_locCvgValueMap add constraint PK_##L_BT_LCVM primary key clustered (LABELID);

if object_id(''##l_floorareaunit'', ''U'') is not null drop table ##L_FloorAreaUnit;

  select *
  into ##L_FloorAreaUnit
  from (values
    (2, ''Square Feet'')
  , (4, ''Square Meters'')
  ) U (AREAUNIT, Floor_Area_Unit);

if object_id(''##l_geocoderesolution'', ''U'') is not null drop table ##L_GeocodeResolution

  select *
  into ##L_GeocodeResolution
  from (values
    (0, -80)
  , (1, -1)
  , (2, -10)
  , (3, 31)
  , (4, 1)
  , (5, 4)
  , (6, 5)
  , (7, 5)
  , (8, 5)
  , (9, 6)
  , (10, 7)
  , (11, 10)
  , (12, 0)
  , (13, 0)
  , (14, 9)
  ) U (GeoResolutionCode, Geocode_Resolution)

if object_id(''##l_soiltypedescription'', ''U'') is not null drop table ##L_soilTypeDescription;

  select *
  into ##L_soilTypeDescription
  from (values
    (''Rock'', 0.999999, 1.25)
  , (''Rock to Soft Rock'', 1.25, 1.75)
  , (''Soft Rock'', 1.75, 2.25)
  , (''Soft Rock to Stiff Soil'', 2.25, 2.75)
  , (''Soft Soil'', 3.75, 4)
  , (''Stiff Soil'', 2.75, 3.25)
  , (''Stiff to Soft Soil'', 3.25, 3.75)
  ) U (Soil_Type_Description, soiltype_greaterThan, soiltype_noGreaterThan);

if object_id(''##l_portacct'', ''U'') is not null drop table ##L_portacct;

  select ACCGRPID into ##L_portacct
  from portacct
  where PORTINFOID=@PortfolioID;

if object_id(''##l_property'', ''U'') is not null drop table ##L_property;

  select PR.LOCID, PR.ACCGRPID
  into ##L_property
  from ##L_portacct PAC, property PR
  where PAC.ACCGRPID=PR.ACCGRPID and PR.ISVALID<>0;
  alter table ##L_property add constraint PK_##L_BT_PROPERTY primary key clustered (LOCID, ACCGRPID)

if object_id(''##l_portacct'', ''U'') is not null drop table ##L_portacct;
'

set @sql = replace(replace(@sql, '##L', '##L' + replace(@@ts, '\', '_')), '##K', '##L');
exec sp_executesql @sql;



/*
g.2. Create extraction procedure #2:
· Create a table that maps location-and-insurance-coverage identifiers
  to location identifiers, insurable values (converted to the user's selected currency),
  and property insurance peril label IDs (as defined in ##L_locCvgValueMap)
*/

set @sql = N'
CREATE PROCEDURE [dbo].[LocationExtraction_s02]
  @k_dbname nvarchar(255)
, @k_portinfoid bigint
, @k_convertCurrency bigint
, @k_targetCurrency nvarchar(3)
, @k_outputTable nvarchar(255)
AS

declare
  @dbname nvarchar(255)
, @PortfolioID bigint
, @IsCurrencyConvert bigint
, @CurrencyTo nvarchar(3)
, @outputTable nvarchar(255)
, @counter bigint
, @count bigint
, @count_LCQ bigint
, @commandstring01 nvarchar(max)
, @sql nvarchar(max)
, @sqlString nvarchar(max);

set @dbname=@k_dbname;
set @PortfolioID=@k_portinfoid;
set @IsCurrencyConvert=@k_convertCurrency;
set @CurrencyTo=@k_targetCurrency;
set @outputTable=@k_outputTable;

if object_id(''##l_loccvg_prep'', ''U'') is not null drop table ##L_loccvg_prep;
  select LC.LOCCVGID, LC.LOCID, LC.VALUEAMT, LC.LABELID, LC.VALUECUR
  into ##L_loccvg_prep
  from ##L_property PR, loccvg LC
  where PR.LOCID=LC.LOCID and LC.ISVALID<>0

alter table ##L_loccvg_prep add constraint PK_##L_BT_LOCCVG primary key clustered (VALUECUR, LABELID, LOCCVGID);

alter table ##L_loccvg_prep add XFACTOR float, VALUEAMT_conv float;

if object_id(''##l_loccvg'', ''U'') is not null drop table ##L_loccvg;
  select
    LC.LOCCVGID, LC.LOCID
  , dbo.ufnCurrencyConversion(LC.VALUEAMT, LC.VALUECUR, @CurrencyTo, @IsCurrencyConvert, 0) VALUEAMT
  , LC.LABELID
  into ##L_loccvg
  from ##L_loccvg_prep LC, ##L_currency CUR
  where LC.VALUECUR=CUR.CODE;

if object_id(''##l_loccvg_prep'', ''U'') is not null drop table ##L_loccvg_prep;
  alter table ##L_loccvg add constraint PK_##L_BT_LOCCVGC primary key clustered (LABELID, LOCCVGID);
'

set @sql = replace(replace(@sql, '##L', '##L' + replace(@@ts, '\', '_')), '##K', '##L');
exec sp_executesql @sql;



/*
g.3. Create extraction procedure #3:
· Build a table of insurable values by location identifier
*/

set @sql = N'
CREATE PROCEDURE [dbo].[LocationExtraction_s03]
  @k_dbname nvarchar(255)
, @k_portinfoid bigint
, @k_convertCurrency bigint
, @k_targetCurrency nvarchar(3)
, @k_outputTable nvarchar(255)
AS

declare
  @dbname nvarchar(255)
, @PortfolioID bigint
, @IsCurrencyConvert bigint
, @CurrencyTo nvarchar(3)
, @outputTable nvarchar(255)
, @counter bigint
, @count bigint
, @count_LCQ bigint
, @commandstring01 nvarchar(max)
, @sql nvarchar(max)
, @sqlString nvarchar(max);

set @dbname=@k_dbname;
set @PortfolioID=@k_portinfoid;
set @IsCurrencyConvert=@k_convertCurrency;
set @CurrencyTo=@k_targetCurrency;
set @outputTable=@k_outputTable;

if object_id(''##l_valuesbylocid'', ''U'') is not null drop table ##L_valuesByLocID;
  select LC.LOCID
  , sum(LC.VALUEAMT*LCVM.EQ0) EQ_TIV
  , sum(LC.VALUEAMT*LCVM.WS0) WS_TIV
  , sum(LC.VALUEAMT*LCVM.TO0) TO_TIV
  , sum(LC.VALUEAMT*LCVM.FL0) FL_TIV
  , sum(LC.VALUEAMT*LCVM.FR0) FR_TIV
  , sum(LC.VALUEAMT*LCVM.TR0) TR_TIV
  , sum(LC.VALUEAMT*LCVM.EQ4) EQ_Building_Value
  , sum(LC.VALUEAMT*LCVM.EQ5) EQ_Other_Structures_Value
  , sum(LC.VALUEAMT*LCVM.EQ6) EQ_Contents_Value
  , sum(LC.VALUEAMT*LCVM.EQ7) EQ_Business_Interruption_Value
  , sum(LC.VALUEAMT*LCVM.EQ8) EQ_Combined_Value
  , sum(LC.VALUEAMT*LCVM.WS4) WS_Building_Value
  , sum(LC.VALUEAMT*LCVM.WS5) WS_Other_Structures_Value
  , sum(LC.VALUEAMT*LCVM.WS6) WS_Contents_Value
  , sum(LC.VALUEAMT*LCVM.WS7) WS_Business_Interruption_Value
  , sum(LC.VALUEAMT*LCVM.WS8) WS_Combined_Value
  , sum(LC.VALUEAMT*LCVM.TO4) TO_Building_Value
  , sum(LC.VALUEAMT*LCVM.TO5) TO_Other_Structures_Value
  , sum(LC.VALUEAMT*LCVM.TO6) TO_Contents_Value
  , sum(LC.VALUEAMT*LCVM.TO7) TO_Business_Interruption_Value
  , sum(LC.VALUEAMT*LCVM.TO8) TO_Combined_Value
  , sum(LC.VALUEAMT*LCVM.FL4) FL_Building_Value
  , sum(LC.VALUEAMT*LCVM.FL5) FL_Other_Structures_Value
  , sum(LC.VALUEAMT*LCVM.FL6) FL_Contents_Value
  , sum(LC.VALUEAMT*LCVM.FL7) FL_Business_Interruption_Value
  , sum(LC.VALUEAMT*LCVM.FL8) FL_Combined_Value
  , sum(LC.VALUEAMT*LCVM.FR4) FR_Building_Value
  , sum(LC.VALUEAMT*LCVM.FR5) FR_Other_Structures_Value
  , sum(LC.VALUEAMT*LCVM.FR6) FR_Contents_Value
  , sum(LC.VALUEAMT*LCVM.FR7) FR_Business_Interruption_Value
  , sum(LC.VALUEAMT*LCVM.FR8) FR_Combined_Value
  , sum(LC.VALUEAMT*LCVM.TR4) TR_Building_Value
  , sum(LC.VALUEAMT*LCVM.TR5) TR_Other_Structures_Value
  , sum(LC.VALUEAMT*LCVM.TR6) TR_Contents_Value
  , sum(LC.VALUEAMT*LCVM.TR7) TR_Business_Interruption_Value
  , sum(LC.VALUEAMT*LCVM.TR8) TR_Combined_Value
, case
    when sum(LC.VALUEAMT*LCVM.EQ0)>sum(LC.VALUEAMT*LCVM.WS0) and sum(LC.VALUEAMT*LCVM.EQ0)>sum(LC.VALUEAMT*LCVM.TO0) and sum(LC.VALUEAMT*LCVM.EQ0)>sum(LC.VALUEAMT*LCVM.FL0) and sum(LC.VALUEAMT*LCVM.EQ0)>sum(LC.VALUEAMT*LCVM.FR0) and sum(LC.VALUEAMT*LCVM.EQ0)>sum(LC.VALUEAMT*LCVM.TR0) then sum(LC.VALUEAMT*LCVM.EQ0)
    when sum(LC.VALUEAMT*LCVM.WS0)>sum(LC.VALUEAMT*LCVM.TO0) and sum(LC.VALUEAMT*LCVM.WS0)>sum(LC.VALUEAMT*LCVM.FL0) and sum(LC.VALUEAMT*LCVM.WS0)>sum(LC.VALUEAMT*LCVM.FR0) and sum(LC.VALUEAMT*LCVM.WS0)>sum(LC.VALUEAMT*LCVM.TR0) then sum(LC.VALUEAMT*LCVM.WS0)
    when sum(LC.VALUEAMT*LCVM.TO0)>sum(LC.VALUEAMT*LCVM.FL0) and sum(LC.VALUEAMT*LCVM.TO0)>sum(LC.VALUEAMT*LCVM.FR0) and sum(LC.VALUEAMT*LCVM.TO0)>sum(LC.VALUEAMT*LCVM.TR0) then sum(LC.VALUEAMT*LCVM.TO0)
    when sum(LC.VALUEAMT*LCVM.FL0)>sum(LC.VALUEAMT*LCVM.FR0) and sum(LC.VALUEAMT*LCVM.FL0)>sum(LC.VALUEAMT*LCVM.TR0) then sum(LC.VALUEAMT*LCVM.FL0)
    when sum(LC.VALUEAMT*LCVM.FR0)>sum(LC.VALUEAMT*LCVM.TR0) then sum(LC.VALUEAMT*LCVM.FR0)
    else sum(LC.VALUEAMT*LCVM.TR0) end
  Total_Insured_Value

  into ##L_valuesByLocID
  From ##L_locCvg LC, ##L_locCvgValueMap LCVM
  where LC.LABELID=LCVM.LABELID
  group by LC.LOCID

if object_id(''##l_loccvg'', ''U'') is not null drop table ##L_loccvg;
  alter table ##L_valuesByLocID add constraint PK_##L_BT_VBLI primary key clustered (LOCID);
'

set @sql = replace(replace(@sql, '##L', '##L' + replace(@@ts, '\', '_')), '##K', '##L');
exec sp_executesql @sql;



/*
g.4. Create extraction procedure #4:
· Build a table of property data (##L_VSL_property) with records mapped for use in the visualization software
*/

set @sql = N'
CREATE PROCEDURE [dbo].[LocationExtraction_s04]
  @k_dbname nvarchar(255)
, @k_portinfoid bigint
, @k_convertCurrency bigint
, @k_targetCurrency nvarchar(3)
, @k_outputTable nvarchar(255)
AS

declare
  @dbname nvarchar(255)
, @PortfolioID bigint
, @IsCurrencyConvert bigint
, @CurrencyTo nvarchar(3)
, @outputTable nvarchar(255)
, @counter bigint
, @count bigint
, @count_LCQ bigint
, @commandstring01 nvarchar(max)
, @sql nvarchar(max)
, @sqlString nvarchar(max);

set @dbname=@k_dbname;
set @PortfolioID=@k_portinfoid;
set @IsCurrencyConvert=@k_convertCurrency;
set @CurrencyTo=@k_targetCurrency;
set @outputTable=@k_outputTable;

if object_id(''##l_VSL_property'', ''U'') is not null drop table ##L_VSL_property;
  select
    convert(int, PR0.LOCID) Location_ID
  , convert(varchar(20), PR0.LOCNUM) Location_Number
  , convert(varchar(40), PR0.LOCNAME) Location_Name
  , convert(int, PR0.NUMBLDGS) Number_of_Buildings
  , convert(varchar(10), PR0.BLDGSCHEME) Temp_RiskModelDB_BLDGSCHEME
  , convert(varchar(5), PR0.BLDGCLASS) Temp_RiskModelDB_BLDGCLASS
  , convert(varchar(255), '''') Construction_Type
  , convert(varchar(10), PR0.OCCSCHEME) Temp_RiskModelDB_OCCSCHEME
  , convert(int, PR0.OCCTYPE) Temp_RiskModelDB_OCCTYPE
  , convert(varchar(255), '''') Occupancy_Type
  , convert(smallint, PR0.NUMSTORIES) Number_of_Stories
  , convert(varchar(92), PR0.YEARBUILT, 101) Year_Built
  , convert(float, PR0.FLOORAREA) Floor_Area
  , convert(nvarchar(63), FAU.Floor_Area_Unit) Floor_Area_Unit
  , convert(varchar(92), PR0.INCEPTDATE, 101) Location_Inception_Date
  , convert(varchar(92), PR0.EXPIREDATE, 101) Location_Expiration_Date
  , convert(int, PR0.PRIMARYLOCID) Primary_Location_ID
  , convert(varchar(40), PR0.SITENAME) Site_Name
  , convert(varchar(20), PR0.USERID1) User_ID_1
  , convert(varchar(20), PR0.USERID2) User_ID_2
  , convert(varchar(20), PR0.USERTXT1) User_Text_1
  , convert(varchar(20), PR0.USERTXT2) User_Text_2
  into ##L_VSL_property
  from
    ##L_property PR
  , property PR0
  , ##L_FloorAreaUnit FAU
  where PR0.LOCID=PR.LOCID and PR0.AREAUNIT=FAU.AREAUNIT
'

set @sql = replace(replace(@sql, '##L', '##L' + replace(@@ts, '\', '_')), '##K', '##L');
exec sp_executesql @sql;



/*
g.5. Create extraction procedure #5:
· Build tables of property addresses (##L_VSL_address) and peril-specific hazard and insurance details (##l_VSL_xxdet_nomcur),
  with records mapped for use in the visualization software. The peril-specific insurance details (coverage limits and deductibles)
  are stated in their nominal, unconverted currencies (hence "nomcur"), and the perils correspond to the remarks in section g.1.
  (xx=EQ, xx=TO, xx=FL, etc.)
  
  (Note, xx=HU (hurricanes) is considered equivalent to xx=WS (hurricanes, tropical storms, and cyclones).)
*/

set @sql = N'
CREATE PROCEDURE [dbo].[LocationExtraction_s05]
  @k_dbname nvarchar(255)
, @k_portinfoid bigint
, @k_convertCurrency bigint
, @k_targetCurrency nvarchar(3)
, @k_outputTable nvarchar(255)
AS

declare
  @dbname nvarchar(255)
, @PortfolioID bigint
, @IsCurrencyConvert bigint
, @CurrencyTo nvarchar(3)
, @outputTable nvarchar(255)
, @counter bigint
, @count bigint
, @count_LCQ bigint
, @commandstring01 nvarchar(max)
, @sql nvarchar(max)
, @sqlString nvarchar(max);

set @dbname=@k_dbname;
set @PortfolioID=@k_portinfoid;
set @IsCurrencyConvert=@k_convertCurrency;
set @CurrencyTo=@k_targetCurrency;
set @outputTable=@k_outputTable;

if object_id(''##l_addressids'', ''U'') is not null drop table ##L_AddressIDs;
  select PR0.AddressID, PR0.LOCID
  into ##L_AddressIDs
  from ##L_property PR, property PR0
  where PR0.LOCID=PR.LOCID;
  alter table ##L_addressIDs add constraint PK_##L_BT_VSL_AID primary key clustered (AddressID, LOCID);

if object_id(''##l_VSL_address'', ''U'') is not null drop table ##L_VSL_address;
  select
    AID.LOCID
  , convert(varchar(6), ADR.CountryScheme) Temp_RiskModelDB_CountryScheme
  , convert(varchar(4), ADR.CountryCode) Temp_RiskModelDB_CountryCode
  , convert(varchar(255), '''') Country_Code_FIPS
  , convert(varchar(255), '''') Country_Name
  , dbo.stringSweep(convert(nvarchar(255), left(ADR.Admin1Code, 255))) State
  , convert(nvarchar(255), left(ADR.Admin2Name, 255)) County
  , dbo.stringSweep(convert(nvarchar(255), left(ADR.CityName, 255))) City
  , dbo.stringSweep(convert(varchar(16), ADR.PostalCode)) Postal_Code
  , dbo.stringSweep(convert(nvarchar(255), left(Replace(Replace(ADR.StreetAddress, '','', ''''), ''"'', ''''), 255))) Street
  , convert(float, ADR.Latitude) Latitude
  , convert(float, ADR.Longitude) Longitude
  , convert(smallint, ADR.GeoResolutionCode) RiskModelDB_Geocode_Resolution
  , convert(int, GR.Geocode_Resolution) Geocode_Resolution
  , convert(nvarchar(255), left(ADR.Admin1Code, 255)) State_wNonalphas
  , convert(nvarchar(255), left(ADR.CityName, 255)) City_wNonalphas
  , convert(varchar(16), ADR.PostalCode) Postal_Code_wNonalphas
  , convert(nvarchar(255), left(Replace(Replace(ADR.StreetAddress, '','', ''''), ''"'', ''''), 255)) Street_wNonalphas
  into ##L_VSL_address
  from
    ##L_AddressIDs AID
  , address ADR
  , ##L_GeocodeResolution GR
  where AID.AddressID=ADR.AddressID and ADR.GeoResolutionCode=GR.GeoResolutionCode;
  alter table ##L_VSL_address add constraint PK_##L_BT_VSL_ADR primary key clustered (LOCID);

if object_id(''##l_VSL_account'', ''U'') is not null drop table ##L_VSL_account;
  select
    PR.LOCID
  , convert(varchar(20), ACC.ACCGRPNUM) Account_Number
  , convert(int, ACC.ACCGRPID) Account_ID
  , convert(varchar(40), ACC.ACCGRPNAME) Account_Name
  into ##L_VSL_account
  from ##L_property PR, accgrp ACC
  where PR.ACCGRPID=ACC.ACCGRPID;
  alter table ##L_VSL_account add constraint PK_##L_BT_VSL_ACC primary key clustered (LOCID);

if object_id(''##l_VSL_eqdet_nomcur'', ''U'') is not null drop table ##L_VSL_eqdet_nomcur;
  select
    D.LOCID
  , convert(float, D.SITELIMAMT) EQ_Site_Limit
  , convert(float, D.SITEDEDAMT) EQ_Site_Deductible
  , convert(varchar(4), D.SITELIMCUR) SITELIMCUR
  , convert(varchar(4), D.SITEDEDCUR) SITEDEDCUR
  , convert(nvarchar(64), D.SOILTYPE) RiskModelDB_Soil_Type
  , convert(nvarchar(64),
    case when SD.Soil_Type_Description is null then ltrim(str(D.SOILTYPE))
    else SD.Soil_Type_Description end
  ) Soil_Type_Description
  into ##L_VSL_eqdet_nomcur
  from ##L_property PR, eqdet D
    left outer join ##L_soilTypeDescription SD
    on (SD.soiltype_greaterThan<D.SOILTYPE and D.SOILTYPE<=SD.soiltype_noGreaterThan)
  where PR.LOCID=D.LOCID;
  alter table ##L_VSL_eqdet_nomcur add constraint PK_##L_BT_VSL_eqdet primary key clustered (LOCID);

if object_id(''##l_VSL_hudet_nomcur'', ''U'') is not null drop table ##L_VSL_hudet_nomcur;
  select
    D.LOCID
  , convert(float, D.SITELIMAMT) HU_Site_Limit
  , convert(float, D.SITEDEDAMT) HU_Site_Deductible
  , convert(varchar(4), D.SITELIMCUR) SITELIMCUR
  , convert(varchar(4), D.SITEDEDCUR) SITEDEDCUR
  , convert(float, DISTCOAST) Distance_to_Coast
  into ##L_VSL_hudet_nomcur
  from ##L_property PR, hudet D
  where PR.LOCID=D.LOCID;
  alter table ##L_VSL_hudet_nomcur add constraint PK_##L_BT_VSL_hudet primary key clustered (LOCID);

if object_id(''##l_VSL_todet_nomcur'', ''U'') is not null drop table ##L_VSL_todet_nomcur;
  select
    D.LOCID
  , convert(float, D.SITELIMAMT) TO_Site_Limit
  , convert(float, D.SITEDEDAMT) TO_Site_Deductible
  , convert(varchar(4), D.SITELIMCUR) SITELIMCUR
  , convert(varchar(4), D.SITEDEDCUR) SITEDEDCUR
  into ##L_VSL_todet_nomcur
  from ##L_property PR, todet D
  where PR.LOCID=D.LOCID;
  alter table ##L_VSL_todet_nomcur add constraint PK_##L_BT_VSL_todet primary key clustered (LOCID);

if object_id(''##l_VSL_fldet_nomcur'', ''U'') is not null drop table ##L_VSL_fldet_nomcur;
  select
    D.LOCID
  , convert(float, D.SITELIMAMT) FL_Site_Limit
  , convert(float, D.SITEDEDAMT) FL_Site_Deductible
  , convert(varchar(4), D.SITELIMCUR) SITELIMCUR
  , convert(varchar(4), D.SITEDEDCUR) SITEDEDCUR
  , convert(nvarchar(8), D.FLZONE) RiskModelDB_FL_Zone
  , convert(varchar(16), D.BFE) RiskModelDB_BFE
  , convert(nvarchar(16), D.SFHA) RiskModelDB_SFHA
  , convert(nvarchar(64), D.ANNPROB) RiskModelDB_Annual_FL_Probability
  , convert(nvarchar(64), D.OTHERZONES) RiskModelDB_FL_Other_Zones
  into ##L_VSL_fldet_nomcur
  from ##L_property PR, fldet D
  where PR.LOCID=D.LOCID;
  alter table ##L_VSL_fldet_nomcur add constraint PK_##L_BT_VSL_fldet primary key clustered (LOCID);

if object_id(''##l_VSL_frdet_nomcur'', ''U'') is not null drop table ##L_VSL_frdet_nomcur;
  select
    D.LOCID
  , convert(float, D.SITELIMAMT) FR_Site_Limit
  , convert(float, D.SITEDEDAMT) FR_Site_Deductible
  , convert(varchar(4), D.SITELIMCUR) SITELIMCUR
  , convert(varchar(4), D.SITEDEDCUR) SITEDEDCUR
  into ##L_VSL_frdet_nomcur
  from ##L_property PR, frdet D
  where PR.LOCID=D.LOCID;
  alter table ##L_VSL_frdet_nomcur add constraint PK_##L_BT_VSL_frdet primary key clustered (LOCID);

if object_id(''##l_VSL_trdet_nomcur'', ''U'') is not null drop table ##L_VSL_trdet_nomcur;
  select
    D.LOCID
  , convert(float, D.SITELIMAMT) TR_Site_Limit
  , convert(float, D.SITEDEDAMT) TR_Site_Deductible
  , convert(varchar(4), D.SITELIMCUR) SITELIMCUR
  , convert(varchar(4), D.SITEDEDCUR) SITEDEDCUR
  into ##L_VSL_trdet_nomcur
  from ##L_property PR, trdet D
  where PR.LOCID=D.LOCID;
  alter table ##L_VSL_trdet_nomcur add constraint PK_##L_BT_VSL_trdet primary key clustered (LOCID);
'

set @sql = replace(replace(@sql, '##L', '##L' + replace(@@ts, '\', '_')), '##K', '##L');
exec sp_executesql @sql;



/*
g.6. Create extraction procedure #6:
· Build tables of peril-specific hazard and insurance details (##l_VSL_xxdet) with records mapped for use
  in the visualization software. The peril-specific insurance details are converted to the user's selected currency --
  thus, ##l_VSL_xxdet is ##l_VSL_xxdet_nomcur after currency conversions (xx in {EQ, HU, TO, FL, FR, TR}).
*/

set @sql = N'
CREATE PROCEDURE [dbo].[LocationExtraction_s06]
  @k_dbname nvarchar(255)
, @k_portinfoid bigint
, @k_convertCurrency bigint
, @k_targetCurrency nvarchar(3)
, @k_outputTable nvarchar(255)
AS

declare
  @dbname nvarchar(255)
, @PortfolioID bigint
, @IsCurrencyConvert bigint
, @CurrencyTo nvarchar(3)
, @outputTable nvarchar(255)
, @counter bigint
, @count bigint
, @count_LCQ bigint
, @commandstring01 nvarchar(max)
, @sql nvarchar(max)
, @sqlString nvarchar(max);

set @dbname=@k_dbname;
set @PortfolioID=@k_portinfoid;
set @IsCurrencyConvert=@k_convertCurrency;
set @CurrencyTo=@k_targetCurrency;
set @outputTable=@k_outputTable;

if object_id(''##l_VSL_eqdet'', ''U'') is not null drop table ##L_VSL_eqdet;
  select
    D.LOCID
  , dbo.ufnCurrencyConversion(D.EQ_Site_Limit, D.SITELIMCUR, @CurrencyTo, @IsCurrencyConvert, 1) EQ_Site_Limit
  , dbo.ufnCurrencyConversion(D.EQ_Site_Deductible, D.SITEDEDCUR, @CurrencyTo, @IsCurrencyConvert, 1) EQ_Site_Deductible
  , D.RiskModelDB_Soil_Type
  , D.Soil_Type_Description
  into ##L_VSL_eqdet
  from
    ##L_VSL_eqdet_nomcur D
  , ##L_currency CUR_L
  , ##L_currency CUR_D
  , ##L_valuesByLocID VBLI
  where D.LOCID=VBLI.LOCID and D.SITELIMCUR=CUR_L.CODE and D.SITEDEDCUR=CUR_D.CODE;
if object_id(''##l_VSL_eqdet_nomcur'', ''U'') is not null drop table ##L_VSL_eqdet_nomcur;
  alter table ##L_VSL_eqdet add constraint PK_##L_BT_VSL_eqdet_c primary key clustered (LOCID);

if object_id(''##l_VSL_hudet'', ''U'') is not null drop table ##L_VSL_hudet;
  select
    D.LOCID
  , dbo.ufnCurrencyConversion(D.HU_Site_Limit, D.SITELIMCUR, @CurrencyTo, @IsCurrencyConvert, 1) HU_Site_Limit
  , dbo.ufnCurrencyConversion(D.HU_Site_Deductible, D.SITEDEDCUR, @CurrencyTo, @IsCurrencyConvert, 1) HU_Site_Deductible
  , D.Distance_to_Coast
  into ##L_VSL_hudet
  from
    ##L_VSL_hudet_nomcur D
  , ##L_currency CUR_L
  , ##L_currency CUR_D
  , ##L_valuesByLocID VBLI
  where D.LOCID=VBLI.LOCID and D.SITELIMCUR=CUR_L.CODE and D.SITEDEDCUR=CUR_D.CODE;
if object_id(''##l_VSL_hudet_nomcur'', ''U'') is not null drop table ##L_VSL_hudet_nomcur;
  alter table ##L_VSL_hudet add constraint PK_##L_BT_VSL_hudet_c primary key clustered (LOCID);

if object_id(''##l_VSL_todet'', ''U'') is not null drop table ##L_VSL_todet;
  select
    D.LOCID
  , dbo.ufnCurrencyConversion(D.TO_Site_Limit, D.SITELIMCUR, @CurrencyTo, @IsCurrencyConvert, 1) TO_Site_Limit
  , dbo.ufnCurrencyConversion(D.TO_Site_Deductible, D.SITEDEDCUR, @CurrencyTo, @IsCurrencyConvert, 1) TO_Site_Deductible
  into ##L_VSL_todet
  from
    ##L_VSL_todet_nomcur D
  , ##L_currency CUR_L
  , ##L_currency CUR_D
  , ##L_valuesByLocID VBLI
  where D.LOCID=VBLI.LOCID and D.SITELIMCUR=CUR_L.CODE and D.SITEDEDCUR=CUR_D.CODE;
if object_id(''##l_VSL_todet_nomcur'', ''U'') is not null drop table ##L_VSL_todet_nomcur;
  alter table ##L_VSL_todet add constraint PK_##L_BT_VSL_todet_c primary key clustered (LOCID);

if object_id(''##l_VSL_fldet'', ''U'') is not null drop table ##L_VSL_fldet;
  select
    D.LOCID
  , dbo.ufnCurrencyConversion(D.FL_Site_Limit, D.SITELIMCUR, @CurrencyTo, @IsCurrencyConvert, 1) FL_Site_Limit
  , dbo.ufnCurrencyConversion(D.FL_Site_Deductible, D.SITEDEDCUR, @CurrencyTo, @IsCurrencyConvert, 1) FL_Site_Deductible
  , D.RiskModelDB_FL_Zone
  , D.RiskModelDB_BFE
  , D.RiskModelDB_SFHA
  , D.RiskModelDB_Annual_FL_Probability
  , D.RiskModelDB_FL_Other_Zones
  into ##L_VSL_fldet
  from
    ##L_VSL_fldet_nomcur D
  , ##L_currency CUR_L
  , ##L_currency CUR_D
  , ##L_valuesByLocID VBLI
  where D.LOCID=VBLI.LOCID and D.SITELIMCUR=CUR_L.CODE and D.SITEDEDCUR=CUR_D.CODE;
if object_id(''##l_VSL_fldet_nomcur'', ''U'') is not null drop table ##L_VSL_fldet_nomcur;
  alter table ##L_VSL_fldet add constraint PK_##L_BT_VSL_fldet_c primary key clustered (LOCID);

if object_id(''##l_VSL_frdet'', ''U'') is not null drop table ##L_VSL_frdet;
  select
    D.LOCID
  , dbo.ufnCurrencyConversion(D.FR_Site_Limit, D.SITELIMCUR, @CurrencyTo, @IsCurrencyConvert, 1) FR_Site_Limit
  , dbo.ufnCurrencyConversion(D.FR_Site_Deductible, D.SITEDEDCUR, @CurrencyTo, @IsCurrencyConvert, 1) FR_Site_Deductible
  into ##L_VSL_frdet
  from
    ##L_VSL_frdet_nomcur D
  , ##L_currency CUR_L
  , ##L_currency CUR_D
  , ##L_valuesByLocID VBLI
  where D.LOCID=VBLI.LOCID and D.SITELIMCUR=CUR_L.CODE and D.SITEDEDCUR=CUR_D.CODE;
if object_id(''##l_VSL_frdet_nomcur'', ''U'') is not null drop table ##L_VSL_frdet_nomcur;
  alter table ##L_VSL_frdet add constraint PK_##L_BT_VSL_frdet_c primary key clustered (LOCID);

if object_id(''##l_VSL_trdet'', ''U'') is not null drop table ##L_VSL_trdet;
  select
    D.LOCID
  , dbo.ufnCurrencyConversion(D.TR_Site_Limit, D.SITELIMCUR, @CurrencyTo, @IsCurrencyConvert, 1) TR_Site_Limit
  , dbo.ufnCurrencyConversion(D.TR_Site_Deductible, D.SITEDEDCUR, @CurrencyTo, @IsCurrencyConvert, 1) TR_Site_Deductible
  into ##L_VSL_trdet
  from
    ##L_VSL_trdet_nomcur D
  , ##L_currency CUR_L
  , ##L_currency CUR_D
  , ##L_valuesByLocID VBLI
  where D.LOCID=VBLI.LOCID and D.SITELIMCUR=CUR_L.CODE and D.SITEDEDCUR=CUR_D.CODE;
if object_id(''##l_VSL_trdet_nomcur'', ''U'') is not null drop table ##L_VSL_trdet_nomcur;
  alter table ##L_VSL_trdet add constraint PK_##L_BT_VSL_trdet_c primary key clustered (LOCID);
 '

set @sql = replace(replace(@sql, '##L', '##L' + replace(@@ts, '\', '_')), '##K', '##L');
exec sp_executesql @sql;



/*
g.7. Create extraction procedure #7:
· Create a JSON string of locations that are to be subject to special policy conditions. Special policy conditions
  apply limits and deductibles to subsets a policy's insured locations, with scope and terms that vary from policy to policy.

· For any given location, a JSON string is created for each unique combination of the following three elements: 
    (i) the name of the special condition,
    (ii) the identifier for the policy, peril, and per-occurrence loss attachment point subject to the special condition,† and
    (iii) a 0/1 flag denoting whether or not the location is included under the special condition (this should always be 1)

· The JSON string components are then concatenated to produce a single JSON string for the location.
    The concatenation is iterative, and proceeds as follows until all available strings S[1], S[2], etc., are concatenated
    into S[1], which is then entered into the table ##L_specCondFlattenWork_locconditions as the field scString:
    · Iteration 1: S[2n-1] and S[2n] are concatenated into string S[2n-1], and string S[2n] is set to an empty string 
    · Iteration 2: S[4n-3] and S[4n-1] are concatenated into string S[4n-3], and string S[4n-1] is set to an empty string 
    · Iteration 3: S[8n-7] and S[8n-3] are concatenated into string S[8n-7], and string S[8n-3] is set to an empty string

    · Iteration i:
        S[(2^i)(n-1)+1] and S[(2^(i-1))(2n-1)+1] are concatenated into S[(2^i)(n-1)+1]
        S[(2^(i-1))(2n-1)+1] is set to an empty string

· In essence, this is an order O(log2(x)) "playoff bracket concatenation." As it relies on UPDATE and INSERT statements,
  it places a high burden on RAM and the transaction log compared to the other steps of the script.

  († The policy/peril/attachment point combination is identified by a single identifier, the "policy ID")
*/

set @sql = N'
CREATE PROCEDURE [dbo].[LocationExtraction_s07]
  @k_dbname nvarchar(255)
, @k_portinfoid bigint
, @k_convertCurrency bigint
, @k_targetCurrency nvarchar(3)
, @k_outputTable nvarchar(255)
AS

declare
  @dbname nvarchar(255)
, @PortfolioID bigint
, @IsCurrencyConvert bigint
, @CurrencyTo nvarchar(3)
, @outputTable nvarchar(255)
, @counter bigint
, @count bigint
, @count_LCQ bigint
, @commandstring01 nvarchar(max)
, @sql nvarchar(max)
, @sqlString nvarchar(max)
, @max_j bigint
, @n bigint
, @k bigint
, @condCombSql nvarchar(max);

set @dbname=@k_dbname;
set @PortfolioID=@k_portinfoid;
set @IsCurrencyConvert=@k_convertCurrency;
set @CurrencyTo=@k_targetCurrency;
set @outputTable=@k_outputTable;

if object_id(''##l_speccondflattenwork_locconditions'', ''U'') is not null drop table ##L_specCondFlattenWork_locconditions;

create table ##L_specCondFlattenWork_locconditions (
  name nvarchar(255)
, policynum nvarchar(255)
, INCLUDED bigint
, CONDITIONID bigint
, POLICYID bigint
, LOCID bigint
, scStrContrib nvarchar(255)
, scStringPart nvarchar(max)
, scString nvarchar(max)
, i bigint identity(1,1)
, j bigint
);

set @sql=replace(N''
  SELECT PC.CONDITIONNAME AS name, POL.POLICYID AS policynum, LC.INCLUDED, LC.CONDITIONID, POL.POLICYID, LC.LOCID
  FROM <<dbn>>.dbo.locconditions LC, <<dbn>>.dbo.policyconditions PC, <<dbn>>.dbo.policy POL, <<dbn>>.dbo.portacct PAC
  WHERE LC.CONDITIONID = PC.CONDITIONID AND PC.POLICYID = POL.POLICYID AND LC.INCLUDED > 0
    and POL.ACCGRPID = PAC.ACCGRPID and PAC.PORTINFOID = @portselect
  ORDER BY LC.LOCID, PC.POLICYID, PC.CONDITIONID
'', ''<<dbn>>'', @dbname);

insert into ##L_specCondFlattenWork_locconditions (
  name, policynum, INCLUDED, CONDITIONID, POLICYID, LOCID
)
exec sp_executesql @sql, N''@CurrencyTo nvarchar(3),@IsCurrencyConvert bit,@portselect bigint''
,@CurrencyTo=@CurrencyTo,@IsCurrencyConvert=@IsCurrencyConvert,@portselect=@PortfolioID

update C
set C.j=C.i-M.min_i+1
from ##L_specCondFlattenWork_locconditions C, (
  select LOCID, min(i) min_i
  from ##L_specCondFlattenWork_locconditions
  group by LOCID
) M
where C.LOCID=M.LOCID;

update ##L_specCondFlattenWork_locconditions
set scStrContrib
= name + ''|''
+ policynum + ''|''
+ ltrim(str(included)) + ''{}'';



select @max_j=max(j) from ##L_specCondFlattenWork_locconditions;

if isnull(@max_j, 0)>=2
    begin
      set @n = -floor(-log(convert(float, @max_j))/log(2));
      set @k = @n;

      set @condCombSql = ''if object_id(''''##L_specCondFlattenWork_locconditions_L9999'''', ''''U'''') is not null drop table ##L_specCondFlattenWork_locconditions_L9999'';
      set @condCombSql = replace(@condCombSql, ''9999'', ltrim(str(@k+1)));
      exec sp_executesql @condCombSql;

      set @condCombSql
      = ''select * into ##L_specCondFlattenWork_locconditions_L'' + ltrim(str(@k+1))
      + '' from ##L_specCondFlattenWork_locconditions''
      exec sp_executesql @condCombSql;

      while @k>0 begin
        set @condCombSql = ''if object_id(''''##L_specCondFlattenWork_locconditions_L9999'''', ''''U'''') is not null drop table ##L_specCondFlattenWork_locconditions_L9999'';
        set @condCombSql = replace(@condCombSql, ''9999'', ltrim(str(@k)));
        exec sp_executesql @condCombSql;

        set @condCombSql = replace(replace(replace(replace(N''
          select
            L0.name, L0.policynum, L0.INCLUDED, L0.CONDITIONID, L0.POLICYID
          , L0.LOCID, L0.scStrContrib + isnull(L1.scStrContrib, '''''''') scStrContrib
          , L0.scStringPart, L0.scString, L0.i, L0.j
          into ##L_specCondFlattenWork_locconditions_L<<lo>>
          from
              ##L_specCondFlattenWork_locconditions_L<<hi>> L0
            left outer join
              ##L_specCondFlattenWork_locconditions_L<<hi>> L1
            on L1.LOCID=L0.LOCID and L1.j = L0.j + power(2, <<n>>-<<k>>)
          where (L0.j-1) & (power(2, <<n>>-<<k>>+1)-1) = 0;
        '', ''<<hi>>'', ltrim(str(@k+1))), ''<<lo>>'', ltrim(str(@k)))

         , ''<<n>>'', ltrim(str(@n))), ''<<k>>'', ltrim(str(@k)))


        exec sp_executesql @condCombSql;

        set @k = @k-1;
      end



      set @condCombSql = ''if object_id(''''##L_specCondFlattenWork_locconditions_L0'''') is not null drop table ##L_specCondFlattenWork_locconditions_L0'';
      exec sp_executesql @condCombSql;

      set @condCombSql = N''
        select
          LC.name, LC.policynum, LC.INCLUDED, LC.CONDITIONID, LC.POLICYID, LC.LOCID
        , LC.scStrContrib, LC.scStringPart
        , case when LCL1.i is not null then
            left(LCL1.scStrContrib, case when len(LCL1.scStrContrib)-2>0 then len(LCL1.scStrContrib)-2 else 0 end)
          else '''''''' end scString
        , LC.i, LC.j
        into ##L_specCondFlattenWork_locconditions_L0
        from ##L_specCondFlattenWork_locconditions LC
          left outer join ##L_specCondFlattenWork_locconditions_L1 LCL1
          on LC.i = LCL1.i
      '';
      exec sp_executesql @condCombSql;
    end
  else
    begin
      set @condCombSql = ''if object_id(''''##L_specCondFlattenWork_locconditions_L0'''') is not null drop table ##L_specCondFlattenWork_locconditions_L0'';
      exec sp_executesql @condCombSql;

      select
        LC.name, LC.policynum, LC.INCLUDED, LC.CONDITIONID, LC.POLICYID, LC.LOCID
      , LC.scStrContrib, LC.scStringPart
      , LC.scStrContrib scString
      , LC.i, LC.j
      into ##L_specCondFlattenWork_locconditions_L0
      from ##L_specCondFlattenWork_locconditions LC
    end
'
set @sql = replace(replace(@sql, '##L', '##L' + replace(@@ts, '\', '_')), '##K', '##L');
exec sp_executesql @sql;



/*
g.8. Create extraction procedure #8:
· Generate the final location data table for ingestion into the visualization software
*/

set @sql = N'
CREATE PROCEDURE [dbo].[LocationExtraction_s08]
  @k_dbname nvarchar(255)
, @k_portinfoid bigint
, @k_convertCurrency bigint
, @k_targetCurrency nvarchar(3)
, @k_outputTable nvarchar(255)
AS

declare
  @dbname nvarchar(255)
, @PortfolioID bigint
, @IsCurrencyConvert bigint
, @CurrencyTo nvarchar(3)
, @outputTable nvarchar(255)
, @counter bigint
, @count bigint
, @count_LCQ bigint
, @commandstring01 nvarchar(max)
, @sql nvarchar(max)
, @sqlString nvarchar(max);

set @dbname=@k_dbname;
set @PortfolioID=@k_portinfoid;
set @IsCurrencyConvert=@k_convertCurrency;
set @CurrencyTo=@k_targetCurrency;
set @outputTable=@k_outputTable;

if object_id(''##l_locexp'', ''U'') is not null drop table ##L_locexp;

  select
    PR.Location_ID
  , PR.Location_Number
  , PR.Location_Name
  , PR.Number_of_Buildings
  , PR.Temp_RiskModelDB_BLDGSCHEME
  , PR.Temp_RiskModelDB_BLDGCLASS
  , PR.Construction_Type
  , PR.Temp_RiskModelDB_OCCSCHEME
  , PR.Temp_RiskModelDB_OCCTYPE
  , PR.Occupancy_Type
  , PR.Number_of_Stories
  , PR.Year_Built
  , PR.Floor_Area
  , PR.Floor_Area_Unit
  , PR.Location_Inception_Date
  , PR.Location_Expiration_Date
  , PR.Primary_Location_ID
  , PR.Site_Name
  , PR.User_ID_1
  , PR.User_ID_2
  , PR.User_Text_1
  , PR.User_Text_2
  , ADR.Temp_RiskModelDB_CountryScheme
  , ADR.Temp_RiskModelDB_CountryCode
  , ADR.Country_Code_FIPS
  , ADR.Country_Name
  , ADR.State
  , ADR.County
  , ADR.City
  , ADR.Postal_Code
  , ADR.Street
  , ADR.Latitude
  , ADR.Longitude
  , ADR.RiskModelDB_Geocode_Resolution
  , ADR.Geocode_Resolution
  , case when EQD.Soil_Type_Description is null then '''' else EQD.Soil_Type_Description end Soil_Type_Description
  , ACC.Account_Number
  , ACC.Account_ID
  , ACC.Account_Name
  , case when FLD.RiskModelDB_FL_Zone is null then '''' else FLD.RiskModelDB_FL_Zone end RiskModelDB_FL_Zone
  , case when FLD.RiskModelDB_BFE is null then '''' else FLD.RiskModelDB_BFE end RiskModelDB_BFE
  , case when FLD.RiskModelDB_SFHA is null then '''' else FLD.RiskModelDB_SFHA end RiskModelDB_SFHA
  , case when FLD.RiskModelDB_Annual_FL_Probability is null then '''' else FLD.RiskModelDB_Annual_FL_Probability end RiskModelDB_Annual_FL_Probability
  , case when FLD.RiskModelDB_FL_Other_Zones is null then '''' else FLD.RiskModelDB_FL_Other_Zones end RiskModelDB_FL_Other_Zones
  , case when HUD.Distance_to_Coast is null then convert(float, 0) else HUD.Distance_to_Coast end Distance_to_Coast
  , case when EQD.EQ_Site_Limit is null then convert(float, 0) else EQD.EQ_Site_Limit end EQ_Site_Limit
  , case when EQD.EQ_Site_Deductible is null then convert(float, 0) else EQD.EQ_Site_Deductible end EQ_Site_Deductible
  , case when FLD.FL_Site_Limit is null then convert(float, 0) else FLD.FL_Site_Limit end FL_Site_Limit
  , case when FLD.FL_Site_Deductible is null then convert(float, 0) else FLD.FL_Site_Deductible end FL_Site_Deductible
  , case when FRD.FR_Site_Limit is null then convert(float, 0) else FRD.FR_Site_Limit end FR_Site_Limit
  , case when FRD.FR_Site_Deductible is null then convert(float, 0) else FRD.FR_Site_Deductible end FR_Site_Deductible
  , case when HUD.HU_Site_Limit is null then convert(float, 0) else HUD.HU_Site_Limit end HU_Site_Limit
  , case when HUD.HU_Site_Deductible is null then convert(float, 0) else HUD.HU_Site_Deductible end HU_Site_Deductible
  , case when TOD.TO_Site_Limit is null then convert(float, 0) else TOD.TO_Site_Limit end TO_Site_Limit
  , case when TOD.TO_Site_Deductible is null then convert(float, 0) else TOD.TO_Site_Deductible end TO_Site_Deductible
  , case when TRD.TR_Site_Limit is null then convert(float, 0) else TRD.TR_Site_Limit end TR_Site_Limit
  , case when TRD.TR_Site_Deductible is null then convert(float, 0) else TRD.TR_Site_Deductible end TR_Site_Deductible
  , isnull(VBLI.EQ_Building_Value, 0) EQ_Building_Value
  , isnull(VBLI.EQ_Other_Structures_Value, 0) EQ_Other_Structures_Value
  , isnull(VBLI.EQ_Contents_Value, 0) EQ_Contents_Value
  , isnull(VBLI.EQ_Business_Interruption_Value, 0) EQ_Business_Interruption_Value
  , isnull(VBLI.EQ_Combined_Value, 0) EQ_Combined_Value
  , isnull(VBLI.WS_Building_Value, 0) WS_Building_Value
  , isnull(VBLI.WS_Other_Structures_Value, 0) WS_Other_Structures_Value
  , isnull(VBLI.WS_Contents_Value, 0) WS_Contents_Value
  , isnull(VBLI.WS_Business_Interruption_Value, 0) WS_Business_Interruption_Value
  , isnull(VBLI.WS_Combined_Value, 0) WS_Combined_Value
  , isnull(VBLI.TO_Building_Value, 0) TO_Building_Value
  , isnull(VBLI.TO_Contents_Value, 0) TO_Contents_Value
  , isnull(VBLI.TO_Other_Structures_Value, 0) TO_Other_Structures_Value
  , isnull(VBLI.TO_Combined_Value, 0) TO_Combined_Value
  , isnull(VBLI.TO_Business_Interruption_Value, 0) TO_Business_Interruption_Value
  , isnull(VBLI.FL_Building_Value, 0) FL_Building_Value
  , isnull(VBLI.FL_Other_Structures_Value, 0) FL_Other_Structures_Value
  , isnull(VBLI.FL_Contents_Value, 0) FL_Contents_Value
  , isnull(VBLI.FL_Business_Interruption_Value, 0) FL_Business_Interruption_Value
  , isnull(VBLI.FL_Combined_Value, 0) FL_Combined_Value
  , isnull(VBLI.FR_Building_Value, 0) FR_Building_Value
  , isnull(VBLI.FR_Other_Structures_Value, 0) FR_Other_Structures_Value
  , isnull(VBLI.FR_Contents_Value, 0) FR_Contents_Value
  , isnull(VBLI.FR_Business_Interruption_Value, 0) FR_Business_Interruption_Value
  , isnull(VBLI.FR_Combined_Value, 0) FR_Combined_Value
  , isnull(VBLI.TR_Building_Value, 0) TR_Building_Value
  , isnull(VBLI.TR_Other_Structures_Value, 0) TR_Other_Structures_Value
  , isnull(VBLI.TR_Contents_Value, 0) TR_Contents_Value
  , isnull(VBLI.TR_Business_Interruption_Value, 0) TR_Business_Interruption_Value
  , isnull(VBLI.TR_Combined_Value, 0) TR_Combined_Value
  , isnull(VBLI.Total_Insured_Value, 0) Total_Insured_Value
  , case when SCF.scString is null then '''' else SCF.scString end Special_Conditions
  , case
      when isnull(SCF.scString, '''')='''' then convert(bigint, 0)
      else floor(0.5*(len(SCF.scString)-len(replace(SCF.scString, ''{}'', '''')))) + 1
    end Special_Conditions_Count
  into ##L_locexp
  from
    ##L_VSL_property PR
    left outer join ##L_VSL_eqdet EQD on EQD.LOCID=PR.Location_ID
    left outer join ##L_VSL_hudet HUD on HUD.LOCID=PR.Location_ID
    left outer join ##L_VSL_todet TOD on TOD.LOCID=PR.Location_ID
    left outer join ##L_VSL_fldet FLD on FLD.LOCID=PR.Location_ID
    left outer join ##L_VSL_frdet FRD on FRD.LOCID=PR.Location_ID
    left outer join ##L_VSL_trdet TRD on TRD.LOCID=PR.Location_ID
    left outer join (select * from ##L_specCondFlattenWork_locconditions_L0 where j=1) SCF on SCF.LOCID=PR.Location_ID
    left outer join ##L_valuesByLocID VBLI on PR.Location_ID=VBLI.LOCID
  , ##L_VSL_account ACC
  , ##L_VSL_address ADR
  where PR.Location_ID=ACC.LOCID
    and PR.Location_ID=ADR.LOCID

if object_id(''<<dbn>>.dbo.locexp_<<ts>>'', ''U'') is not null drop table <<dbn>>.dbo.locexp_<<ts>>;

select Location_ID, Location_Number, Location_Name, Number_of_Buildings, Temp_RiskModelDB_BLDGSCHEME, Temp_RiskModelDB_BLDGCLASS
  , Construction_Type, Temp_RiskModelDB_OCCSCHEME, Temp_RiskModelDB_OCCTYPE, Occupancy_Type, Number_of_Stories, Year_Built, Floor_Area, Floor_Area_Unit
  , Location_Inception_Date, Location_Expiration_Date, Primary_Location_ID, Site_Name, User_ID_1, User_ID_2, User_Text_1, User_Text_2
  , Temp_RiskModelDB_CountryScheme, Temp_RiskModelDB_CountryCode, Country_Code_FIPS, Country_Name, State, County, City, Postal_Code, Street, Latitude
  , Longitude, RiskModelDB_Geocode_Resolution, Geocode_Resolution, Soil_Type_Description, Account_Number, Account_ID, Account_Name, RiskModelDB_FL_Zone
  , RiskModelDB_BFE, RiskModelDB_SFHA, RiskModelDB_Annual_FL_Probability, RiskModelDB_FL_Other_Zones, Distance_to_Coast, EQ_Site_Limit, EQ_Site_Deductible
  , FL_Site_Limit, FL_Site_Deductible, FR_Site_Limit, FR_Site_Deductible, HU_Site_Limit, HU_Site_Deductible, TO_Site_Limit
  , TO_Site_Deductible, TR_Site_Limit, TR_Site_Deductible, EQ_Building_Value, EQ_Other_Structures_Value, EQ_Contents_Value
  , EQ_Business_Interruption_Value, EQ_Combined_Value, WS_Building_Value, WS_Other_Structures_Value, WS_Contents_Value
  , WS_Business_Interruption_Value, WS_Combined_Value, TO_Building_Value, TO_Contents_Value, TO_Other_Structures_Value
  , TO_Combined_Value, TO_Business_Interruption_Value, FL_Building_Value, FL_Other_Structures_Value, FL_Contents_Value
  , FL_Business_Interruption_Value, FL_Combined_Value, FR_Building_Value, FR_Other_Structures_Value, FR_Contents_Value
  , FR_Business_Interruption_Value, FR_Combined_Value, TR_Building_Value, TR_Other_Structures_Value, TR_Contents_Value
  , TR_Business_Interruption_Value, TR_Combined_Value, Total_Insured_Value, Special_Conditions
  , Special_Conditions_Count from ##L_locexp;

'



/*
h. Run all the extraction procedures defined in steps g.1. through g.8. In each case:
· Replace <<dbn>> with the name of the database selected by the user
· Replace <<pid>> with numeric index of the property insurance portfolio in the risk model database
· Replace <<ts>> with the timestamp
*/

set @sql = replace(replace(replace(
  replace(replace(
  @sql
, '##L', '##L' + replace(@@ts, '\', '_')), '##K', '##L')
, '<<dbn>>', @@dbname), '<<pid>>', ltrim(str(@@PortfolioID))), '<<ts>>', replace(@@ts, '\', '_'));
exec sp_executesql @sql;

set @sql='EXEC [dbo].[LocationExtraction_s01] @k_dbname = N''' + @@dbname + ''', @k_portinfoid = ' + ltrim(str(@@PortfolioID)) + ', @k_convertCurrency = '
+ ltrim(str(@@IsCurrencyConvert)) + ', @k_targetCurrency = N''' + @@CurrencyTo + ''', @k_outputTable = N''locexp_' + replace(@@ts, '\', '_') + ''''
exec sp_executesql @sql

set @sql=replace(@sql, 's01', 's02');
exec sp_executesql @sql

set @sql=replace(@sql, 's02', 's03');
exec sp_executesql @sql

set @sql=replace(@sql, 's03', 's04');
exec sp_executesql @sql

set @sql=replace(@sql, 's04', 's05');
exec sp_executesql @sql

set @sql=replace(@sql, 's05', 's06');
exec sp_executesql @sql

set @sql=replace(@sql, 's06', 's07');
exec sp_executesql @sql

set @sql=replace(@sql, 's07', 's08');
exec sp_executesql @sql

