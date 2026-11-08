@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'BrewCore: Beer batch of brew order'
@Metadata.ignorePropagatedAnnotations: true
// The beer batch that the goods receipt of a brew order created (movement type 101)
define view entity ZVHB_I_BrewOrderBatch
  as select from ZVHB_R_MaterialDocumentItem
{
  key BrewOrder,
      max( Batch ) as Batch
}
where
      BrewOrder    <> ''
  and MovementType =  '101'
group by
  BrewOrder
