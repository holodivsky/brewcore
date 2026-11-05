@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'BrewCore: Stock'
@Metadata.ignorePropagatedAnnotations: true
// Stock per material, plant, storage location and batch, split into free and blocked stock
define view entity ZVHB_I_Stock
  as select from ZVHB_I_StockBalance

  association [0..1] to ZVHB_I_MaterialVH as _Material on $projection.Material = _Material.Material
{
      @ObjectModel.foreignKey.association: '_Material'
  key Material,
  key Plant,
  key StorageLocation,
  key Batch,
      Unit,
      BatchStatus,

      @EndUserText.label: 'Best Before'
      ExpiryDate,

      @EndUserText.label: 'Remaining Shelf Life (Days)'
      case when ExpiryDate is null or ExpiryDate = '00000000'
           then 0
           else dats_days_between( $session.system_date, ExpiryDate )
      end                                                   as RemainingShelfLife,

      @EndUserText.label: 'Expired'
      case when ExpiryDate is not null and ExpiryDate <> '00000000' and ExpiryDate < $session.system_date
           then cast( 'X' as abap_boolean )
           else cast( ' ' as abap_boolean )
      end                                                   as IsExpired,

      @Semantics.quantity.unitOfMeasure: 'Unit'
      @EndUserText.label: 'Total Stock'
      TotalQuantity,

      @Semantics.quantity.unitOfMeasure: 'Unit'
      @EndUserText.label: 'Free Stock'
      case BatchStatus when 'BLKD' then TotalQuantity - TotalQuantity else TotalQuantity end as FreeQuantity,

      @Semantics.quantity.unitOfMeasure: 'Unit'
      @EndUserText.label: 'Blocked Stock'
      case BatchStatus when 'BLKD' then TotalQuantity else TotalQuantity - TotalQuantity end as BlockedQuantity,

      _Material
}
