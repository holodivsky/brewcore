@EndUserText.label: 'Empties Return'
// Parameter of the static action returnEmpties: crates a customer brings back
define abstract entity ZVHB_D_EmptiesReturn
{
  @Consumption.valueHelpDefinition: [{ entity: { name: 'ZVHB_I_CustomerVH', element: 'Customer' } }]
  @EndUserText.label: 'Customer'
  Customer : zvhb_partner;

  @Consumption.valueHelpDefinition: [{ entity: { name: 'ZVHB_I_MaterialVH', element: 'Material' } }]
  @EndUserText.label: 'Empties'
  Material : zvhb_material;

  @EndUserText.label: 'Returned Quantity'
  Quantity : abap.dec(13,3);
}
