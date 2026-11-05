@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'BrewCore: Stock movement'
@Metadata.ignorePropagatedAnnotations: true
// One signed line per stock change. A transfer posting changes two storage locations,
// so its receiving side comes from the second branch of the union.
define view entity ZVHB_I_StockMovement
  as select from zvhb_mdocitm
{
  key material_document                            as MaterialDocument,
  key item                                         as Item,
  key cast( 'I' as abap.char( 1 ) )                as Side,
      material                                     as Material,
      plant                                        as Plant,
      storage_location                             as StorageLocation,
      batch                                        as Batch,
      unit                                         as Unit,

      // Receipts and reversed issues increase the stock, issues and reversed receipts reduce it
      @Semantics.quantity.unitOfMeasure: 'Unit'
      case when movement_type = '101' or movement_type = '262' or movement_type = '312'
             or movement_type = '552' or movement_type = '561' or movement_type = '602'
           then quantity
           else quantity * -1
      end                                          as Quantity
}

union all

select from zvhb_mdocitm
{
  key material_document                            as MaterialDocument,
  key item                                         as Item,
  key cast( 'R' as abap.char( 1 ) )                as Side,
      material                                     as Material,
      plant                                        as Plant,
      receiving_location                           as StorageLocation,
      batch                                        as Batch,
      unit                                         as Unit,
      case when movement_type = '311'
           then quantity
           else quantity * -1
      end                                          as Quantity
}
where
     movement_type = '311'
  or movement_type = '312'
