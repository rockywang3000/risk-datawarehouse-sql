
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED     
SET NOCOUNT ON  

--get information by limiting createdate, then compare existing dataware, insert New records if any

-- for 6-30-2011
drop table pubs.dbo.acct2
select  c.AccountKey,c.CreateDate, p.BankKey,b.BankName,case when p.isOnlineProduct =1 then 'Online' else 'Retail' end as Channel
into pubs.dbo.acct2
from vcustomer c (nolock)
join vuproduct p (nolock) on c.productkey = p.productkey
join Bank b (nolock) on p.BankKey = b.BankKey
where c.CreateDate >= '1/1/2011'
and c.CreateDate < '9/1/2012'
and isnull(c.SecretWord, '') NOT LIKE 'NECTEST%'  
AND isnull(c.FirstName, '') NOT LIKE 'test%'   
AND isnull(c.LastName, '') NOT LIKE 'test%'
AND isnull(c.address1, '') NOT LIKE '%605 E HUNTINGTON%' 
AND isnull(c.residentialaddress1, '') NOT LIKE '%605 E HUNTINGTON%'    
AND isnull(c.email, '') NOT LIKE '%@greendot%' 
and p.ourcardtypekey = 1 --exclude gift cards
and AccountKey is not null


drop table pubs.dbo.acct3
select tt.AccountKey, CreateDate,BankKey,BankName,Channel 
into pubs.dbo.acct3 
from (
select *,DENSE_RANK() over (partition by accountkey order by createdate desc) as attempt 
from pubs.dbo.acct2 (Nolock)
)tt
where attempt=1



create index inadfad on pubs.dbo.acct3 (accountkey)

/*--October 2011
--GE 4,367,505
--GD 5,593,380
select count(accountkey) from pubs.dbo.acct3



select count(*) from pubs.dbo.acct4

select accountkey from pubs.dbo.acct3 group by accountkey having count(*) > 1

select  * from pubs.dbo.acct4 where accountkey = 27346982

*/

--Latest is the last identityvalidationkey; customerkey is the one used for activation
drop table pubs.dbo.acct4
select tt.* into pubs.dbo.acct4 from pubs.dbo.acct3 (nolock) cross apply pubs.dbo.fcipwithaccountkey (pubs.dbo.acct3.AccountKey) tt


--select * from pubs.dbo.acct3

drop table pubs.dbo.acct5
select t.*,Latest as LastIdentityValidationKey,
VerificationStatusType,LastAttemptValue
into pubs.dbo.acct5 from pubs.dbo.acct3 t (nolock) left join pubs.dbo.acct4 a (nolock) on t.AccountKey= a.Accountkey


/*
drop table pubs.dbo.acct1

select COUNT(distinct Accountkey) from pubs.dbo.acct4

select * from pubs.dbo.acct5 where accountkey = 27338162

--1614876
select COUNT(Accountkey) from #temp

1049632
select COUNT(distinct Accountkey) from #temp

select * from pubs.dbo.acct3 where AccountKey not in (select AccountKey from pubs.dbo.acct4)

27347947
27349310
27349319

select * from vCustomer where AccountKey = 27347947
select * from pubs.dbo.fTempPersowithAccountkey (27338162)

*/

-- just rerun this to update info. compare if there is any difference, then update accordingly; run it daily
--creat 3 indices


------------------------------------------when LAST put the compliance block---------------------------
--Get who put the last credit rating
drop table pubs.dbo.acct6
select customerkey,max(changedate) LatestDate
into pubs.dbo.acct6
from creditratinghistory crh  (nolock)  
where crh.creditratingkey in ('B5','P9', 'C5')
--and ChangeDate >=  convert(varchar(10),getdate()-30,101)  
and ChangeDate >=  '1/1/2011'  
and ChangeDate <  '10/1/2012'  
group by customerkey

---select * from creditratinghistory order by changedate desc

drop table pubs.dbo.acct7
select --v.AccountKey,
c.customerkey,crh.ChangeDate, crh.creditratingkey,crh.sysuserkey, fullname
into pubs.dbo.acct7
from pubs.dbo.acct6 c (nolock)
join creditratinghistory crh  (nolock) on c.customerkey = crh.customerkey and crh.changedate = latestdate
join sysuser su  (nolock) on crh.sysuserkey = su.sysuserkey
--join vCustomer v (nolock) on c.CustomerKey= v.CustomerKey
where 
crh.creditratingkey in ('B5','P9', 'B3') or 
(
crh.creditratingkey = 'C5'
and 
crh.sysuserkey in(3227, 2933,989,1884,4561,4562,988,2370,4153,2690,2687,6838,4176,7347,7090,6917,6918)
)

--select * from SysUser where FullName like '%chebe%'


-- Final Result with creditratingkey change user
drop table pubs.dbo.acct8
select f.accountkey, a.*, DENSE_RANK() over (partition by f.accountkey order by a.changedate desc) as attempt
into pubs.dbo.acct8
from pubs.dbo.acct7 a (nolock) join vCustomer f (nolock)  on f.customerkey = a.customerkey and a.CreditRatingKey=f.CreditRatingKey



------------------------------------------------------------------------
-- combine together
drop table pubs.dbo.acct9
select f.*, a.CreditRatingKey as BlockCreditratingkey, ChangeDate as BlockDate, FullName as BlockUser
into pubs.dbo.acct9
from pubs.dbo.acct5 f (nolock) left join pubs.dbo.acct8 a (nolock) on f.AccountKey = a.AccountKey and a.attempt = 1


--
/*
select AccountKey from pubs.dbo.acct9 group by AccountKey having count(*) > 1

select * from pubs.dbo.acct9 where accountkey = 30541218

select * from pubs.dbo.fTempPersowithAccountkey (30541218)

t
42641574
p
42648288

select * from pubs.dbo.acct7 where CustomerKey in (42641574,42648288)
*/

create index ina on pubs.dbo.acct9 (accountkey)


drop table pubs.dbo.acct10
select pubs.dbo.acct9.*,TCustomerkey, TCreditRatingkey,TCurrBalance,PCustomerkey,PCreditRatingkey,PCurrBalance,VCustomerkey,
DOB,CardActivationDate,ProductKey,HomePhone,CellPhone,Email,ResidentialAddress1,ResidentialAddress2,ResidentialCity,ResidentialState,ResidentialZipcode,
Address1,Address2,City,State,ZipCode
into pubs.dbo.acct10
from pubs.dbo.acct9 (nolock) cross apply pubs.dbo.fTempPersowithAccountkey (pubs.dbo.acct9.AccountKey) tt 


--select * from pubs.dbo.acct10

/*
drop table pubs.dbo.acct
select * into pubs.dbo.acct from pubs.dbo.acct10

*/

select COUNT(distinct AccountKey) from pubs.dbo.acct10
select AccountKey, count(*) from pubs.dbo.acct10 group by AccountKey having COUNT(*) > 1




select distinct * 
into ci_dsa.dbo.RPO_ACCT1
from pubs.dbo.acct10 (nolock)

-- there are still 45 duplicates--need to research
select accountkey, COUNT(*) from ci_dsa.dbo.RPO_ACCT1 group by AccountKey having COUNT(*) > 1
select * from pubs.dbo.acct10 where AccountKey = 49012879
select * from vCustomer where AccountKey = 49012879




select IDENTITY(int,1,1) as Tablekey, * 
into ci_dsa.dbo.RPO_ACCT
from ci_dsa.dbo.RPO_ACCT1 (nolock)


-- Create indices

create index indexAccountkey on ci_dsa.dbo.RPO_ACCT (accountkey)
create index indexT on ci_dsa.dbo.RPO_ACCT (tcustomerkey)
create index indexP on ci_dsa.dbo.RPO_ACCT (pcustomerkey)
create index indexbankkey on ci_dsa.dbo.RPO_ACCT (bankkey)
create index indexcreatedate on ci_dsa.dbo.RPO_ACCT (createdate)
create index indexV on ci_dsa.dbo.RPO_ACCT (vcustomerkey)



select Top 10 * from ci_dsa.dbo.RPO_ACCT


