@EndUserText.label: 'Beer Tax Declaration for a Month'
// Parameter of the static action generate: plant and month of the declaration
define abstract entity ZVHB_D_DeclarationRequest
{
  @Consumption.valueHelpDefinition: [{ entity: { name: 'ZVHB_I_PlantVH', element: 'Plant' } }]
  @EndUserText.label: 'Plant'
  Plant       : zvhb_plant;

  @EndUserText.label: 'Year'
  PeriodYear  : abap.numc(4);

  @EndUserText.label: 'Month'
  PeriodMonth : abap.numc(2);
}
