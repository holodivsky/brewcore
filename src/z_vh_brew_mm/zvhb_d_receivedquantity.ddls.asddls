@EndUserText.label: 'Received Quantity'
// Change of the received quantity: positive for a goods receipt, negative for its reversal
define abstract entity ZVHB_D_ReceivedQuantity
{
  Quantity : abap.dec(13,3);
}
