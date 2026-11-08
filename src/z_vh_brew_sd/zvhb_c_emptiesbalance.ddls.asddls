@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Empties Balance'
@Metadata.ignorePropagatedAnnotations: true
@Search.searchable: true
@UI.headerInfo: {
  typeName: 'Empties Balance',
  typeNamePlural: 'Empties Balances',
  title: { type: #STANDARD, value: 'CustomerName' },
  description: { type: #STANDARD, value: 'MaterialName' }
}
@UI.presentationVariant: [{ sortOrder: [{ by: 'BalanceQuantity', direction: #DESC }] }]
// FR-IM-06: crates at each customer and the deposit they are worth at today's deposit rate
define view entity ZVHB_C_EmptiesBalance
  as select from         ZVHB_I_EmptiesBalance as Balance
    inner join           ZVHB_I_CustomerVH     as Customer on Customer.Customer = Balance.Customer
    left outer to one join ZVHB_I_MaterialVH   as Material on Material.Material = Balance.Material
    left outer to one join zvhb_price          as Deposit  on  Deposit.condition_type = 'DEPO'
                                                           and Deposit.material       = Balance.Material
                                                           and Deposit.valid_from    <= $session.system_date
                                                           and Deposit.valid_to      >= $session.system_date
{
      @UI.lineItem: [{ position: 10, importance: #HIGH }]
      @UI.selectionField: [{ position: 10 }]
      @UI.textArrangement: #TEXT_FIRST
      @ObjectModel.text.element: [ 'CustomerName' ]
      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZVHB_I_CustomerVH', element: 'Customer' } }]
      @Search.defaultSearchElement: true
  key Balance.Customer,

      @UI.lineItem: [{ position: 20, importance: #HIGH }]
      @UI.textArrangement: #TEXT_FIRST
      @ObjectModel.text.element: [ 'MaterialName' ]
      @EndUserText.label: 'Empties'
  key Balance.Material,

      @UI.hidden: true
      @Search.defaultSearchElement: true
      Customer.CustomerName,

      @UI.hidden: true
      @EndUserText.label: 'Empties Description'
      Material.MaterialName,

      @UI.hidden: true
      Balance.Unit,

      @UI.lineItem: [{ position: 30, importance: #MEDIUM }]
      @EndUserText.label: 'Issued'
      @Semantics.quantity.unitOfMeasure: 'Unit'
      Balance.IssuedQuantity,

      @UI.lineItem: [{ position: 40, importance: #MEDIUM }]
      @EndUserText.label: 'Returned'
      @Semantics.quantity.unitOfMeasure: 'Unit'
      Balance.ReturnedQuantity,

      @UI.lineItem: [{ position: 50, importance: #HIGH }]
      @EndUserText.label: 'At Customer'
      @Semantics.quantity.unitOfMeasure: 'Unit'
      Balance.BalanceQuantity,

      @UI.hidden: true
      Deposit.currency as Currency,

      @UI.lineItem: [{ position: 60, importance: #HIGH }]
      @EndUserText.label: 'Deposit Value'
      @Semantics.amount.currencyCode: 'Currency'
      cast( cast( Balance.BalanceQuantity as abap.dec( 13, 3 ) ) * cast( Deposit.amount as abap.dec( 15, 2 ) )
            as abap.curr( 23, 2 ) ) as DepositValue
}
