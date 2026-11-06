@EndUserText.label: 'Create Purchase Order from Requisition'
define abstract entity ZVHB_D_RequisitionReference
{
  @Consumption.valueHelpDefinition: [{ entity: { name: 'ZVHB_I_ApprovedRequisitionVH', element: 'PurchaseRequisition' } }]
  @EndUserText.label: 'Purchase Requisition'
  PurchaseRequisition : zvhb_purch_req;

  @Consumption.valueHelpDefinition: [{ entity: { name: 'ZVHB_I_SupplierVH', element: 'Supplier' } }]
  @EndUserText.label: 'Supplier (empty: preferred supplier)'
  Supplier            : zvhb_partner;

  @EndUserText.label: 'Net Price per Unit (EUR)'
  NetPrice            : abap.dec(13,2);
}
