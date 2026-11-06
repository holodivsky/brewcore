@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'BrewCore: Supplier invoice'
@Metadata.ignorePropagatedAnnotations: true
define root view entity ZVHB_R_SupplierInvoice
  as select from zvhb_sinvhdr

  composition [0..*] of ZVHB_R_SupplierInvoiceItem as _Item

  association [0..1] to ZVHB_R_PurchaseOrder       as _PurchaseOrder on $projection.PurchaseOrder = _PurchaseOrder.PurchaseOrder
  association [0..1] to ZVHB_I_SupplierVH          as _Supplier      on $projection.Supplier = _Supplier.Supplier
  association [0..1] to ZVHB_I_InvoiceStatusVH     as _Status        on $projection.Status = _Status.Status
{
  key invoice_uuid          as InvoiceUUID,

      supplier_invoice      as SupplierInvoice,

      @ObjectModel.foreignKey.association: '_PurchaseOrder'
      purchase_order        as PurchaseOrder,

      @ObjectModel.foreignKey.association: '_Supplier'
      @EndUserText.label: 'Supplier'
      supplier              as Supplier,

      invoice_reference     as InvoiceReference,

      @EndUserText.label: 'Invoice Date'
      invoice_date          as InvoiceDate,

      @EndUserText.label: 'Currency'
      currency              as Currency,

      @Semantics.amount.currencyCode: 'Currency'
      @EndUserText.label: 'Total Net Amount'
      total_amount          as TotalAmount,

      @ObjectModel.foreignKey.association: '_Status'
      status                as Status,

      // Blocked and rejected invoices are red, posted ones green
      cast( case status when 'BLCK' then 1
                        when 'REJ'  then 1
                        when 'POST' then 3
                        else 0 end as abap.int1 ) as StatusCriticality,

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
      _PurchaseOrder,
      _Supplier,
      _Status
}
