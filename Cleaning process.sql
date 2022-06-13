
-- clean up duplicates

drop table #t1
select AccountKey, COUNT(*) as cnt into #t1 from ci_dsa.dbo.RPO_ACCT group by AccountKey having COUNT(*) >1

select * from ci_dsa.dbo.RPO_ACCT where AccountKey in (3138449)

select 


select accountkey, COUNT(*) from pubs.dbo.acct35_cip group by accountkey having COUNT(*) > 1
select * from pubs.dbo.acct35_cip where accountkey = 51431176

select * from vCustomer where accountkey = 51431176

select * from pubs.dbo.fTempPersowithAccountkey (51431176) tt

select p.isatm, vc.*,p.* 
from vCustomer vc join vuProduct p on vc.ProductKey= p.productkey where accountkey = 3138449
