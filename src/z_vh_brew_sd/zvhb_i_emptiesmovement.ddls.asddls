@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'BrewCore: Empties issued and returned'
@Metadata.ignorePropagatedAnnotations: true
// FR-IM-06: crates that left with a delivery and crates that came back with a credit memo
define view entity ZVHB_I_EmptiesMovement
  as select from zvhb_dlvitm as Item
    inner join   zvhb_dlvhdr as Header on Header.dlv_uuid = Item.dlv_uuid
{
  key Item.item_uuid                 as ItemUUID,
      Header.customer                as Customer,
      Item.material                  as Material,
      Item.unit                      as Unit,

      @Semantics.quantity.unitOfMeasure: 'Unit'
      Item.quantity                  as IssuedQuantity,

      @Semantics.quantity.unitOfMeasure: 'Unit'
      Item.quantity - Item.quantity  as ReturnedQuantity
}
where
      Item.item_category = 'DEPO'
  and (
       Header.status     = 'GI'
    or Header.status     = 'BILL'
  )

union all

select from zvhb_billitm as Item
  inner join zvhb_billhdr as Header on Header.bill_uuid = Item.bill_uuid
{
  key Item.item_uuid                 as ItemUUID,
      Header.customer                as Customer,
      Item.material                  as Material,
      Item.unit                      as Unit,
      Item.quantity - Item.quantity  as IssuedQuantity,
      Item.quantity                  as ReturnedQuantity
}
where
      Item.item_category  = 'DEPO'
  and Header.billing_type = 'CRM'
