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
  COALESCE(lobdet.LOBNAME, '')           AS Line_of_Business,
  CASE policy.POLICYTYPE
  WHEN 1
    THEN 'EQ'
  WHEN 2
    THEN 'HU'
  WHEN 3
    THEN 'TO'
  WHEN 4
    THEN 'FL'
  WHEN 5
    THEN 'FR'
  WHEN 6
    THEN 'TR'
  ELSE 'unknown' END                     AS Policy_Peril,
  dbo.ufnCurrencyConversion(policy.UNDCOVAMT, policy.UNDCOVCUR, @CurrencyTo, @IsCurrencyConvert, 0) AS Attachment_Point,
  dbo.ufnCurrencyConversion(policy.PARTOF, policy.PARTOFCUR, @CurrencyTo, @IsCurrencyConvert, 1) AS Layer_Amount,
  dbo.ufnCurrencyConversion(policy.BLANLIMAMT, policy.BLANLIMCUR, @CurrencyTo, @IsCurrencyConvert, 1) AS Blanket_Limit,
  dbo.ufnCurrencyConversion(policy.MAXDEDAMT, policy.MAXDEDCUR, @CurrencyTo, @IsCurrencyConvert, 1) AS Maximum_Deductible,
  policy.POLICYID                          AS Policy_ID,
  cast(Month(policy.INCEPTDATE) AS VARCHAR) + '/' + cast(Day(policy.INCEPTDATE) AS VARCHAR) + '/' +
  cast(YEAR(policy.INCEPTDATE) AS VARCHAR) AS Policy_Inception_Date,
  cast(Month(policy.EXPIREDATE) AS VARCHAR) + '/' + cast(Day(policy.EXPIREDATE) AS VARCHAR) + '/' +
  cast(YEAR(policy.EXPIREDATE) AS VARCHAR) AS policy_Expiration_Date,
  dbo.ufnCurrencyConversion(policy.BLANPREAMT, policy.BLANPRECUR, @CurrencyTo, @IsCurrencyConvert, 0) AS Blanket_Premium,
  policy.POLICYSTAT                        AS Policy_Stat,
  policy.POLICYNUM                         AS Policy_Number,
  ''									   AS Special_Conditions,
  ''									   AS Special_Conditions_Count
FROM portinfo
  INNER JOIN portacct ON portinfo.PORTINFOID = portacct.PORTINFOID
  INNER JOIN accgrp ON portacct.ACCGRPID = accgrp.ACCGRPID
  INNER JOIN policy ON accgrp.ACCGRPID = policy.ACCGRPID
  LEFT OUTER JOIN lobdet ON policy.LOBDETID = lobdet.LOBDETID
WHERE ACCGRP.ISVALID = 1 AND POLICY.ISVALID = 1 AND POLICY.POLICYTYPE IN (1, 2, 3, 4, 5, 6) AND
      portinfo.PORTINFOID = @PortfolioId AND portacct.PORTINFOID = @PortfolioId
