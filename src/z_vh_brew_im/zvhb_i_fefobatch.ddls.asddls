@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'BrewCore: FEFO batch proposal'
@Metadata.ignorePropagatedAnnotations: true
// Batches that may be issued: free stock, not expired. Consumers sort by ExpiryDate (first expired, first out).
define view entity ZVHB_I_FefoBatch
  as select from ZVHB_I_Stock
{
  key Material,
  key Plant,
  key StorageLocation,
  key Batch,
      Unit,
      ExpiryDate,
      RemainingShelfLife,

      @Semantics.quantity.unitOfMeasure: 'Unit'
      FreeQuantity
}
where
      Batch        <> ''
  and IsExpired    =  ' '
  and FreeQuantity >  0
