@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'BrewCore: Credit exposure item'
@Metadata.ignorePropagatedAnnotations: true
// FR-SD-03: what a customer has ordered or owes: open and delivered orders that are not billed yet,
// plus invoices; credit memos reduce it. Payments follow with accounting, so every invoice counts as open.
define view entity ZVHB_I_CreditExposureItem
  as select from zvhb_sohdr
{
  key so_uuid      as DocumentUUID,
      customer     as Customer,
      currency     as Currency,

      @Semantics.amount.currencyCode: 'Currency'
      cast( total_amount as zvhb_amount ) as Amount
}
where
     status = 'OPEN'
  or status = 'DLVD'

union all

select from zvhb_billhdr
{
  key bill_uuid as DocumentUUID,
      customer  as Customer,
      currency  as Currency,

      cast( case billing_type when 'CRM' then total_amount - total_amount - total_amount
                              else total_amount end as zvhb_amount ) as Amount
}
