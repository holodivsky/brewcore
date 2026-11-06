@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'BrewCore: Purchase order'
@Metadata.ignorePropagatedAnnotations: true
define root view entity ZVHB_R_PurchaseOrder
  as select from zvhb_pohdr

  composition [0..*] of ZVHB_R_PurchaseOrderItem as _Item

  association [0..1] to ZVHB_I_SupplierVH        as _Supplier     on $projection.Supplier = _Supplier.Supplier
  association [0..1] to I_Currency               as _Currency     on $projection.Currency = _Currency.Currency
  association [0..1] to ZVHB_I_PaymentTermsVH    as _PaymentTerms on $projection.PaymentTerms = _PaymentTerms.PaymentTerms
  association [0..1] to ZVHB_I_POStatusVH        as _Status       on $projection.Status = _Status.Status
{
  key po_uuid               as PurchaseOrderUUID,

      purchase_order        as PurchaseOrder,

      @ObjectModel.foreignKey.association: '_Supplier'
      @EndUserText.label: 'Supplier'
      supplier              as Supplier,

      @EndUserText.label: 'Order Date'
      order_date            as OrderDate,

      @ObjectModel.foreignKey.association: '_Currency'
      @EndUserText.label: 'Currency'
      currency              as Currency,

      @ObjectModel.foreignKey.association: '_PaymentTerms'
      payment_terms         as PaymentTerms,

      @Semantics.amount.currencyCode: 'Currency'
      @EndUserText.label: 'Total Net Amount'
      total_amount          as TotalAmount,

      @ObjectModel.foreignKey.association: '_Status'
      status                as Status,

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
      _Supplier,
      _Currency,
      _PaymentTerms,
      _Status
}
