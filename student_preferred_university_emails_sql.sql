select p.SPRIDEN_ID, p.SPRIDEN_LAST_NAME, p.SPRIDEN_FIRST_NAME, p.SPRIDEN_MI,
e.GOREMAL_EMAL_CODE, e.GOREMAL_EMAIL_ADDRESS, e.GOREMAL_STATUS_IND, e.GOREMAL_PREFERRED_IND
 from goremal e, spriden p
where spriden_pidm = e.goremal_pidm
and spriden_change_ind is null
and spriden_id in (select ID from LAUREATE_DATA.IDS_Q133060)
and e.GOREMAL_STATUS_IND  in ('A')
and e.GOREMAL_PREFERRED_IND = 'Y'
and e.GOREMAL_EMAL_CODE = 'UNIV'
order by 2