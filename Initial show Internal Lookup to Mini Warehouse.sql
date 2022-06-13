
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED     
SET NOCOUNT ON  


drop table pubs.dbo.i1
select * into pubs.dbo.i1 
from CI_DSA.dbo.RPO_ACCT ci (nolock) where activation_step = 'approved' and LastAttemptValue is null 

create index ii2 on pubs.dbo.i1(accountkey)
create index ii3 on pubs.dbo.i1(lastidentityvalidationkey)

--2226872
select COUNT(*) from pubs.dbo.i1

drop table pubs.dbo.i2
select 
b.CreateDate as identityCreateDate,b.ValidationResultCode,
b.IdentityValidationStatusTypeKey,IdentityValidationStatusType,
b.IdentityValidationVendorKey,IdentityValidationVendor, a.*
into pubs.dbo.i2
from pubs.dbo.i1 a (nolock) 
join identityValidationStatus b (nolock) on a.LastIdentityValidationKey = b.IdentityValidationKey 
join identityValidationStatusType i (nolock) on i.IdentityValidationStatusTypeKey =b.IdentityValidationStatusTypeKey
join identityValidationVendor v (nolock) on v.IdentityValidationVendorKey =b.IdentityValidationVendorKey


create index ii4 on pubs.dbo.i2(accountkey)


-- internal lookup
drop table #i3
select * into #i3 from pubs.dbo.i2 (nolock) 
where  identityvalidationvendorkey = 4 and identityvalidationstatustypekey = 1 and VerificationStatusType ='Approved'

--select COUNT(*) from pubs.dbo.i2
---2226840
--select COUNT(*) from #i3

--select top 5 * from pubs.dbo.i2 a (nolock) left join #i3 b (nolock) on a.AccountKey= b.AccountKey where  b.AccountKey is null

-- verificationstatus is null, have perso card
--select * from CI_DSA.dbo.RPO_ACCT where accountkey in (44778718)


--update to the master table--------------------------------
update av
set   av.LastAttemptValue = 'Int'
from #i3 ac (nolock) join CI_DSA.dbo.RPO_ACCT av (nolock) 
on ac.AccountKey= av.AccountKey --and AV.LastAttemptValue is null


select * from CI_DSA.dbo.RPO_ACCT av (nolock) 
on ac.AccountKey= av.AccountKey --and AV.LastAttemptValue is null


---------------------------------------------------------------------------------------------------------------
--- update bank
---------------------------------------------------------------------------------------------------------------



drop table pubs.dbo.bank1
select p.BankKey as newbankkey,b.BankName as newbankname,ci.* into pubs.dbo.bank1 
from CI_DSA.dbo.RPO_ACCT ci (nolock) 
join vuproduct p (nolock) on ci.productkey = p.productkey
join Bank b (nolock) on p.BankKey = b.BankKey

create index ii22 on pubs.dbo.bank1(accountkey)

select top 10 * from pubs.dbo.bank1 where BankKey != newbankkey


--update to the master table--------------------------------
update av
set   av.BankKey = ac.newbankkey, av.BankName=ac.newbankname
from pubs.dbo.bank1 ac (nolock) join CI_DSA.dbo.RPO_ACCT av (nolock) 
on ac.AccountKey= av.AccountKey 


/*
select BankKey, COUNT(*) from  CI_DSA.dbo.RPO_ACCT av (nolock) group by BankKey

select * 
from vuproduct p (nolock)
join Bank b (nolock) on p.BankKey = b.BankKey
 where p.BankKey=1 -- no synovus bank anymore
 */
------------------------------------------------------------------------


