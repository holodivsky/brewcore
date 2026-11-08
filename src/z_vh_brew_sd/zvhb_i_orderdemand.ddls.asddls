@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'BrewCore: Confirmed demand per order'
@Metadata.ignorePropagatedAnnotations: true
// Quantities that sales orders have confirmed and not delivered yet
define view entity ZVHB_I_OrderDemand
  as select from zvhb_soitm as Item
    inner join   zvhb_sohdr as Header on Header.so_uuid = Item.so_uuid
{
  key Item.so_uuid                     as SalesOrderUUID,
  key Item.material                    as Material,
      Item.unit                        as Unit,

      @Semantics.quantity.unitOfMeasure: 'Unit'
      sum( Item.confirmed_quantity )   as ConfirmedQuantity
}
where
     Header.status = 'OPEN'
  or Header.status = 'CRBL'
group by
  Item.so_uuid,
  Item.material,
  Item.unit
