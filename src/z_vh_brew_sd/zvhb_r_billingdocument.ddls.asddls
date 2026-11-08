@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'BrewCore: Billing document'
@Metadata.ignorePropagatedAnnotations: true
define root view entity ZVHB_R_BillingDocument
  as select from zvhb_billhdr

  composition [0..*] of ZVHB_R_BillingDocumentItem as _Item

  association [0..1] to ZVHB_I_CustomerVH          as _Customer    on $projection.Customer = _Customer.Customer
  association [0..1] to ZVHB_I_BillingTypeVH       as _BillingType on $projection.BillingType = _BillingType.BillingType
{
  key bill_uuid             as BillingDocumentUUID,

      billing_document      as BillingDocument,

      @ObjectModel.foreignKey.association: '_BillingType'
      billing_type          as BillingType,

      @ObjectModel.foreignKey.association: '_Customer'
      customer              as Customer,

      sales_order           as SalesOrder,

      delivery              as Delivery,

      @EndUserText.label: 'Billing Date'
      billing_date          as BillingDate,

      currency              as Currency,

      @Semantics.amount.currencyCode: 'Currency'
      @EndUserText.label: 'Net Value'
      net_amount            as NetAmount,

      @Semantics.amount.currencyCode: 'Currency'
      @EndUserText.label: 'Deposit'
      deposit_amount        as DepositAmount,

      @Semantics.amount.currencyCode: 'Currency'
      @EndUserText.label: 'Total'
      total_amount          as TotalAmount,

      @Semantics.user.createdBy: true
      created_by            as CreatedBy,

      @Semantics.systemDateTime.createdAt: true
      created_at            as CreatedAt,

      @Semantics.user.lastChangedBy: true
      last_changed_by       as LastChangedBy,

      @Semantics.systemDateTime.lastChangedAt: true
      last_changed_at       as LastChangedAt,

      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at as LocalLastChangedAt,

      _Item,
      _Customer,
      _BillingType
}
