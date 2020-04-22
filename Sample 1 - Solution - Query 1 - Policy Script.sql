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
b. Set the time stamp, which will also include the name of the server running the query --
   e.g., 20190322085714_EC2AMAZ_QRG0RLJ denotes 2019/03/22,
   08:57:14 (8:57am and 14 seconds), server EC2AMAZ-QRG0RLJ (this server)
*/

set @@ts = replace(replace(replace(left(convert(datetime2, getdate()), 19), ':', ''), ' ', ''), '-', '') + '_' + replace(@@servername, '-', '_')



/*
c. Set the database name, portfolio ID, option to convert,
     and currency conversion target selected by the user
*/

set @@dbname=db_name();

set @@PortfolioID=@PortfolioID;
set @@IsCurrencyConvert=@IsCurrencyConvert;
set @@CurrencyTo=@CurrencyTo;

set @sql = 'if object_id ('''
  + @@dbname + '_' + right('000' + LTrim(Str(@@PortfolioID)), 4) + '_timestamp'
  + ''') is not null drop table '
  + @@dbname + '_' + right('000' + LTrim(Str(@@PortfolioID)), 4) + '_timestamp';
exec sp_executesql @sql;

set @sql = 'select ''' + @@ts + ''' ts into ' + @@dbname + '_' + right('000' + LTrim(Str(@@PortfolioID)), 4) + '_timestamp';
EXECUTE sp_executesql @sql;



/*
d. Extract policy-level special conditions (terms that apply to subsets of insured locations,
   as described in the remarks in the location script)
*/

SET @sql = N'
  if object_id(''##L_specCondFlattenWork_policyconditions'') is not null drop table  ##L_specCondFlattenWork_policyconditions;

  create table ##L_specCondFlattenWork_policyconditions (
    name nvarchar(255)
  , type bigint
  , limit float
  , deductible float
  , parentname nvarchar(255)
  , CONDITIONID bigint
  , POLICYID bigint
  , PARENTCONDITIONID bigint
  , scStrContrib nvarchar(255)
  , scStringPart nvarchar(max)
  , scString nvarchar(max)
  , i bigint identity(1,1)
  , j bigint
  );

  insert into ##L_specCondFlattenWork_policyconditions (
    name, type, limit, deductible, parentname, CONDITIONID, POLICYID, PARENTCONDITIONID
  )
  exec sp_executesql N''
  SELECT
    PC.CONDITIONNAME AS name
  , PC.CONDITIONTYPE AS type
  , dbo.ufnCurrencyConversion(PC.LIMIT, POL.blanlimcur, @CurrencyTo, @IsCurrencyConvert, 1) AS limit
  , dbo.ufnCurrencyConversion(PC.DEDUCTIBLE, POL.blandedcur, @CurrencyTo, @IsCurrencyConvert, 1) AS deductible
  , (select PCP.CONDITIONNAME FROM <<dbn>>.dbo.policyconditions PCP WHERE PCP.CONDITIONID = PC.PARENTCONDITIONID) AS parentname
  , PC.CONDITIONID, PC.POLICYID, PC.PARENTCONDITIONID
  FROM <<dbn>>.dbo.policyconditions PC, <<dbn>>.dbo.policy POL, <<dbn>>.dbo.portacct PAC
  WHERE PC.POLICYID = POL.POLICYID and POL.ACCGRPID = PAC.ACCGRPID and PAC.PORTINFOID = @portSelect
  ORDER BY PC.POLICYID, PC.CONDITIONID
  ''
  ,N''@CurrencyTo nvarchar(3),@IsCurrencyConvert bit,@portselect bigint''
  ,@CurrencyTo=N''USD'',@IsCurrencyConvert=1,@portselect=<<pid>>

  update C
  set C.j=C.i-M.min_i+1
  from ##L_specCondFlattenWork_policyconditions C, (
    select POLICYID, min(i) min_i
    from ##L_specCondFlattenWork_policyconditions
    group by POLICYID
  ) M
  where C.POLICYID=M.POLICYID;

  update ##L_specCondFlattenWork_policyconditions
  set scStrContrib
  = name + ''|''
  + ltrim(str(type)) + ''|''
  + ltrim(str(limit, 22, 9)) + ''|''
  + ltrim(str(deductible, 22, 9)) + ''|''
  + case when parentname is null then ''NULL'' else parentname end + ''{}'';

  if object_id(''##L_specCondFlattenWork_policyconditions_stringparts'') is not null drop table  ##L_specCondFlattenWork_policyconditions_stringparts;

  select power(2, -floor(-log(power(convert(float, case when max(ct)=1 then 2 else max(ct) end), 0.5))/log(2))) pts
  into ##L_specCondFlattenWork_policyconditions_stringparts
  from (
    select max(j) ct from ##L_specCondFlattenWork_policyconditions
  ) U;

  update C
  set C.scStringPart=C.scStrContrib
  from ##L_specCondFlattenWork_policyconditions C
  , ##L_specCondFlattenWork_policyconditions_stringparts PTS
  , (select POLICYID, max(j) max_j from ##L_specCondFlattenWork_policyconditions group by POLICYID) M
  where C.POLICYID=M.POLICYID and (C.j=M.max_j or (C.j & (PTS.pts-1)) = 0);

  declare @sqlString nvarchar(max), @counter bigint, @count bigint;
  select @count=pts from ##L_specCondFlattenWork_policyconditions_stringparts;

  set @counter=@count-1;

  while @counter>0 begin
    update C0
    set C0.scStringPart = C0.scStrContrib + C1.scStringPart
    from
      ##L_specCondFlattenWork_policyconditions C0
    , ##L_specCondFlattenWork_policyconditions C1
    where C0.POLICYID=C1.POLICYID and C0.j & (@count-1) = @counter and C1.j=C0.j+1;

    update C1
    set C1.scStringPart = ''''
    from
      ##L_specCondFlattenWork_policyconditions C0
    , ##L_specCondFlattenWork_policyconditions C1
    where C0.POLICYID=C1.POLICYID and C0.j & (@count-1) = @counter and C1.j=C0.j+1;

    set @counter=@counter-1;
  end;

  update PC
  set PC.scString=PC.scStringPart
  from ##L_specCondFlattenWork_policyconditions PC, (
    select POLICYID, j
    from ##L_specCondFlattenWork_policyconditions
    where j & (@count-1) = 1
    group by POLICYID, j
  ) M
  where PC.POLICYID=M.POLICYID and PC.j=M.j;

  select @counter=max(j)
  from ##L_specCondFlattenWork_policyconditions
  where j & (@count-1) = 1;

  while @counter>@count begin
    update C0
    set C0.scString = C0.scStringPart + C1.scString
    from
      ##L_specCondFlattenWork_policyconditions C0
    , ##L_specCondFlattenWork_policyconditions C1
    where C0.POLICYID=C1.POLICYID and C1.j=@counter and C0.j=C1.j-@count;

    update C1
    set C1.scString = ''''
    from
      ##L_specCondFlattenWork_policyconditions C0
    , ##L_specCondFlattenWork_policyconditions C1
    where C0.POLICYID=C1.POLICYID and C1.j=@counter and C0.j=C1.j-@count;

    set @counter=@counter-@count;
  end;

  update ##L_specCondFlattenWork_policyconditions set scString=left(scString, len(scString)-2) where j=1;

  if object_id(''##L_specCondFlattenWork_policyconditions_varCharsNeeded'') is not null drop table  ##L_specCondFlattenWork_policyconditions_varCharsNeeded;

  select -floor(-convert(float, max(len(scString)))/8000) VCN
  into ##L_specCondFlattenWork_policyconditions_varCharsNeeded
  from ##L_specCondFlattenWork_policyconditions where j=1;

  if object_id(''##L_specCondFlattenWork_policyconditionStrings'') is not null drop table  ##L_specCondFlattenWork_policyconditionStrings;

  /*
  select @count=VCN from ##L_specCondFlattenWork_policyconditions_varCharsNeeded;
  if @count is null or @count<1
  */ set @count=1;
  set @counter=1;

  set @sqlString=''select POLICYID'';

  while @counter<=@count begin
    set
      @sqlString = @sqlString
    + '', scString''
    set @counter=@counter+1;
  end

  set @sqlString = @sqlString
    + '' into ##L_specCondFlattenWork_policyconditionStrings''
    + '' from ##L_specCondFlattenWork_policyconditions where j=1''
    + '' order by POLICYID'';

  exec (@sqlString);
';

set @sql = replace(replace(
  replace(replace(@sql, '##L', '##L' + replace(@@ts, '\', '_')), '##K', '##L')
, '<<dbn>>', @@dbname), '<<pid>>', ltrim(str(@@PortfolioID)));
EXECUTE sp_executesql @sql;



/*
e. Create policy data table
*/

set @sql = N'
  if object_id(''##<<dbn>>_dbo_polexp_<<ts>>'') is not null drop table  ##<<dbn>>_dbo_polexp_<<ts>>;

  create table ##<<dbn>>_dbo_polexp_<<ts>> (
    Account_ID bigint
  , Account_Name nvarchar(255)
  , Underwriter_Name nvarchar(255)
  , Branch_Name nvarchar(255)
  , Cedant_ID nvarchar(255)
  , Producer_ID nvarchar(255)
  , User_ID_1 nvarchar(255)
  , User_ID_2 nvarchar(255)
  , User_ID_3 nvarchar(255)
  , User_ID_4 nvarchar(255)
  , User_Text_1 nvarchar(255)
  , User_Text_2 nvarchar(255)
  , Blanket_Minimum_Deductible float
  , Line_of_Business nvarchar(255)
  , Policy_Peril nvarchar(255)
  , Attachment_Point float
  , Layer_Amount float
  , Blanket_Limit float
  , Maximum_Deductible float
  , Policy_ID bigint
  , Policy_Inception_Date datetime
  , policy_Expiration_Date datetime
  , Blanket_Premium float
  , Policy_Stat nvarchar(255)
  , Policy_Number nvarchar(255)
  , Special_Conditions nvarchar(max)
  , Special_Conditions_Count bigint
  );

  insert into ##<<dbn>>_dbo_polexp_<<ts>>
  exec sp_executesql N''
  SELECT
    accgrp.ACCGRPID                          AS Account_ID,
    accgrp.ACCGRPNAME                        AS Account_Name,
    accgrp.UWRITRNAME                        AS Underwriter_Name,
    accgrp.BRANCHNAME                        AS Branch_Name,
    accgrp.CEDANTID                          AS Cedant_ID,
    accgrp.PRDCERID                          AS Producer_ID,
    accgrp.USERID1                           AS User_ID_1,
    accgrp.USERID2                           AS User_ID_2,
    accgrp.USERID3                           AS User_ID_3,
    accgrp.USERID4                           AS User_ID_4,
    accgrp.USERTXT1                          AS User_Text_1,
    accgrp.USERTXT2                          AS User_Text_2,
    CASE policy.mindedamt
    WHEN 0
      THEN dbo.ufnCurrencyConversion(policy.blandedamt, policy.blandedcur, @CurrencyTo, @IsCurrencyConvert, 1)
    ELSE dbo.ufnCurrencyConversion(policy.mindedamt, policy.mindedcur, @CurrencyTo, @IsCurrencyConvert, 1) END AS Blanket_Minimum_Deductible,
    COALESCE(lobdet.LOBNAME, '''''''')           AS Line_of_Business,
    CASE policy.POLICYTYPE
    WHEN 1
      THEN ''''EQ''''
    WHEN 2
      THEN ''''HU''''
    WHEN 3
      THEN ''''TO''''
    WHEN 4
      THEN ''''FL''''
    WHEN 5
      THEN ''''FR''''
    WHEN 6
      THEN ''''TR''''
    ELSE ''''unknown'''' END                     AS Policy_Peril,
    dbo.ufnCurrencyConversion(policy.UNDCOVAMT, policy.UNDCOVCUR, @CurrencyTo, @IsCurrencyConvert, 0) AS Attachment_Point,
    dbo.ufnCurrencyConversion(policy.PARTOF, policy.PARTOFCUR, @CurrencyTo, @IsCurrencyConvert, 1) AS Layer_Amount,
    dbo.ufnCurrencyConversion(policy.BLANLIMAMT, policy.BLANLIMCUR, @CurrencyTo, @IsCurrencyConvert, 1) AS Blanket_Limit,
    dbo.ufnCurrencyConversion(policy.MAXDEDAMT, policy.MAXDEDCUR, @CurrencyTo, @IsCurrencyConvert, 1) AS Maximum_Deductible,
    policy.POLICYID                          AS Policy_ID,
    cast(Month(policy.INCEPTDATE) AS VARCHAR) + ''''/'''' + cast(Day(policy.INCEPTDATE) AS VARCHAR) + ''''/'''' +
    cast(YEAR(policy.INCEPTDATE) AS VARCHAR) AS Policy_Inception_Date,
    cast(Month(policy.EXPIREDATE) AS VARCHAR) + ''''/'''' + cast(Day(policy.EXPIREDATE) AS VARCHAR) + ''''/'''' +
    cast(YEAR(policy.EXPIREDATE) AS VARCHAR) AS policy_Expiration_Date,
    dbo.ufnCurrencyConversion(policy.BLANPREAMT, policy.BLANPRECUR, @CurrencyTo, @IsCurrencyConvert, 0) AS Blanket_Premium,
    policy.POLICYSTAT                        AS Policy_Stat,
    policy.POLICYNUM                         AS Policy_Number,
    convert(nvarchar(max),'''''''')               AS Special_Conditions,
    convert(bigint, 0)                       AS Special_Conditions_Count
  FROM <<dbn>>.dbo.portinfo
    INNER JOIN <<dbn>>.dbo.portacct ON portinfo.PORTINFOID = portacct.PORTINFOID
    INNER JOIN <<dbn>>.dbo.accgrp ON portacct.ACCGRPID = accgrp.ACCGRPID
    INNER JOIN <<dbn>>.dbo.policy ON accgrp.ACCGRPID = policy.ACCGRPID
    LEFT OUTER JOIN <<dbn>>.dbo.lobdet ON policy.LOBDETID = lobdet.LOBDETID
  WHERE ACCGRP.ISVALID = 1 AND POLICY.ISVALID = 1 AND POLICY.POLICYTYPE IN (1, 2, 3, 4, 5, 6) AND
        portinfo.PORTINFOID = @PortfolioId AND portacct.PORTINFOID = @PortfolioId
  '',N''@PortfolioId nvarchar(8),@CurrencyTo nvarchar(3),@IsCurrencyConvert bit'',@PortfolioId=''<<pid>>'',@CurrencyTo=N''USD'',@IsCurrencyConvert=1
'

set @sql = replace(replace(replace(
  @sql
, '<<dbn>>', @@dbname), '<<pid>>', ltrim(str(@@PortfolioID))), '<<ts>>', replace(@@ts, '\', '_'));
exec sp_executesql @sql;



/*
f. Populate policy data table with special conditions string
*/

set @sql = N'
  if (select sum(1) from tempdb.INFORMATION_SCHEMA.columns where TABLE_NAME=''##L_specCondFlattenWork_policyconditionStrings'' and column_name=''scString'') is not null begin
    update PE
    set
      PE.Special_Conditions = PCS.scString
    , PE.Special_Conditions_Count = 1+(len(PCS.scString)-len(replace(PCS.scString, ''}'', '''')))
    from
      ##L_specCondFlattenWork_policyconditionStrings PCS
    , ##<<dbn>>_dbo_polexp_<<ts>> PE
    where PCS.POLICYID=PE.POLICY_ID
  end
'

set @sql = replace(replace(replace(
  replace(replace(
  @sql
, '##L', '##L' + replace(@@ts, '\', '_')), '##K', '##L')
, '<<dbn>>', @@dbname), '<<pid>>', ltrim(str(@@PortfolioID))), '<<ts>>', replace(@@ts, '\', '_'));
exec sp_executesql @sql;



set @sql = replace(replace(replace(
  'select * from ##<<dbn>>_dbo_polexp_<<ts>>'
, '<<dbn>>', @@dbname), '<<pid>>', ltrim(str(@@PortfolioID))), '<<ts>>', replace(@@ts, '\', '_'));
exec (@sql);