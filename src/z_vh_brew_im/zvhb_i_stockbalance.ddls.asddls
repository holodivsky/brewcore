@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'BrewCore: Stock balance'
@Metadata.ignorePropagatedAnnotations: true
// Stock is never stored: it is the sum of all movements, as in S/4HANA (MATDOC)
define view entity ZVHB_I_StockBalance
  as select from    ZVHB_I_StockMovement as Movement
    left outer to one join ZVHB_R_Batch  as Batch on  Movement.Material = Batch.Material
                                                  and Movement.Batch    = Batch.Batch
{
  key Movement.Material,
  key Movement.Plant,
  key Movement.StorageLocation,
  key Movement.Batch,
      Movement.Unit,
      Batch.Status                 as BatchStatus,
      Batch.ExpiryDate,

      @Semantics.quantity.unitOfMeasure: 'Unit'
      sum( Movement.Quantity )     as TotalQuantity
}
group by
  Movement.Material,
  Movement.Plant,
  Movement.StorageLocation,
  Movement.Batch,
  Movement.Unit,
  Batch.Status,
  Batch.ExpiryDate
having
  sum( Movement.Quantity ) <> 0
